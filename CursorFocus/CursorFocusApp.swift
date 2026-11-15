import SwiftUI

@main
struct CursorFocusApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var prefs = Preferences.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(engine: appDelegate.engine, prefs: prefs)
        } label: {
            MenuIcon(engine: appDelegate.engine, prefs: prefs)
        }

        Settings {
            SettingsView(prefs: prefs)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = Engine(prefs: .shared)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch the app too. No tap or prompts there.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        // Explain first. The system prompts come from the setup window's
        // buttons, so nobody gets asked for keyboard access out of nowhere.
        if !Permission.allGranted {
            SetupWindow.show()
        }
        Task { await engine.startWhenAllowed() }
    }
}
