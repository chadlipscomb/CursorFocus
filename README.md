# CursorFocus

Menu bar app for macOS. If you move the mouse over a window and start typing,
your keystrokes go to that window instead of the one that still has focus.

By default it is not focus-follows-mouse. Hovering never changes anything on
its own. Only the first key press after you move onto a window does, and only
if you moved there in the last few seconds. Turn on "Switch on hover" if you
want focus to follow the pointer without typing.

## How it decides

When you press a key, CursorFocus moves focus to the window under the pointer
if all of these are true:

- the pointer is over a normal app window that doesn't have focus
- it moved onto that window within the time window (3 seconds by default)
- it moved there *after* focus last changed, so hovering B and then
  cmd-tabbing to A still types into A
- neither app is excluded
- the key isn't a passthrough shortcut (cmd-tab, cmd-space, and so on)
- no mouse button is held down

The key that triggered the switch, and anything typed while focus was moving,
is held and then delivered to the new window in order.

## Settings

- **Time window**: 0.5 to 10 seconds
- **Switch on hover**: off by default. Focuses the window under the pointer
  once it has been there for the delay (0.5 s by default), no typing needed.
  Same rules as above, minus the key checks
- **Redirect shortcuts**: on by default; turn off to only redirect plain typing
- **Raise window when focusing**: always on for now (see
  [docs/focusing.md](docs/focusing.md))
- **Exclusions**: per app, "never focus into", "never steal from", or both
- **Passthrough shortcuts**: shortcuts that never redirect
- **Pause** from the menu for 15 minutes, an hour, or until tomorrow
- **Launch at login**

## Building

Requires Xcode 16 or later and macOS 14 or later.

Open `CursorFocus.xcodeproj` and run the `CursorFocus` scheme, or:

```sh
xcodebuild -project CursorFocus.xcodeproj -scheme CursorFocus build
xcodebuild -project CursorFocus.xcodeproj -scheme CursorFocus test
```

On first launch a setup window explains the Accessibility permission and asks
for it. See
[docs/development.md](docs/development.md) for why that grant disappears after
rebuilding and what to do about it.

The `CursorFocus App Store` scheme builds the sandboxed, hover-only variant. See
[docs/app-store.md](docs/app-store.md).

## Docs

- [Spec](docs/spec.md)
- [Architecture](docs/architecture.md)
- [Focusing windows](docs/focusing.md)
- [Getting on the App Store](docs/app-store.md), [listing](docs/app-store-listing.md), [privacy policy](docs/privacy.md)
- [Development](docs/development.md)

Planning happens on the [project board](https://github.com/users/chadlipscomb/projects/2).
