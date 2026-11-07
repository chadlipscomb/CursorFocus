import AppKit
import ApplicationServices

#if APP_STORE

/// Brings a specific window forward and makes it key without Accessibility,
/// which the sandbox doesn't allow. Clicks the window's top edge, where
/// almost every app has title bar or resize area rather than content, then
/// puts the pointer back.
enum WindowFocuser {
    @MainActor
    static func focus(_ target: WindowInfo) {
        // Part of the top edge can be under another window, and a click
        // there would land in the wrong app.
        let b = target.bounds
        let edge = [0.5, 0.25, 0.75]
            .map { CGPoint(x: b.minX + b.width * $0, y: b.minY + 2) }
            .first { Windows.under($0)?.id == target.id }
        guard let edge else {
            NSRunningApplication(processIdentifier: target.pid)?.activate()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let pointer = CGEvent(source: nil)?.location

        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: edge, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
        if let pointer {
            CGWarpMouseCursorPosition(pointer)
            // Warping stalls pointer movement briefly unless this is reset.
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }
}

#else

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

#endif
