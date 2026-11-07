import Foundation
import Testing
@testable import CursorFocus

struct RedirectPolicyTests {
    let now = Date(timeIntervalSinceReferenceDate: 10_000)
    let a = RedirectPolicy.Target(windowID: 1, bundleID: "com.apple.Terminal")
    let b = RedirectPolicy.Target(windowID: 2, bundleID: "com.apple.Safari")

    let typeH = KeyPress(keyCode: 4, modifiers: [])
    let cmdF = KeyPress(keyCode: 3, modifiers: .command)

    /// Focus on A since a while ago, cursor entered B one second ago.
    func context(enteredAgo: TimeInterval = 1, focusChangedAgo: TimeInterval = 60) -> RedirectPolicy.Context {
        RedirectPolicy.Context(
            hovered: b,
            hoverEnteredAt: now - enteredAgo,
            focused: a,
            focusChangedAt: now - focusChangedAgo,
            now: now
        )
    }

    @Test func redirectsTypingIntoRecentlyHoveredWindow() {
        #expect(RedirectPolicy().shouldRedirect(typeH, in: context()))
    }

    @Test func redirectsShortcutsByDefault() {
        #expect(RedirectPolicy().shouldRedirect(cmdF, in: context()))
    }

    @Test func ignoresHoverOlderThanTheWindow() {
        #expect(!RedirectPolicy().shouldRedirect(typeH, in: context(enteredAgo: 3.5)))
        #expect(RedirectPolicy(window: 5).shouldRedirect(typeH, in: context(enteredAgo: 3.5)))
    }

    @Test func focusChangeAfterHoverWins() {
        // Hovered B, then cmd-tabbed to A.
        #expect(!RedirectPolicy().shouldRedirect(typeH, in: context(enteredAgo: 2, focusChangedAgo: 1)))
    }

    @Test func nothingToDoWhenHoveringTheFocusedWindow() {
        var ctx = context()
        ctx.hovered = a
        #expect(!RedirectPolicy().shouldRedirect(typeH, in: ctx))
    }

    @Test func nothingToDoWhenNotOverAWindow() {
        var ctx = context()
        ctx.hovered = nil
        #expect(!RedirectPolicy().shouldRedirect(typeH, in: ctx))
    }

    @Test func notWhileAMouseButtonIsHeld() {
        var ctx = context()
        ctx.mouseButtonDown = true
        #expect(!RedirectPolicy().shouldRedirect(typeH, in: ctx))
    }

    @Test func notForKeyRepeat() {
        var key = typeH
        key.isRepeat = true
        #expect(!RedirectPolicy().shouldRedirect(key, in: context()))
    }

    @Test func shortcutsCanBeTurnedOff() {
        let policy = RedirectPolicy(redirectShortcuts: false)
        #expect(!policy.shouldRedirect(cmdF, in: context()))
        #expect(!policy.shouldRedirect(KeyPress(keyCode: 0, modifiers: .control), in: context()))
        // Shift and option still type characters.
        #expect(policy.shouldRedirect(KeyPress(keyCode: 4, modifiers: .shift), in: context()))
        #expect(policy.shouldRedirect(KeyPress(keyCode: 14, modifiers: .option), in: context()))
    }

    @Test(arguments: Shortcut.defaults)
    func defaultPassthroughsNeverRedirect(shortcut: Shortcut) {
        let key = KeyPress(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        #expect(!RedirectPolicy().shouldRedirect(key, in: context()))
    }

    @Test func passthroughNeedsExactModifiers() {
        // Plain left arrow isn't ctrl-left.
        #expect(RedirectPolicy().shouldRedirect(KeyPress(keyCode: 123, modifiers: []), in: context()))
        // cmd-Q and cmd-W are deliberately not protected.
        #expect(RedirectPolicy().shouldRedirect(KeyPress(keyCode: 12, modifiers: .command), in: context()))
        #expect(RedirectPolicy().shouldRedirect(KeyPress(keyCode: 13, modifiers: .command), in: context()))
    }

    @Test func excludedHoveredApp() {
        for mode in [Exclusion.Mode.both, .neverFocusInto] {
            let policy = RedirectPolicy(exclusions: [Exclusion(bundleID: "com.apple.Safari", name: "Safari", mode: mode)])
            #expect(!policy.shouldRedirect(typeH, in: context()), "\(mode)")
        }
        let policy = RedirectPolicy(exclusions: [Exclusion(bundleID: "com.apple.Safari", name: "Safari", mode: .neverStealFrom)])
        #expect(policy.shouldRedirect(typeH, in: context()))
    }

    @Test func excludedFocusedApp() {
        for mode in [Exclusion.Mode.both, .neverStealFrom] {
            let policy = RedirectPolicy(exclusions: [Exclusion(bundleID: "com.apple.Terminal", name: "Terminal", mode: mode)])
            #expect(!policy.shouldRedirect(typeH, in: context()), "\(mode)")
        }
        let policy = RedirectPolicy(exclusions: [Exclusion(bundleID: "com.apple.Terminal", name: "Terminal", mode: .neverFocusInto)])
        #expect(policy.shouldRedirect(typeH, in: context()))
    }

    // MARK: Switch on hover

    @Test func hoverFocusesAnotherWindow() {
        // The delay is the engine's job, so the hover age doesn't matter here.
        #expect(RedirectPolicy().shouldFocusOnHover(in: context(enteredAgo: 30)))
    }

    @Test func hoverFollowsTheSameRules() {
        let policy = RedirectPolicy()
        #expect(!policy.shouldFocusOnHover(in: context(enteredAgo: 2, focusChangedAgo: 1)))

        var ctx = context()
        ctx.mouseButtonDown = true
        #expect(!policy.shouldFocusOnHover(in: ctx))

        ctx = context()
        ctx.hovered = a
        #expect(!policy.shouldFocusOnHover(in: ctx))

        let excluded = RedirectPolicy(exclusions: [Exclusion(bundleID: "com.apple.Safari", name: "Safari")])
        #expect(!excluded.shouldFocusOnHover(in: context()))
    }
}
