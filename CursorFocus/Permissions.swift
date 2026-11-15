import AppKit
import ApplicationServices

/// A system permission the app needs. The direct build uses Accessibility,
/// for the event tap (it modifies events) and for AX window focusing. The App
/// Store build is sandboxed, where AX isn't available, so it asks for Input
/// Monitoring (to see keys) and event posting (to replay them and click
/// windows) instead.
enum Permission: String, CaseIterable, Identifiable {
    case accessibility
    case inputMonitoring
    /// System Settings lists this one under Accessibility too.
    case postEvents

    var id: String { rawValue }

    /// Everything this build needs, in the order it's asked for.
    static var required: [Permission] {
        #if APP_STORE
        [.inputMonitoring, .postEvents]
        #else
        [.accessibility]
        #endif
    }

    static var allGranted: Bool {
        required.allSatisfy(\.granted)
    }

    var title: String {
        switch self {
        case .accessibility, .postEvents: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }

    /// Shown next to the permission, before the system asks for it.
    var reason: String {
        switch self {
        case .accessibility:
            "To see a key press before the focused app does, hold it while the window under the pointer comes forward, then deliver it there."
        case .inputMonitoring:
            "To see a key press before the focused app does, so it can be held while the window under the pointer comes forward."
        case .postEvents:
            "To deliver the held key presses to that window, and to click its title bar to bring it forward."
        }
    }

    var granted: Bool {
        switch self {
        case .accessibility: AXIsProcessTrusted()
        case .inputMonitoring: CGPreflightListenEventAccess()
        case .postEvents: CGPreflightPostEventAccess()
        }
    }

    /// macOS only shows the system prompt once per permission. After that,
    /// asking again does nothing, so open the right pane of System Settings.
    func ask() {
        let key = "asked.\(rawValue)"
        guard !UserDefaults.standard.bool(forKey: key) else {
            openSettings()
            return
        }
        UserDefaults.standard.set(true, forKey: key)

        switch self {
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
        case .postEvents:
            _ = CGRequestPostEventAccess()
        }
    }

    func openSettings() {
        let pane = self == .inputMonitoring ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        NSWorkspace.shared.open(url)
    }
}
