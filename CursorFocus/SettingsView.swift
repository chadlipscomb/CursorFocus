import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: Engine
    @ObservedObject var prefs: Preferences

    var body: some View {
        TabView {
            GeneralSettings(prefs: prefs)
                .tabItem { Label("General", systemImage: "gearshape") }
            PermissionSettings(engine: engine)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct GeneralSettings: View {
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Enabled", isOn: $prefs.enabled)

            Section {
                LabeledContent("Time window") {
                    HStack {
                        Slider(value: $prefs.window, in: 0.5...10, step: 0.5)
                        Text(prefs.window.formatted(.number.precision(.fractionLength(1))) + " s")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            } footer: {
                Text("How long after the pointer moves onto a window that typing still goes to it.")
            }

            Section {
                Toggle("Redirect shortcuts", isOn: $prefs.redirectShortcuts)
            } footer: {
                Text("When off, only plain typing follows the pointer. ⌘ and ⌃ shortcuts stay with the focused window.")
            }

            Section {
                Toggle("Raise window when focusing", isOn: $prefs.raiseWindow)
                    .disabled(true)
            } footer: {
                Text("Always on for now. Focusing a window without bringing it forward needs a private macOS API.")
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .formStyle(.grouped)
    }
}

struct PermissionSettings: View {
    @ObservedObject var engine: Engine

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    if engine.running {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open System Settings…") {
                            Permissions.openAccessibilitySettings()
                        }
                    }
                }
            } footer: {
                Text("Used to see key presses before the focused app does, and to bring the window under the pointer forward. CursorFocus picks the change up on its own, no relaunch needed.")
            }
        }
        .formStyle(.grouped)
    }
}
