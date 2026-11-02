import SwiftUI

@main
struct CursorFocusApp: App {
    @AppStorage("enabled") private var enabled = true

    var body: some Scene {
        MenuBarExtra("CursorFocus", systemImage: enabled ? "cursorarrow.rays" : "cursorarrow.slash") {
            Toggle("Enabled", isOn: $enabled)
            Divider()
            Button("Quit CursorFocus") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
