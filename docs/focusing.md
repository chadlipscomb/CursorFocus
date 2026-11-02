# Focusing a specific window

macOS has no public "make this window key" call that works across apps.
Since macOS 14, activating another app is also cooperative, so a background
app asking for some other app to come forward can be ignored.

The PoC uses public API only. Other options are written down here so we don't
have to rediscover them.

## What the PoC does

`WindowFocuser.focus`:

1. Finds the AX window whose frame matches the window server bounds (AX and
   CGWindowList ids can't be mapped without private API).
2. Sets `kAXMain` on it and performs `kAXRaise`.
3. Sets `kAXFrontmost` on the app.
4. Calls `NSRunningApplication.activate()` as a fallback.

The engine then checks that it worked before replaying keys.

**Limitation:** this always brings the window forward. The "Raise window when
focusing" setting exists but is disabled for that reason.

## Options considered

| Approach | Good | Bad |
|----------|------|-----|
| Public AX + activate (current) | Documented, should survive OS updates | Activation can be refused; multi-window apps sometimes key the wrong window; always raises |
| Private SkyLight (`_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`) | What AltTab and AutoRaise use. Targets the exact window, fast, can focus without raising, no SIP changes | Undocumented, can break in any release. Needs `dlsym` so a missing symbol degrades instead of crashing. Not allowed on the App Store |
| Synthetic click on the title bar | Uses the system's own click-to-focus | Hard to find a spot that's always inert (tabs, toolbars, double-click to zoom); windows without title bars; always raises |
| `CGEvent.postToPid` without focusing | No focus change | Keys go to the app's key window, not the hovered one; many apps ignore keys while inactive. Not usable |

If public focusing turns out to be unreliable in practice, the plan is
public first, then fall back to SkyLight, with a "public APIs only" switch.
Tracked in #20.
