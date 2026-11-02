import SwiftUI
import UniformTypeIdentifiers

struct ExclusionSettings: View {
    @ObservedObject var prefs: Preferences
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(selection: $selection) {
                ForEach($prefs.exclusions) { $exclusion in
                    HStack {
                        AppIcon(bundleID: exclusion.bundleID)
                        VStack(alignment: .leading) {
                            Text(exclusion.name)
                            Text(exclusion.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $exclusion.mode) {
                            ForEach(Exclusion.Mode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .tag(exclusion.bundleID)
                }
            }
            .frame(minHeight: 200)
            .overlay {
                if prefs.exclusions.isEmpty {
                    Text("No excluded apps")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Menu {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                            prefs.exclude(bundleID: app.bundleIdentifier!, name: app.localizedName ?? app.bundleIdentifier!)
                        }
                    }
                    Divider()
                    Button("Choose App…", action: chooseApp)
                } label: {
                    Image(systemName: "plus")
                }
                .menuIndicator(.hidden)
                .fixedSize()

                Button {
                    if let selection { prefs.removeExclusion(selection) }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)

                Spacer()
            }

            Text("""
                Never focus into: typing never moves to this app's windows.
                Never steal from: while this app has focus, typing stays put.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .filter { !prefs.isExcluded($0.bundleIdentifier!) && $0 != .current }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            prefs.exclude(bundleID: id, name: name)
        }
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 24, height: 24)
        }
    }
}
