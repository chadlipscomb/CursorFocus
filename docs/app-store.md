# Getting on the Mac App Store

Short version: the App Store build has to be sandboxed, and sandboxed apps
can't use Accessibility at all. Apple DTS is explicit about it, and the
permission prompt never even shows up. So the App Store build is a different
variant that focuses windows by clicking them. By default it's also
**hover-only**: no typing redirect, so it never looks at the keyboard and needs
one permission instead of two. It hasn't been tried on a real machine yet.

Direct distribution (Developer ID + notarization) has none of these
problems, and uses the same paid account. Worth doing either way.

## What's already done

- **AppStore build configuration** and a **CursorFocus App Store** scheme.
  Sandboxed via `Config/AppStore.entitlements`, compiled with `APP_STORE` and
  `HOVER_ONLY`. CI builds it on every push.
- **Sandbox variants** of the two pieces that need it:
  - `Permission`: asks for event posting (and Input Monitoring, if typing
    redirect is on) instead of Accessibility.
  - `WindowFocuser`: clicks the hovered window's top edge (title bar or
    resize area in nearly every app), picking a spot that isn't covered by
    another window, then puts the pointer back. Falls back to app-level
    activation if the whole edge is covered.
- **Hover-only variant** (`HOVER_ONLY`, see below). Watches the mouse with a
  global `NSEvent` monitor, which needs no permission, and focuses the window
  under the pointer after the hover delay. Settings hides everything that only
  applies to typing.
- **Setup window**. On first launch, before any system prompt, it says what
  the app does and why it needs each permission. The system prompts come from
  its Allow buttons, not from launching the app. It stays reachable from the
  menu ("Finish Setup…") while anything is missing, so a reviewer who clicks
  Don't Allow still gets a way forward instead of a broken-looking app.
- **Fallback** for the full variant if the system only allows a listen-only
  event tap: keys can't be held back and replayed, so typing isn't
  redirected, but switch on hover still works. The menu says so.
- **App icon**, **privacy manifest** (`PrivacyInfo.xcprivacy`: no tracking,
  no data collected, UserDefaults reason CA92.1), **export compliance**
  (`ITSAppUsesNonExemptEncryption = NO` in `Config/Info.plist`, so no
  encryption questions on every upload), copyright string, Utilities
  category.
- **Listing text** for both variants in
  [app-store-listing.md](app-store-listing.md), privacy policy in
  [privacy.md](privacy.md).

## Hover-only or full

