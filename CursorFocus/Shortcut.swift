import AppKit

struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt8

    static let control = Modifiers(rawValue: 1 << 0)
    static let option = Modifiers(rawValue: 1 << 1)
    static let shift = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(_ flags: CGEventFlags) {
        var m: Modifiers = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        self = m
    }

    init(_ flags: NSEvent.ModifierFlags) {
        var m: Modifiers = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        self = m
    }

    /// ⌃⌥⇧⌘, in the order macOS menus use.
    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// A key press as the policy sees it.
struct KeyPress {
    var keyCode: UInt16
    var modifiers: Modifiers
    var isRepeat = false

    /// Option and shift alone still type characters, so only command and
    /// control make something a shortcut.
    var isShortcut: Bool {
        !modifiers.isDisjoint(with: [.command, .control])
    }
}

extension KeyPress {
    init(_ event: CGEvent) {
        keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        modifiers = Modifiers(event.flags)
        isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}

struct Shortcut: Codable, Hashable, Identifiable {
    var keyCode: UInt16
    var modifiers: Modifiers
    /// What to show for the key itself, e.g. "Tab" or "F".
    var key: String

    var id: String { "\(modifiers.rawValue)-\(keyCode)" }
    var display: String { modifiers.symbols + key }

    func matches(_ press: KeyPress) -> Bool {
        press.keyCode == keyCode && press.modifiers == modifiers
    }
}

extension Shortcut {
    /// Things that already mean "switch somewhere else" or belong to the system.
    static let defaults: [Shortcut] = [
        Shortcut(keyCode: 48, modifiers: .command, key: "Tab"),
        Shortcut(keyCode: 48, modifiers: [.command, .shift], key: "Tab"),
        Shortcut(keyCode: 50, modifiers: .command, key: "`"),
        Shortcut(keyCode: 49, modifiers: .command, key: "Space"),
        Shortcut(keyCode: 49, modifiers: .option, key: "Space"),
        Shortcut(keyCode: 123, modifiers: .control, key: "←"),
        Shortcut(keyCode: 124, modifiers: .control, key: "→"),
        Shortcut(keyCode: 125, modifiers: .control, key: "↓"),
        Shortcut(keyCode: 126, modifiers: .control, key: "↑"),
        Shortcut(keyCode: 20, modifiers: [.command, .shift], key: "3"),
        Shortcut(keyCode: 21, modifiers: [.command, .shift], key: "4"),
        Shortcut(keyCode: 23, modifiers: [.command, .shift], key: "5"),
    ]
}
