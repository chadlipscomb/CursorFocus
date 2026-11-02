import AppKit
import os

private let log = Logger(subsystem: "com.chadlipscomb.CursorFocus", category: "engine")

/// Owns the event tap. Watches mouse moves to keep the tracker current, and
/// on a key press that should be redirected it swallows the key, focuses the
/// hovered window, then replays everything typed in the meantime.
@MainActor
final class Engine: ObservableObject {
    struct Redirect {
        var appName: String
        var at: Date
    }

    struct AppRef: Equatable {
        var bundleID: String
        var name: String
    }

    @Published private(set) var running = false
    @Published private(set) var lastRedirect: Redirect?
    /// Most recent app other than us, for the "Exclude …" menu item.
    @Published private(set) var lastActiveApp: AppRef?

    private let prefs: Preferences
    private let tracker = WindowTracker()
    private var tap: CFMachPort?

    /// Non-nil while switching focus. Every key event lands here until the
    /// target window has focus, then gets posted again in order.
    private var buffer: [CGEvent]?

    /// Stamped on events we post so the tap lets them through.
    private static let replayMarker: Int64 = 0x4346_4F43

    init(prefs: Preferences) {
        self.prefs = prefs
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.noteActiveApp() }
        }
        noteActiveApp()
    }

    private func noteActiveApp() {
        guard let app = NSWorkspace.shared.frontmostApplication, app != .current,
              let id = app.bundleIdentifier
        else { return }
        lastActiveApp = AppRef(bundleID: id, name: app.localizedName ?? id)
    }

    /// Accessibility can be granted while we're running, so keep checking
    /// instead of making the user relaunch.
    func startWhenAllowed() async {
        while !start() {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        guard Permissions.accessibilityGranted else { return false }

        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Couldn't create event tap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        running = true
        return true
    }

    /// Returns true to let the event through.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            tracker.mouseMoved(to: event.location)
            return true

        case .keyDown, .keyUp, .flagsChanged:
            if event.getIntegerValueField(.eventSourceUserData) == Self.replayMarker { return true }
            if buffer != nil {
                buffer?.append(event.copy() ?? event)
                return false
            }
            guard type == .keyDown, prefs.isActive else { return true }
            return !redirectIfNeeded(event)

        default:
            return true
        }
    }

    /// Returns true if the event was taken.
    private func redirectIfNeeded(_ event: CGEvent) -> Bool {
        // Typing in our own settings window should never be redirected.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return false
        }

        let now = Date()
        let cursor = CGEvent(source: nil)?.location ?? event.location
        tracker.update(point: cursor, now: now)

        guard let target = tracker.hovered else { return false }

        let ctx = RedirectPolicy.Context(
            hovered: Self.target(for: target),
            hoverEnteredAt: tracker.hoverEnteredAt,
            focused: tracker.focused.map(Self.target(for:)),
            focusChangedAt: tracker.focusChangedAt,
            mouseButtonDown: Self.mouseButtonDown,
            now: now
        )
        guard prefs.policy.shouldRedirect(KeyPress(event), in: ctx) else { return false }

        buffer = [event.copy() ?? event]
        WindowFocuser.focus(target)
        let appName = NSRunningApplication(processIdentifier: target.pid)?.localizedName ?? "?"
        Task { await finishSwitch(to: target, appName: appName, started: now) }
        return true
    }

    private func finishSwitch(to target: WindowInfo, appName: String, started: Date) async {
        let deadline = started.addingTimeInterval(0.25)
        while !hasFocus(target) && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        if hasFocus(target) {
            log.info("Redirected to \(appName, privacy: .public) in \(ms) ms")
        } else {
            log.error("Timed out focusing \(appName, privacy: .public) after \(ms) ms, replaying anyway")
        }
        lastRedirect = Redirect(appName: appName, at: started)

        let events = buffer ?? []
        buffer = nil
        for event in events {
            event.setIntegerValueField(.eventSourceUserData, value: Self.replayMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func hasFocus(_ target: WindowInfo) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid
            && Windows.frontmost(of: target.pid)?.id == target.id
    }

    private static func target(for window: WindowInfo) -> RedirectPolicy.Target {
        RedirectPolicy.Target(windowID: window.id,
                              bundleID: NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier)
    }

    private static var mouseButtonDown: Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
            || CGEventSource.buttonState(.combinedSessionState, button: .right)
    }
}

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<Engine>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap's run loop source is on the main run loop.
    let pass = MainActor.assumeIsolated { engine.handle(type, event) }
    return pass ? Unmanaged.passUnretained(event) : nil
}
