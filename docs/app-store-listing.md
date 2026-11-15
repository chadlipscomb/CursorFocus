# App Store listing

Drafts for App Store Connect. Limits are in brackets. The store build is
hover-only by default, so that's the first set. The full set is for when
`HOVER_ONLY` comes out.

## Name [30]

CursorFocus

## Hover-only

### Subtitle [30]

Focus follows your pointer

### Promotional text [170]

Rest the pointer on a window and it comes forward, ready for typing. No more
clicking a window just to type into it.

### Description [4000]

On a Mac, keyboard focus stays on the last window you clicked. Look over at
another window, start typing, and it all goes into the window you were in
before. So you click first, every time, sometimes on something you didn't
mean to.

CursorFocus brings the window under the pointer forward once the pointer has
rested on it for a moment. Glance across without stopping and nothing
happens. Stop on a window and it's ready for your keyboard.

- Adjustable delay, from a tenth of a second to two seconds
- Works across windows of the same app, not just between apps
- Exclude apps completely, or just in one direction
- Leaves you alone while you drag, and after you switch apps with ⌘Tab
- Pause for 15 minutes, an hour, or until tomorrow

CursorFocus lives in the menu bar. It needs permission to control the
computer, which it uses for one thing: clicking the title bar of the window
under the pointer to bring it forward. It never sees what you type and
doesn't collect, store or send anything.

### Keywords [100]

focus,window,mouse,pointer,cursor,hover,follows,keyboard,productivity,menu bar

### Review notes

CursorFocus is a menu bar utility for people who use the mouse to move
between windows. When the pointer rests on a window for a moment (0.5 s by
default), CursorFocus brings that window forward so the user can type into
it without clicking first.

How to try it:

1. Launch CursorFocus. A setup window explains the permission. Click
   Allow… and approve it in System Settings.
2. Open two TextEdit windows side by side and click into the left one.
3. Rest the pointer on the right one for half a second without clicking.
4. The right window comes forward and typing goes into it.

Why the permission:

- Event posting (listed under Accessibility in System Settings): to post one
  left click on the top edge of the window under the pointer, which is how a
  sandboxed app can bring a specific window forward. The pointer is put back
  where it was. Accessibility APIs would be the usual way, but they aren't
  available to sandboxed apps.

The app doesn't monitor the keyboard, makes no network connections and
collects no data. A screen recording is attached.

## Full

### Subtitle [30]

Type where you're pointing

### Promotional text [170]

Move the mouse to a window, start typing, and your keys go there. No more
typing into the window you left behind.

### Description [4000]

On a Mac, keyboard focus stays on the last window you clicked. Move the
pointer over another window to read it, start typing or press ⌘F, and it all
goes into the window you were in before.

CursorFocus fixes that. If you've moved the pointer onto a different window
in the last few seconds and start typing, that window gets focus first and
your keystrokes land there. Nothing is lost, even if you type fast.

It isn't focus-follows-mouse. Hovering alone changes nothing, unless you want
it to:

- Typing and shortcuts follow the pointer for a few seconds after you move
  it (adjustable)
- Optional switch on hover, after a short delay
- Shortcuts like ⌘Tab, ⌘Space and Spaces switching are never redirected, and
  you can add your own
- Exclude apps completely, or just in one direction
- Pause for 15 minutes, an hour, or until tomorrow

CursorFocus lives in the menu bar. It needs Input Monitoring to see key
presses before the focused app does, and permission to control the computer
to deliver them to the window under the pointer. It doesn't collect, store or
send anything.

### Keywords [100]

focus,window,mouse,pointer,cursor,typing,keyboard,hover,productivity,menu bar

### Review notes

CursorFocus is a menu bar utility for people who use the mouse to move
between windows. When the pointer has recently moved onto a different
window and the user starts typing, CursorFocus brings that window forward
first so the keystrokes reach the window the user is looking at.

How to try it:

1. Launch CursorFocus. A setup window explains both permissions. Click
   Allow… on each and approve them in System Settings.
2. Open two TextEdit windows side by side and click into the left one.
3. Move the pointer over the right one and type within 3 seconds.
4. The text appears in the right window.

Why the permissions:

- Input Monitoring: to see a key press before it reaches the focused app,
  hold it while focus moves, and then deliver it. Keys are never stored,
  logged or sent anywhere.
- Event posting: to deliver the held key presses to the new window, and to
  click the target window's title bar to focus it. Accessibility APIs would
  be the usual way to focus a window, but they aren't available to sandboxed
  apps.

The app makes no network connections and collects no data. A screen
recording is attached.

## Support URL

Same site as the privacy policy.
