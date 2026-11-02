# Architecture

Everything runs on the main thread. There are no background queues and no
helper processes.

```
 CGEventTap (keys + mouse moves)
        │
        ▼
     Engine ──────► WindowTracker ──► Windows (CGWindowList)
        │                 hovered window + when it was entered
        │                 focused window + when focus last changed
        │
        ├─► RedirectPolicy  (pure: should this key redirect?)
        │
        └─► WindowFocuser   (AX raise/main/frontmost + activate)
                then replay held keys with CGEvent.post
```

## Files

| File | What it does |
|------|--------------|
| `CursorFocusApp.swift` | App entry point, menu bar item, settings scene, app delegate |
| `Engine.swift` | Owns the event tap, holds keys during a switch, replays them |
| `WindowTracker.swift` | Hovered window, focused window, and their timestamps |
| `Windows.swift` | Hit testing and lookups over `CGWindowListCopyWindowInfo` |
| `RedirectPolicy.swift` | The rules. No side effects, covered by tests |
| `WindowFocuser.swift` | Focuses a specific window with public AX calls |
| `Shortcut.swift` | Modifiers, key presses, passthrough shortcuts and defaults |
| `Preferences.swift` | Settings in `UserDefaults`, exclusions, pause |
| `Permissions.swift` | Accessibility check, prompt, and deep link |
| `MenuContent.swift` | Menu bar menu and icon |
| `SettingsView.swift`, `ExclusionSettings.swift`, `ShortcutSettings.swift` | Settings window tabs |

## Key flow

1. Mouse moves update `WindowTracker` (throttled to about 30 per second).
2. On a key down, `Engine` refreshes the tracker for the current pointer
   position and asks `RedirectPolicy`.
3. If the answer is no, the event goes through untouched.
4. If yes, the event is swallowed and copied into a buffer.
   `WindowFocuser.focus` is called, and a task polls every 10 ms until the
   target app is frontmost and its frontmost window is the target, giving up
   after 250 ms.
5. Every key event that arrives in the meantime (down, up, modifier changes)
   goes into the same buffer.
6. The buffer is posted back with `CGEvent.post`, stamped with a marker in
   `eventSourceUserData` so the tap lets those events through.

Keys are never dropped. If focusing times out, the buffer is replayed to
whatever has focus at that point.

## Focus tracking without AX

The focused window is approximated as the frontmost layer-0 window of the
frontmost app. This avoids `_AXUIElementGetWindow` (private) for mapping AX
windows to window server ids. It's wrong for apps where a floating panel sits
in front of the document window, which is an accepted PoC limitation.

Focus changes aren't observed directly. The tracker compares against the last
value it saw on every mouse move and key press, and records the time it
noticed a change.

## Tests

`CursorFocusTests` is hosted in the app. The app delegate skips the tap and
permission prompt when `XCTestConfigurationFilePath` is set. Tests use Swift
Testing and cover the policy rules.
