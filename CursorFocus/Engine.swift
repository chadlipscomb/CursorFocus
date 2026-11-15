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
    /// The tap could only be created listen-only, so keys can't be held back
    /// and replayed. Switch on hover still works. Expected to happen, if at
    /// all, in the sandboxed build.
    @Published private(set) var listenOnly = false
    @Published private(set) var lastRedirect: Redirect?
    /// Most recent app other than us, for the "Exclude …" menu item.
    @Published private(set) var lastActiveApp: AppRef?

    private let prefs: Preferences
    private let tracker = WindowTracker()
    private var tap: CFMachPort?
    /// Used instead of the tap in the hover-only build.
    private var mouseMonitor: Any?

    /// Non-nil while switching focus. Every key event lands here until the
    /// target window has focus, then gets posted again in order.
    private var buffer: [CGEvent]?

    /// Pending "switch on hover", restarted whenever the pointer moves onto a
    /// different window.
    private var hoverTask: Task<Void, Never>?
    private var hoverTarget: CGWindowID?

    /// Stamped on events we post so the tap lets them through.
    private static let replayMarker: Int64 = 0x4346_4F43

    init(prefs: Preferences) {
        self.prefs = prefs
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.noteActiveApp()
                // Without this, a cmd-tab only registers on the next mouse
                // move, and can tie with a hover that starts on that same move.
                self?.tracker.refreshFocus()
            }
        }
        noteActiveApp()
    }

    private func noteActiveApp() {
        guard let app = NSWorkspace.shared.frontmostApplication, app != .current,
              let id = app.bundleIdentifier
        else { return }
        lastActiveApp = AppRef(bundleID: id, name: app.localizedName ?? id)
    }

    /// Permission can be granted while we're running, so keep checking
    /// instead of making the user relaunch.
    func startWhenAllowed() async {
        while !start() {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    @discardableResult
    func start() -> Bool {
        if tap != nil || mouseMonitor != nil { return true }
        guard Permission.allGranted else { return false }
        if !Build.redirectsTyping { return startMouseMonitor() }

        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        func create(_ options: CGEventTapOptions) -> CFMachPort? {
            CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: options,
                              eventsOfInterest: mask, callback: tapCallback,
                              userInfo: Unmanaged.passUnretained(self).toOpaque())
        }
        let tap: CFMachPort
        if let active = create(.defaultTap) {
            tap = active
        } else if let passive = create(.listenOnly) {
            log.error("Only a listen-only event tap is allowed, typing won't be redirected")
            tap = passive
            listenOnly = true
        } else {
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

    /// The hover-only build never looks at the keyboard, and a global monitor
    /// for mouse moves needs no permission at all.
    private func startMouseMonitor() -> Bool {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            let point = event.cgEvent?.location ?? .zero
            MainActor.assumeIsolated { self?.mouseMoved(to: point) }
        }
        running = mouseMonitor != nil
        return running
    }

    private func mouseMoved(to point: CGPoint) {
        tracker.mouseMoved(to: point)
        scheduleHoverFocus()
    }

    /// Returns true to let the event through.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            mouseMoved(to: event.location)
            return true

        case .keyDown, .keyUp, .flagsChanged:
            if event.getIntegerValueField(.eventSourceUserData) == Self.replayMarker { return true }
            if buffer != nil {
                buffer?.append(event.copy() ?? event)
                return false
            }
            guard type == .keyDown, !listenOnly, prefs.isActive else { return true }
            return !redirectIfNeeded(event)

        default:
            return true
        }
    }

    /// Returns true if the event was taken.
    private func redirectIfNeeded(_ event: CGEvent) -> Bool {
        // Typing in our own settings window should never be redirected. We can
        // also be active with no window at all after Settings closes, which
        // shouldn't count.
        if NSApp.isActive && NSApp.keyWindow != nil { return false }

        let now = Date()
        let cursor = CGEvent(source: nil)?.location ?? event.location
        tracker.update(point: cursor, now: now)

        guard let target = tracker.hovered,
              prefs.policy.shouldRedirect(KeyPress(event), in: context(target, now: now))
        else { return false }

        buffer = [event.copy() ?? event]
        WindowFocuser.focus(target)
        tracker.focusMoved(to: target, at: now)
        let appName = NSRunningApplication(processIdentifier: target.pid)?.localizedName ?? "?"
        Task { await finishSwitch(to: target, appName: appName, started: now) }
        return true
    }

    private func scheduleHoverFocus() {
        guard prefs.hoverEnabled, prefs.isActive else {
            hoverTask?.cancel()
            hoverTarget = nil
            return
        }
        let id = tracker.hovered?.id
        guard id != hoverTarget else { return }
        hoverTarget = id
        hoverTask?.cancel()
        guard let id else { return }

        let delay = prefs.hoverDelay
        log.debug("Hover: entered \(id), waiting \(delay) s")
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled { self?.focusOnHover() }
        }
    }

    private func focusOnHover() {
        // A key press already took care of it.
        if buffer != nil { return }

        let now = Date()
        tracker.update(point: CGEvent(source: nil)?.location ?? .zero, now: now)
        guard let target = tracker.hovered, target.id == hoverTarget else {
            log.debug("Hover: pointer left window \(self.hoverTarget ?? 0)")
            return
        }
        let ctx = context(target, now: now)
        guard prefs.policy.shouldFocusOnHover(in: ctx) else {
            log.debug("""
                Hover: not focusing \(target.id), focused \(ctx.focused?.windowID ?? 0), \
                entered \(ctx.hoverEnteredAt.timeIntervalSince(ctx.focusChangedAt), format: .fixed(precision: 3)) s \
                after focus changed, button down \(ctx.mouseButtonDown)
                """)
            return
        }

        WindowFocuser.focus(target)
        tracker.focusMoved(to: target, at: now)
        let appName = NSRunningApplication(processIdentifier: target.pid)?.localizedName ?? "?"
        log.info("Focused \(appName, privacy: .public) on hover")
        lastRedirect = Redirect(appName: appName, at: now)
    }

    private func context(_ hovered: WindowInfo, now: Date) -> RedirectPolicy.Context {
        RedirectPolicy.Context(
            hovered: Self.target(for: hovered),
            hoverEnteredAt: tracker.hoverEnteredAt,
            focused: tracker.focused.map(Self.target(for:)),
            focusChangedAt: tracker.focusChangedAt,
            mouseButtonDown: Self.mouseButtonDown,
            now: now
        )
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
    // The tap's run loop source is on the main run loop, so the event never
    // actually crosses threads. Older compilers can't see that.
    nonisolated(unsafe) let event = event
    let pass = MainActor.assumeIsolated { engine.handle(type, event) }
    return pass ? Unmanaged.passUnretained(event) : nil
}
