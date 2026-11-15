import SwiftUI

struct MenuIcon: View {
    @ObservedObject var engine: Engine
    @ObservedObject var prefs: Preferences

    var body: some View {
        if !engine.running {
            Image(systemName: "exclamationmark.triangle")
        } else if prefs.isActive {
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
            Text("Needs your permission to work")
            Button("Finish Setup…") { SetupWindow.show() }
            Divider()
        } else if engine.listenOnly {
            Text("Typing can't be redirected, only switch on hover works")
            Divider()
        }

        Toggle("Enabled", isOn: $prefs.enabled)

        if let until = prefs.pausedUntil {
            Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
            Button("Resume") { prefs.pausedUntil = nil }
        } else {
            Menu("Pause") {
                Button("For 15 Minutes") { prefs.pause(for: 15 * 60) }
                Button("For 1 Hour") { prefs.pause(for: 60 * 60) }
                Button("Until Tomorrow") { prefs.pauseUntilTomorrow() }
            }
            .disabled(!prefs.enabled)
        }

        Divider()

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
