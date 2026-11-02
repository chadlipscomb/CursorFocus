import SwiftUI

struct ShortcutSettings: View {
    @ObservedObject var prefs: Preferences
    @State private var selection: String?
    @State private var recorder: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These never move focus, even right after the pointer moves.")
                .foregroundStyle(.secondary)

            List(prefs.passthrough, selection: $selection) { shortcut in
                Text(shortcut.display)
                    .font(.body.monospaced())
                    .tag(shortcut.id)
            }
            .frame(minHeight: 200)

            HStack(spacing: 4) {
                Button(recorder == nil ? "Record Shortcut" : "Press a shortcut…") {
                    recorder == nil ? startRecording() : stopRecording()
                }
                Button {
                    prefs.passthrough.removeAll { $0.id == selection }
                    selection = nil
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)

                Spacer()

                Button("Restore Defaults") {
                    prefs.passthrough = Shortcut.defaults
                }
            }
        }
        .padding()
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let shortcut = Shortcut(event)
            if !prefs.passthrough.contains(where: { $0.id == shortcut.id }) {
                prefs.passthrough.append(shortcut)
            }
            selection = shortcut.id
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
    }
}

private extension Shortcut {
    init(_ event: NSEvent) {
        self.init(keyCode: event.keyCode, modifiers: Modifiers(event.modifierFlags),
                  key: Self.keyName(event))
    }

    static let namedKeys: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    static func keyName(_ event: NSEvent) -> String {
        if let name = namedKeys[event.keyCode] { return name }
        return event.charactersIgnoringModifiers?.uppercased() ?? "#\(event.keyCode)"
    }
}
