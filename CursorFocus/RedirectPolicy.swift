import Foundation
import CoreGraphics

/// Decides whether a key press should go to the window under the cursor
/// instead of the focused one. No side effects, so it can be tested directly.
struct RedirectPolicy {
    var window: TimeInterval = 3
    var redirectShortcuts = true
    var exclusions: [Exclusion] = []
    var passthrough: [Shortcut] = Shortcut.defaults

    struct Target: Equatable {
        var windowID: CGWindowID
        var bundleID: String?
    }

    struct Context {
        var hovered: Target?
        var hoverEnteredAt: Date
        var focused: Target?
        var focusChangedAt: Date
        var mouseButtonDown = false
        var now: Date
    }

    func shouldRedirect(_ key: KeyPress, in ctx: Context) -> Bool {
        if key.isRepeat { return false }
        // The cursor has to have arrived recently.
        if ctx.now.timeIntervalSince(ctx.hoverEnteredAt) > window { return false }

        if key.isShortcut && !redirectShortcuts { return false }
        if passthrough.contains(where: { $0.matches(key) }) { return false }

        return canMoveFocus(in: ctx)
    }

    /// For "switch on hover": the pointer has rested on the hovered window
    /// long enough, should it take focus without a key press?
    func shouldFocusOnHover(in ctx: Context) -> Bool {
        canMoveFocus(in: ctx)
    }

    /// The checks shared by typing and hovering.
    private func canMoveFocus(in ctx: Context) -> Bool {
        if ctx.mouseButtonDown { return false }
        guard let hovered = ctx.hovered, hovered.windowID != ctx.focused?.windowID else { return false }

        // The cursor has to have arrived after focus last moved. If you hover
        // B and then cmd-tab to A, you meant A.
        if ctx.hoverEnteredAt <= ctx.focusChangedAt { return false }

        if isExcluded(hovered.bundleID, from: .neverFocusInto) { return false }
        if isExcluded(ctx.focused?.bundleID, from: .neverStealFrom) { return false }

        return true
    }

    private func isExcluded(_ bundleID: String?, from mode: Exclusion.Mode) -> Bool {
        guard let bundleID, let exclusion = exclusions.first(where: { $0.bundleID == bundleID }) else {
            return false
        }
        return exclusion.mode == .both || exclusion.mode == mode
    }
}
