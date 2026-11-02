# App Store notes

Shipping on the Mac App Store means App Sandbox. The current build is not
sandboxed. Here's what we know about each piece.

| Piece | Privilege | In the sandbox? |
|-------|-----------|-----------------|
| Listen-only `CGEventTap` | Input Monitoring | Yes. Apple DTS says they test this regularly |
| `CGEventTap` that swallows events | Probably Accessibility | Unknown. Nobody in the threads confirms it |
| `CGEvent.post` | PostEvent (shown under Accessibility, but it's a separate TCC service) | Yes, per DTS |
| `CGWindowListCopyWindowInfo` (ids, bounds, pids) | None | Yes. Window titles need Screen Recording, but we don't use them |
| AX (`AXUIElement…`) | Accessibility | No, not without a temporary exception entitlement |

So a sandboxed build loses AX. That leaves app-level activation and a
synthetic click (see [focusing.md](focusing.md)) as the ways to move focus.

## App Review

Even with the APIs working, review is a risk. A clipboard manager was
rejected under guideline 2.4.5 for using `CGEvent.post`, with the reviewer
saying Accessibility features shouldn't be used for non-accessibility
purposes. CursorFocus is arguably closer to an accessibility aid than a
clipboard manager is, but that's not something to count on.

## Plan

- #16 Spike a sandboxed build: does a swallowing tap work with Input
  Monitoring alone?
- #17 Window focusing without AX
- #18 How to pitch it in review notes, or decide it's a dead end

The code keeps the sandbox-hostile parts in `WindowFocuser` and
`Permissions` so a sandboxed variant would mostly swap those.

## Sources

- [Accessibility Permission In Sandbox For Keyboard](https://developer.apple.com/forums/thread/789896)
- [Clarification on Accessibility and Input Monitoring APIs for App Store Apps](https://developer.apple.com/forums/thread/780626)
- [Clipboard manager rejected under Guideline 2.4.5 for using CGEvent.post](https://developer.apple.com/forums/thread/820594)
