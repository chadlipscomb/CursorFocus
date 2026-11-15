import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        TabView {
            GeneralSettings(prefs: prefs)
                .tabItem { Label("General", systemImage: "gearshape") }
            ExclusionSettings(prefs: prefs)
                .tabItem { Label("Exclusions", systemImage: "nosign") }
            ShortcutSettings(prefs: prefs)
                .tabItem { Label("Shortcuts", systemImage: "command") }
            PermissionSettings()
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
                Toggle("Switch on hover", isOn: $prefs.focusOnHover)
                LabeledContent("Delay") {
                    HStack {
                        Slider(value: $prefs.hoverDelay, in: 0.1...2, step: 0.1)
                        Text(prefs.hoverDelay.formatted(.number.precision(.fractionLength(1))) + " s")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .disabled(!prefs.focusOnHover)
            } footer: {
                Text("Focus the window under the pointer once it has been there this long, without waiting for you to type. The window comes to the front.")
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
    @State private var granted: Set<Permission> = []

    var body: some View {
        Form {
            Section {
                ForEach(Permission.required) { permission in
                    PermissionRow(permission: permission, granted: granted.contains(permission))
                }
            } footer: {
                Text("CursorFocus picks changes up on its own, no relaunch needed. Nothing you type is stored or sent anywhere.")
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                granted = Set(Permission.required.filter(\.granted))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
