import AppKit
import ApplicationServices

/// Brings a specific window forward and makes it key, using only public
/// Accessibility API plus NSRunningApplication.
enum WindowFocuser {
    static func focus(_ target: WindowInfo) {
        let app = AXUIElementCreateApplication(target.pid)
        // Don't let a hung app stall the main thread (and with it, the tap).
        AXUIElementSetMessagingTimeout(app, 0.1)

        if let window = axWindow(in: app, matching: target.bounds) {
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        // Belt and braces. On 14+ this is a request the system can turn down,
        // which is why the AX frontmost attribute goes first.
        NSRunningApplication(processIdentifier: target.pid)?.activate()
    }

    /// AX and CGWindowList don't share window ids without private API, so
    /// match on the frame instead.
    private static func axWindow(in app: AXUIElement, matching bounds: CGRect) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }

        let match = windows.first { window in
            guard let frame = frame(of: window) else { return false }
            return abs(frame.minX - bounds.minX) < 2 && abs(frame.minY - bounds.minY) < 2
                && abs(frame.width - bounds.width) < 2 && abs(frame.height - bounds.height) < 2
        }
        return match ?? (windows.count == 1 ? windows.first : nil)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }

        var origin = CGPoint.zero
        var extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }
}
