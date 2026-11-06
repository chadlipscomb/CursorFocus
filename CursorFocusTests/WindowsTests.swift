import CoreGraphics
import Testing
@testable import CursorFocus

struct WindowsTests {
    let display = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let me: pid_t = 1
    let point = CGPoint(x: 500, y: 500)

    func window(_ id: CGWindowID, pid: pid_t = 2, _ bounds: CGRect) -> WindowInfo {
        WindowInfo(id: id, pid: pid, bounds: bounds)
    }

    @Test func findsTopmostAppWindow() {
        let front = window(1, CGRect(x: 0, y: 0, width: 800, height: 800))
        let back = window(2, CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let hit = Windows.hit(point, in: [(front, 0), (back, 0)], displays: [display], ownPID: me)
        #expect(hit == front)
    }

    @Test func looksThroughFullDisplayOverlay() {
        let dock = window(1, pid: 3, display)
        let app = window(2, CGRect(x: 0, y: 30, width: 2560, height: 1222))
        let hit = Windows.hit(point, in: [(dock, 20), (app, 0)], displays: [display], ownPID: me)
        #expect(hit == app)
    }

    @Test func menuOrPanelBlocks() {
        let menu = window(1, pid: 3, CGRect(x: 400, y: 400, width: 200, height: 300))
        let app = window(2, display)
        #expect(Windows.hit(point, in: [(menu, 101), (app, 0)], displays: [display], ownPID: me) == nil)
    }

    @Test func ownWindowBlocks() {
        let settings = window(1, pid: me, CGRect(x: 400, y: 400, width: 460, height: 500))
        let app = window(2, display)
        #expect(Windows.hit(point, in: [(settings, 0), (app, 0)], displays: [display], ownPID: me) == nil)
    }
}
