import AppKit
import ApplicationServices

/// The direct build uses Accessibility, for the event tap (it modifies
/// events) and for AX window focusing. The App Store build is sandboxed,
/// where AX isn't available, so it asks for Input Monitoring (to see keys)
/// and event posting (to replay them and click windows) instead.
enum Permissions {
    #if APP_STORE
    static let name = "Input Monitoring"
    private static let pane = "Privacy_ListenEvent"

    static var granted: Bool {
        CGPreflightListenEventAccess() && CGPreflightPostEventAccess()
    }

    static func request() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        if !CGPreflightPostEventAccess() { _ = CGRequestPostEventAccess() }
    }
    #else
    static let name = "Accessibility"
    private static let pane = "Privacy_Accessibility"

    static var granted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt the first time. After that it's a no-op and
    /// the user has to go to System Settings.
    static func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    #endif

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        NSWorkspace.shared.open(url)
    }
}
