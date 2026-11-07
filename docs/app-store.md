# Getting on the Mac App Store

Short version: the App Store build has to be sandboxed, and sandboxed apps
can't use Accessibility at all. Apple DTS is explicit about it, and the
permission prompt never even shows up. So the App Store build is a different
variant that focuses windows by clicking them, and it hasn't been tried on a
real machine yet. Whether App Review accepts it is a separate question.

Direct distribution (Developer ID + notarization) has none of these
problems, and uses the same paid account. Worth doing either way.

## What's already done

- **AppStore build configuration** and a **CursorFocus App Store** scheme.
  Sandboxed via `Config/AppStore.entitlements`, compiled with `APP_STORE`.
- **Sandbox variants** of the two pieces that need it:
  - `Permissions`: asks for Input Monitoring and event posting instead of
    Accessibility.
  - `WindowFocuser`: clicks the hovered window's top edge (title bar or
    resize area in nearly every app), picking a spot that isn't covered by
    another window, then puts the pointer back. Falls back to app-level
    activation if the whole edge is covered.
- **Fallback** if the system only allows a listen-only event tap: keys can't
  be held back and replayed, so typing isn't redirected, but switch on hover
  still works. The menu says so when it happens.
- **App icon**, **privacy manifest** (`PrivacyInfo.xcprivacy`: no tracking,
  no data collected, UserDefaults reason CA92.1), **export compliance**
  (`ITSAppUsesNonExemptEncryption = NO` in `Config/Info.plist`, so no
  encryption questions on every upload), copyright string, Utilities
  category.
- **Listing text** drafted in [app-store-listing.md](app-store-listing.md),
  privacy policy in [privacy.md](privacy.md).

## What's unknown

| Question | How we find out | If the answer is bad |
|----------|-----------------|----------------------|
| Can a sandboxed app create an event tap that swallows keys with only Input Monitoring? | Step 2 below | Ship hover-only, or skip the App Store |
| Does clicking the top edge focus the right window in the apps you use, without side effects? | Step 2 below | Tune where it clicks, or hover-only |
| Will App Review accept an app that reads keystrokes and posts synthetic keys and clicks? | Submit (step 6) | Appeal with the review notes, or direct distribution only |

On review: a clipboard manager was rejected under guideline 2.4.5 for using
`CGEvent.post`, the reviewer saying those features are for accessibility
purposes. PopClip left the store in 2024 over Accessibility in a sandboxed
update. Window managers like Magnet are on the store, but likely predate the
sandbox requirement or are grandfathered. Expect at least one rejection.

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

1. Quit the normal CursorFocus.
2. In Xcode, switch to the **CursorFocus App Store** scheme and press ⌘R.
3. Allow **Input Monitoring** when asked, and allow it to **control the
   computer** (that's event posting; it shows up under Accessibility).
4. Check:
   - The menu doesn't say "Typing can't be redirected". If it does, the
     sandbox refused the active tap.
   - Hover another window and type: text lands there.
   - Same for a second window of the same app, and for Obsidian and Helium,
     whose title bars are custom.
   - Switch on hover works, and the pointer doesn't visibly jump.
5. Watch the log while testing:

   ```sh
   log stream --predicate 'subsystem == "com.chadlipscomb.CursorFocus"' --level debug
   ```

Both builds share a bundle id, so switching between them may need
`tccutil reset All com.chadlipscomb.CursorFocus`.

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
- Paste the listing text from [app-store-listing.md](app-store-listing.md).

### 5. Screenshots

At least one, 16:10, at 1280×800, 1440×900, 2560×1600 or 2880×1800. Suggested:

1. The menu open over two windows, one of them obviously the one being typed
   into.
2. Settings > General.
3. Settings > Exclusions with a couple of apps.

A short screen recording for the review notes helps more than screenshots
for a reviewer who doesn't get what the app is for.

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

That build keeps the Accessibility version (better focusing, no clicks), opens
without the Gatekeeper warning, and keeps its permission across updates.

## Sources

- [Accessibility Permission In Sandbox For Keyboard](https://developer.apple.com/forums/thread/789896) (DTS: Input Monitoring taps and `CGEvent.post` work in the sandbox)
- [AXIsProcessTrusted returns true, but AXUIElementCopyAttributeValue fails](https://developer.apple.com/forums/thread/794253) (DTS: Accessibility isn't supported in sandboxed apps)
- [Accessibility permission not granted for sandboxed menu bar app](https://developer.apple.com/forums/thread/810677)
- [Unable to submit my macOS window-manager app](https://developer.apple.com/forums/thread/805556)
- [Clipboard manager rejected under Guideline 2.4.5 for using CGEvent.post](https://developer.apple.com/forums/thread/820594)
- [The Mac App Store won't let window managers exist](https://blakecrosley.com/blog/window-manager-mac-app-store-sandbox)
- [A window switcher on the Mac App Store?](https://alinpanaitiu.com/blog/window-switcher-app-store/)
