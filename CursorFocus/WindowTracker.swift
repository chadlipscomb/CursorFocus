import AppKit

/// Remembers which window the cursor is over and when it got there, plus
/// which window has focus and when that last changed.
@MainActor
final class WindowTracker {
    private(set) var hovered: WindowInfo?
    private(set) var hoverEnteredAt = Date.distantPast
    private(set) var focused: WindowInfo?
    private(set) var focusChangedAt = Date.distantPast

    private var lastUpdate = Date.distantPast

    /// Called for every mouse move, so it's throttled. Hit testing walks the
    /// whole window list.
    func mouseMoved(to point: CGPoint, now: Date = .now) {
        guard now.timeIntervalSince(lastUpdate) > 0.03 else { return }
        update(point: point, now: now)
    }

    func update(point: CGPoint, now: Date = .now) {
        lastUpdate = now
        let window = Windows.under(point)
        if window?.id != hovered?.id {
            hoverEnteredAt = now
        }
        hovered = window
        refreshFocus(now: now)
    }

    /// App switches are reported by the engine as they happen. Window changes
    /// within an app (clicks, new windows) aren't observed directly; they're
    /// picked up on the next mouse move or key press by comparing against the
    /// last value we saw.
    func refreshFocus(now: Date = .now) {
        let window = NSWorkspace.shared.frontmostApplication.flatMap {
            Windows.frontmost(of: $0.processIdentifier)
        }
        if window?.id != focused?.id {
            focusChangedAt = now
        }
        focused = window
    }

    /// We just moved focus ourselves, so there's no need to wait for the next
    /// mouse move to notice.
    func focusMoved(to window: WindowInfo, at now: Date = .now) {
        focused = window
        focusChangedAt = now
    }
}
