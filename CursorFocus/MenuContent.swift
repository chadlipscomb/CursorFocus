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

    var body: some View {
        if !engine.running {
            Text("Needs Accessibility access")
            Button("Open Accessibility Settings…") {
                Permissions.openAccessibilitySettings()
            }
            Divider()
        }

        Toggle("Enabled", isOn: $prefs.enabled)

        if let last = engine.lastRedirect {
            Divider()
            Text("Last: \(last.appName) at \(last.at.formatted(date: .omitted, time: .standard))")
        }

        Divider()
        Button("Quit CursorFocus") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
