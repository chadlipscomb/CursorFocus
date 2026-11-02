import AppKit

/// Remembers which window the cursor is over and when it got there.
@MainActor
final class WindowTracker {
    private(set) var hovered: WindowInfo?
    private(set) var hoverEnteredAt = Date.distantPast

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
    }
}
