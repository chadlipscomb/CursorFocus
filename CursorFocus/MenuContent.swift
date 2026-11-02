import SwiftUI

struct MenuIcon: View {
    @ObservedObject var engine: Engine
    @ObservedObject var prefs: Preferences

    var body: some View {
        if !engine.running {
            Image(systemName: "exclamationmark.triangle")
        } else if prefs.enabled {
            Image(systemName: "cursorarrow.rays")
        } else {
            Image(systemName: "cursorarrow.slash")
        }
    }
}

struct MenuContent: View {
    @ObservedObject var engine: Engine
    @ObservedObject var prefs: Preferences
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if !engine.running {
            Text("Needs Accessibility access")
            Button("Open Accessibility Settings…") {
                Permissions.openAccessibilitySettings()
            }
            Divider()
        }

        Toggle("Enabled", isOn: $prefs.enabled)

        if let app = engine.lastActiveApp {
            if prefs.isExcluded(app.bundleID) {
                Button("Stop Excluding \(app.name)") { prefs.removeExclusion(app.bundleID) }
            } else {
                Button("Exclude \(app.name)") { prefs.exclude(bundleID: app.bundleID, name: app.name) }
            }
        }

        if let last = engine.lastRedirect {
            Divider()
            Text("Last: \(last.appName) at \(last.at.formatted(date: .omitted, time: .standard))")
        }

        Divider()
        Button("Settings…") {
            // Menu bar apps aren't active, so the window would open behind
            // whatever you were using.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit CursorFocus") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
