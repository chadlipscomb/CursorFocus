# Development

## Requirements

- Xcode 16 or later (the project uses folder-synced groups, so new files in
  `CursorFocus/` or `CursorFocusTests/` show up without touching the project)
- macOS 14 or later

## Accessibility grant vs. rebuilds

macOS ties the Accessibility grant to the app's code signature. The project
signs ad hoc ("Sign to Run Locally"), so every rebuild looks like a new app
and the old grant stops working, even though the checkbox in System Settings
is still on.

Options:

- Set your team under Signing & Capabilities. With a stable Apple Development
  certificate the grant survives rebuilds. Don't commit the team id.
- Or reset and grant again:

  ```sh
  tccutil reset Accessibility com.chadlipscomb.CursorFocus
  ```

Tracked in #19.

## Logs

Redirects and failures go to the unified log:

```sh
log stream --predicate 'subsystem == "com.chadlipscomb.CursorFocus"' --level info
```

## Manual test checklist

- Hover a different window, type within 3 s: text lands in the hovered window
- Same after 4 s: text stays in the focused window
- Hover, then cmd-F: find opens in the hovered window
- Hover, cmd-tab: normal app switcher, no redirect
- Hover B, cmd-tab back to A, type: goes to A
- Excluded apps behave per their mode
- Type fast right after hovering: nothing lost, nothing out of order
- Toggle off: behaves like stock macOS
- Switch on hover: resting on a window focuses it after the delay; sweeping
  across windows quickly doesn't; cmd-tab while resting on another window sticks
- First launch with no permission: setup window opens centered, no system
  prompt until Allow… is clicked, row turns green once granted
- Sleep/wake, plugging in a display, revoking and re-granting Accessibility
