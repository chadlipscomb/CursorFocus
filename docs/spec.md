# Spec

## Problem

Keyboard focus on macOS stays on the last window you clicked. So you work in
window A, move the mouse over window B to read or scroll it, start typing or
hit cmd-F, and it all goes into A.

CursorFocus makes that first key press go to B, as long as you moved onto B
recently. By default hovering alone never changes focus; see "Switch on
hover" below.

## Rules

A key down is redirected to the hovered window W when:

1. The pointer is over a normal app window W (layer 0, on screen). Not the
   Dock, menu bar, desktop, menus, floating panels, or CursorFocus's own
   windows.
2. W isn't the focused window.
3. The pointer entered W within the time window (default 3 s). Entering again
   resets the clock. Nudging the mouse inside a window you've been parked on
   for a minute doesn't count.
4. The pointer entered W after focus last changed. Hover B, cmd-tab to A, type:
   it goes to A.
5. Neither the focused app nor W's app is excluded for that direction.
6. The key is a trigger and not a passthrough shortcut.
7. No mouse button is held, and CursorFocus is enabled and not paused.

Once redirected, W has focus, so the following keys go there normally.

### Triggers

- Typing: anything that produces text, plus Return, Delete, Tab, arrows
- Shortcuts: anything with cmd or control held. Option and shift alone count
  as typing since they produce characters
- Never: modifier-only presses, key repeat, media and brightness keys

"Redirect shortcuts" (default on) can be turned off so only typing redirects.

### Switch on hover

Off by default. When on, resting the pointer on a window for the hover delay
(0.1 to 2 s, default 0.5) focuses it without a key press. Rules 1, 2, 4, 5 and
7 still apply, so a cmd-tab while the pointer sits on another window sticks.
The delay restarts each time the pointer moves onto a different window.
Typing before the delay is up redirects as usual.

With public APIs the window is raised, so this behaves like auto-raise.

### Passthrough shortcuts

Never redirected. Defaults, all editable:

- cmd-tab, cmd-shift-tab, cmd-backtick
- cmd-space, option-space
- control-arrows (Spaces, Mission Control)
- cmd-shift-3, 4, 5 (screenshots)

cmd-Q, cmd-W and cmd-Delete are not in the defaults. They redirect like any
other shortcut. Add them to the list if you want them protected.

## Delivery

1. An active event tap sees key and mouse-move events before apps do.
2. On a redirect, the key is swallowed and buffered, along with anything else
   typed until focus lands.
3. The target window is focused (see [focusing.md](focusing.md)).
4. Once the target app is frontmost with W in front, or after 250 ms, the
   buffer is replayed in order. Keys are never dropped.

"Raise window when focusing" defaults to on. Focusing without raising needs
private API, so the toggle is disabled in the PoC.

## Exclusions

Per app, keyed by bundle id:

| Mode | Effect |
|------|--------|
| Never focus into | Typing never moves to this app's windows |
| Never steal from | While this app has focus, typing stays there |
| Both (default) | Ignored completely |

Add from running apps, from `/Applications`, or with "Exclude <app>" in the
menu.

Password fields use secure input, which hides keys from event taps anyway.

## Menu

- Enabled
- Pause: 15 minutes, 1 hour, until tomorrow / Resume
- Exclude <last app> / Stop excluding
- Last redirect (app and time)
- Settings…
- Quit

The icon changes when paused or disabled, and when Accessibility access is
missing.

## Settings

- General: enabled, time window (0.5 to 10 s), switch on hover and its
  delay, redirect shortcuts, raise window, launch at login
- Exclusions
- Shortcuts: passthrough list, record, restore defaults
- Permissions: Accessibility status and a link to System Settings

## Edge cases

| Case | Expected |
|------|----------|
| Same app, different window | Redirects. Window level, not app level |
| Menu open in the focused app | Should not redirect (#15) |
| IME composing | Should not redirect (#15) |
| Target app hung | Replay to whatever has focus after 250 ms |
| Multiple displays | Works, global coordinates throughout |
| Tap disabled by the system | Re-enabled immediately |

## Later

See the Polish and App Store milestones on the board: redirect flash,
debug panel, toggle hotkey, sandboxed build.

## Out of scope

- Focus-follows-mouse without raising (needs private API, #20)
- Moving the pointer to follow focus
- Redirecting mouse or scroll events (macOS already scrolls the hovered
  window)
