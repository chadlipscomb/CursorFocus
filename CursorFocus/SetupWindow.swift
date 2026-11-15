import SwiftUI

/// Explains what the app does and why it needs each permission before any
/// system prompt shows up. Opens on launch while something is missing, and
/// from the menu after that.
@MainActor
enum SetupWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SetupView { close() }))
            window.title = "CursorFocus"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Menu bar apps aren't active, so the window would open behind
        // whatever you were using.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
    }
}

struct SetupView: View {
    let done: @MainActor () -> Void
    @State private var granted: Set<Permission> = []

    private var allGranted: Bool {
        granted.count == Permission.required.count
    }

    private static let redirectIntro = "Move the pointer onto another window and start typing. CursorFocus brings that window forward first, so your keys land where you're looking, not in the window you left behind. For that, macOS needs you to allow:"
    private static let hoverIntro = "Rest the pointer on a window for a moment and CursorFocus brings it forward, so you can start typing without clicking first. For that, macOS needs you to allow:"
    private static let redirectPrivacy = "Nothing you type is stored or sent anywhere. CursorFocus makes no network connections."
    private static let hoverPrivacy = "CursorFocus never sees what you type, and makes no network connections."

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to CursorFocus")
                        .font(.title2.bold())
                    Text(Build.redirectsTyping ? "Type into the window you're pointing at." : "Focus follows your pointer.")
                        .foregroundStyle(.secondary)
                }
            }

            Text(Build.redirectsTyping ? Self.redirectIntro : Self.hoverIntro)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Permission.required) { permission in
                    PermissionRow(permission: permission, granted: granted.contains(permission))
                }
            }

            Text(Build.redirectsTyping ? Self.redirectPrivacy : Self.hoverPrivacy)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if allGranted {
                    Label("You're all set. CursorFocus lives in the menu bar.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Button(allGranted ? "Done" : "Later") { done() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .task {
            // System Settings doesn't tell anyone when a permission changes.
            while !Task.isCancelled {
                granted = Set(Permission.required.filter(\.granted))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct PermissionRow: View {
    let permission: Permission
    let granted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).bold()
                Text(permission.reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if !granted {
                Button("Allow…") { permission.ask() }
            }
        }
    }
}