| | Hover-only (default) | Full |
|---|---|---|
| What it does | Focuses the window under the pointer after a short rest | That, plus typing follows the pointer |
| Permissions | Accessibility (shown as controlling the computer; it's event posting) | Input Monitoring and Accessibility |
| Sees key presses | Never | Yes, holds them briefly while focus moves |
| Review risk | Lower. One permission, used for one click | Higher. Reads and replays keystrokes, the 2.4.5 pattern |

To ship the full app on the store, open the project's build settings, pick
the CursorFocus target, AppStore configuration, and remove `HOVER_ONLY` from
**Active Compilation Conditions**. Then use the "Full" listing text and review
notes, and fix the first line of the key presses paragraph in
[privacy.md](privacy.md), which says the store version never looks at the
keyboard.

The suggested path: submit hover-only first. Once it's on the store, an
update that adds typing redirect gets reviewed against an app that's already
approved.

## Keeping App Review happy

What the build already does about it is above (setup window, one permission,
nothing broken when a permission is denied). The rest is on the submission:

- **Attach a screen recording** to the review notes: the setup window, the
  permission prompt, then the TextEdit demo. 30 seconds is plenty. A reviewer
  who doesn't get what a utility is for rejects it.
- **Say plainly what it does** in the review notes, including that it posts a
  synthetic click, and why Accessibility isn't an option in the sandbox.
  Drafts are in the listing doc. Don't pitch it as an accessibility app; that
  invites "these APIs are for accessibility purposes".
- **Screenshots of the real app**, the menu and Settings, not only marketing
  text (2.3).
- **TestFlight external testing first**. Its review is lighter and gives early
  warning.
- **If it's rejected under 2.4.5**, reply in Resolution Center asking which
  part of 2.4.5 it violates (nothing there forbids posting events), then
  appeal to the App Review Board if needed.

## What's unknown

| Question | How we find out | If the answer is bad |
|----------|-----------------|----------------------|
| Does clicking the top edge focus the right window in the apps you use, without side effects? | Step 2 below | Tune where it clicks |
| Does `CGRequestPostEventAccess` prompt and work from the sandbox? | Step 2 below | Skip the App Store |
| Full variant only: can a sandboxed app create an event tap that swallows keys with only Input Monitoring? | Step 2 with `HOVER_ONLY` removed | Stay hover-only |
| Will App Review accept it? | Submit (step 6) | Appeal, or direct distribution only |

On review: a clipboard manager was rejected under guideline 2.4.5 for using
`CGEvent.post`, the reviewer saying those features are for accessibility
purposes. PopClip left the store in 2024 over Accessibility in a sandboxed
update. Window managers like Magnet are on the store, but likely predate the
sandbox requirement or are grandfathered. Be ready for at least one round
with the reviewer.

## What you need to do

### 1. Developer account and signing

1. Join the Apple Developer Program if you haven't ($99/year):
   <https://developer.apple.com/programs/enroll/>
2. Xcode > Settings > Accounts: add your Apple ID.
3. Select the CursorFocus target > Signing & Capabilities. For the AppStore
   configuration, pick your team. Leave "Automatically manage signing" on;
   Xcode registers the bundle id `com.chadlipscomb.CursorFocus` for you.
   Setting the team also fixes #19 (Accessibility lost on every rebuild) for
   the direct build.

### 2. Try the sandboxed build

This is the step that decides whether the rest is worth it.

1. Quit the normal CursorFocus. Both builds share a bundle id, so start
   clean: `tccutil reset All com.chadlipscomb.CursorFocus`.
2. In Xcode, switch to the **CursorFocus App Store** scheme and press ⌘R.
3. The setup window opens. Click **Allow…** and approve the prompt (it lands
   under Accessibility in System Settings). The row should tick over to
   green on its own within a second.
4. Check:
   - Rest the pointer on another window: it comes forward after the delay
     (Settings > General, 0.5 s by default), and you can type into it.
   - Same for a second window of the same app, and for Obsidian and Helium,
     whose title bars are custom.
   - The pointer doesn't visibly jump, and nothing gets clicked that
     shouldn't (a tab, a button in a custom title bar).
   - Sweeping across windows quickly doesn't focus them.
   - Deny the permission instead (or reset and relaunch): the menu says it
     needs permission, and Finish Setup… reopens the window.
5. Watch the log while testing:

   ```sh
   log stream --predicate 'subsystem == "com.chadlipscomb.CursorFocus"' --level debug
   ```

To try the full variant too, remove `HOVER_ONLY` (above) and repeat: two
permissions this time, and the menu must not say "Typing can't be
redirected".

### 3. Privacy policy URL

App Store Connect needs a public URL, and this repo is private. Put
[privacy.md](privacy.md) somewhere public: a public gist, a page on your own
site, or a small public repo with GitHub Pages. Fill in the contact address
first (`CONTACT_EMAIL`); it will be public.

### 4. App Store Connect record

At <https://appstoreconnect.apple.com> > Apps > + > New App:

- Platform macOS, name **CursorFocus** (free on the store as of November
  2026), language English (U.S.), bundle id from step 1, SKU `cursorfocus`.
- Category: Utilities, secondary Productivity.
- Price: your call.
- Age rating questionnaire: all "none", which gives 4+.
- App Privacy: "Data Not Collected".
- Privacy policy URL from step 3, support URL (can be the same site).
- Paste the listing text for the variant you're shipping from
  [app-store-listing.md](app-store-listing.md).

### 5. Screenshots

At least one, 16:10, at 1280×800, 1440×900, 2560×1600 or 2880×1800. Suggested:

1. Two windows side by side with the pointer resting on the one coming
   forward, and the menu open.
2. The setup window.
3. Settings > General.
4. Settings > Exclusions with a couple of apps.

Record the screen recording for the review notes at the same time.

### 6. Archive and submit

1. Scheme **CursorFocus App Store**, Product > Archive.
2. Organizer > Distribute App > App Store Connect > Upload.
3. In App Store Connect, add the build to TestFlight first and run it from
   there once, since that's the real sandboxed, store-signed binary.
4. Fill in the review notes (drafted in the listing doc), attach the screen
   recording, submit.

## Also worth doing: direct download

With the same account:

1. Scheme **CursorFocus**, Product > Archive > Distribute App > Direct
   Distribution. Xcode signs with Developer ID and notarizes.
2. Attach the exported app to a GitHub release.

That build keeps the Accessibility version with typing redirect (better
focusing, no clicks), opens without the Gatekeeper warning, and keeps its
permission across updates.

## Sources

- [Accessibility Permission In Sandbox For Keyboard](https://developer.apple.com/forums/thread/789896) (DTS: Input Monitoring taps and `CGEvent.post` work in the sandbox)
- [AXIsProcessTrusted returns true, but AXUIElementCopyAttributeValue fails](https://developer.apple.com/forums/thread/794253) (DTS: Accessibility isn't supported in sandboxed apps)
- [Accessibility permission not granted for sandboxed menu bar app](https://developer.apple.com/forums/thread/810677)
- [Unable to submit my macOS window-manager app](https://developer.apple.com/forums/thread/805556)
- [Clipboard manager rejected under Guideline 2.4.5 for using CGEvent.post](https://developer.apple.com/forums/thread/820594)
- [The Mac App Store won't let window managers exist](https://blakecrosley.com/blog/window-manager-mac-app-store-sandbox)
- [A window switcher on the Mac App Store?](https://alinpanaitiu.com/blog/window-switcher-app-store/)
