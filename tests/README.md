# Native navigation and glass acceptance

These suites use TesterArmy e2e only. Build with native Xcode before running them.
Select an already-booted simulator. Do not boot, shut down, erase, or delete a device.
The tests install the selected app bundle without removing its data.
Game flows use the existing in-memory store and debug flags.

## Suites

- `native-glass-tabs.e2e.ts`: four native phone tab identifiers and their destinations.
- `native-glass-gallery.e2e.ts`: onboarding, all root screens, three game formats, handwriting, manual entry, statistics, history, results, and sharing.
- `native-glass-extras.e2e.ts`: scoring utilities, Home utilities, and the Pro offer. It does not purchase or restore a purchase.
- `native-glass-a11y.e2e.ts`: actual system AX5 plus real Reduce Transparency, long and multilingual names, keyboard access, utility actions, exact scores 7 and 9, and undo to zero.

## Run

Use Node 22.12 or later. Install the locked development dependencies in a fresh checkout.
Run each suite with its own output directory and session name.

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1-beta.app/Contents/Developer
export PIPCOUNT_DEVICE=<already-booted-simulator-udid>
export PIPCOUNT_SESSION=<unique-session-name>
export PIPCOUNT_APP=<absolute-built-app-path>
export PIPCOUNT_JOURNEY_MANIFEST="$PWD/.e2e-selected-run/manifest.jsonl"
npx e2e run tests/native-glass-gallery.e2e.ts --output .e2e-selected-run --reporter list,markdown
```

For accessibility, also set `PIPCOUNT_SETTINGS_RECORD` to an absolute JSON output path.
The suite records the original system settings and restores them in `finally`.
It verifies AX5 through the native simulator category and the Settings slider.
Reduce Transparency is changed and verified through the real Settings UI in e2e.
Native `simctl ui content_size` configures the simulator environment. It is not an app launch override.
All app actions and UI assertions remain in TesterArmy e2e.

Use `PIPCOUNT_PHONE=1 PIPCOUNT_A11Y_POSE=compact` for the compact phone's light/dark cases.
Run `PIPCOUNT_A11Y_POSE=inner-portrait` and `PIPCOUNT_A11Y_POSE=inner-landscape` as separate Duo runs.
Arrange each physical pose with Device Hub Rotate Right before its run.
The driver orientation value does not change the inner app viewport on this Xcode beta.
Each case asserts the actual screenshot aspect ratio before testing the app.
The default run checks the two compact cases. All app actions and assertions use e2e.
Never run two sessions on the same device at the same time.

For baseline Home utility captures, set `PIPCOUNT_HOME_TOOLS_ONLY=1` and select the baseline app bundle.
For utility captures from an already-open game, set `PIPCOUNT_CAPTURE_EXISTING=1`.
The full gallery saves its own fixture games and needs neither flag.

## Evidence

Keep the original e2e output unchanged. `manifest.jsonl` links each named state to its screenshot.
Copy PNG bytes into the comparison deliverable and record their SHA-256 hashes.
Build success and source checks do not replace runtime assertions or large-text screenshot review.
