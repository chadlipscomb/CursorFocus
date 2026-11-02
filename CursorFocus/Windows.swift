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
    static func under(_ point: CGPoint) -> WindowInfo? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for entry in list() {
            guard let (window, layer) = info(entry), window.bounds.contains(point) else { continue }
            if window.pid == ownPID || layer != 0 { return nil }
            return window
        }
        return nil
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
