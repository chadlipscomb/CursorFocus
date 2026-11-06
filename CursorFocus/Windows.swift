import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
}

/// Queries the window server. Coordinates are global with the origin at the
/// top left of the main display, same as CGEvent locations.
enum Windows {
    /// On-screen windows, front to back.
    private static func list() -> [[String: Any]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        return CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private static func info(_ entry: [String: Any]) -> (window: WindowInfo, layer: Int)? {
        guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
              let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
              let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else { return nil }
        // Some apps keep fully transparent windows on screen. They can't be seen,
        // so they shouldn't count as being "under" the cursor.
        if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha == 0 { return nil }
        let layer = entry[kCGWindowLayer as String] as? Int ?? 0
        return (WindowInfo(id: id, pid: pid, bounds: bounds), layer)
    }

    /// The normal app window under `point`, or nil if the point is over the
    /// Dock, menu bar, a menu, a floating panel, the desktop, or our own windows.
    @MainActor
    static func under(_ point: CGPoint) -> WindowInfo? {
        // The Dock and menu bar are drawn in windows that span the whole
        // display, so they're ruled out by position instead.
        guard usableAreas().contains(where: { $0.contains(point) }) else { return nil }
        return hit(point,
                   in: list().compactMap(info),
                   displays: displayBounds(),
                   ownPID: ProcessInfo.processInfo.processIdentifier)
    }

    /// `windows` front to back. Split out from `under` so it can be tested
    /// without a window server.
    static func hit(_ point: CGPoint, in windows: [(window: WindowInfo, layer: Int)],
                    displays: [CGRect], ownPID: pid_t) -> WindowInfo? {
        for (window, layer) in windows where window.bounds.contains(point) {
            if window.pid == ownPID { return nil }
            if layer == 0 { return window }
            // The Dock keeps an invisible window over the entire display, above
            // everything else. Anything that size isn't something you'd be
            // pointing at, so look through it.
            if displays.contains(window.bounds) { continue }
            return nil
        }
        return nil
    }

    private static func displayBounds() -> [CGRect] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        return ids.prefix(Int(count)).map(CGDisplayBounds)
    }

    /// Each screen minus the menu bar and Dock, flipped into window coordinates.
    @MainActor
    private static func usableAreas() -> [CGRect] {
        guard let primary = NSScreen.screens.first?.frame else { return [] }
        return NSScreen.screens.map {
            let r = $0.visibleFrame
            return CGRect(x: r.minX, y: primary.maxY - r.maxY, width: r.width, height: r.height)
        }
    }

    /// The frontmost normal window belonging to `pid`. For the active app this
    /// is close enough to "the focused window" without needing private API.
    static func frontmost(of pid: pid_t) -> WindowInfo? {
        for entry in list() {
            guard let (window, layer) = info(entry), layer == 0, window.pid == pid,
                  window.bounds.width > 40, window.bounds.height > 40
            else { continue }
            return window
        }
        return nil
    }
}
