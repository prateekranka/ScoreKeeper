# Native navigation and glass acceptance

These suites use TesterArmy e2e only. Build with native Xcode before running them.
Select an already-booted simulator. Do not boot, shut down, erase, or delete a device.
The tests install the selected app bundle without removing its data.
Game flows use the existing in-memory store and debug flags.

## Suites

- `native-glass-tabs.e2e.ts`: the same four destination identifiers in folded native tabs and the open Duo island.
- `native-glass-no-sidebar.e2e.ts`: one bottom-trailing island, full-width content in the default compact rail pose, reachable last controls, four root destinations, folded native navigation, scoring and Game Over actions, game-route preservation, and score-draft preservation across folding.
- `native-glass-gallery.e2e.ts`: onboarding, all root screens, three game formats, handwriting, manual entry, statistics, history, results, and sharing.
- `native-glass-review.e2e.ts`: at-rest row and score clearance, timer presets and Reset, light/dark Home, scoring and Game Over, empty statistics, and the dark main paywall.
- `paywall.e2e.ts`: onboarding, the one-time gift, Pro and trial access, remaining starts, and AX5 benefit/action/legal layout.
- `native-glass-extras.e2e.ts`: scoring utilities, Home utilities, and the Pro offer. It does not purchase or restore a purchase.
- `native-glass-a11y.e2e.ts`: actual system AX5 plus real Reduce Transparency, long and multilingual names, keyboard access, utility actions, exact scores 7 and 9, and undo to zero.

## Run

Use Node 22.12 or later. Install the locked development dependencies in a fresh checkout.
Run each suite with its own output directory and session name.

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1-beta.app/Contents/Developer
export PIPCOUNT_DEVICE=<already-booted-simulator-udid>
export PIPCOUNT_SESSION=<unique-session-name>
export AGENT_DEVICE_STATE_DIR="$PWD/.build/device-state/$PIPCOUNT_SESSION"
mkdir -p -m 700 "$AGENT_DEVICE_STATE_DIR"
export PIPCOUNT_APP=<absolute-built-app-path>
export PIPCOUNT_JOURNEY_MANIFEST="$PWD/.e2e-selected-run/manifest.jsonl"
npx e2e run tests/native-glass-gallery.e2e.ts --output .e2e-selected-run --reporter list,markdown --video off
```

Set `PIPCOUNT_NO_FOLD=1` to run in the current pose when the host cannot stream the hinge angle.
This skips pose changes and folded-only assertions. It does not verify fold transitions.
Keep `actionTimeout` at 20 seconds or more when folds are enabled; e2e 0.21 waits for the pose.

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

For the no-sidebar suite, the default is `PIPCOUNT_DUO_POSE=default`. Arrange the
Duo's default compact open pose before the run. The first case leaves that pose
unchanged and checks a 466-point native content width, a horizontal navigation island, and
hidden native tabs. Inspect the saved PNGs for the vertical status capsule. `PIPCOUNT_DUO_WINDOW_WIDTH` can set a different measured
logical window width. Run the tabs suite with `PIPCOUNT_DUO_POSE=default` to
include the same initial geometry check before its folded/open cases.

Also run `PIPCOUNT_DUO_POSE=inner-portrait` for a 669 by 951 open-panel capture and
`PIPCOUNT_DUO_POSE=inner-landscape` for a 951 by 669 capture. Arrange each pose
before its run. Those screenshot dimensions are separate from logical native
view frames. Both suites fold and reopen only the selected device.
Task A uses only Duo `E00E0899-9FCB-49BE-9D05-E469A89371EA`. Wait if the Mac load
average exceeds about 40 before starting UI suites. Do not change another simulator.

The landscape accessibility suite checks actual 951 by 669 captures. Utility
sheets require both their unique content and Done control to disappear after
dismissal. Score-deck actions and root buttons use current native locators.
The suite checks root buttons' current 44-point targets and the island's
bottom-trailing native frame before tapping. It does not compare scaled PNG
pixels with logical view coordinates. Each tap must
select the requested destination. Scoring utilities open through the island Tools
menu. Utility sheets use their Done button in the same shared island.
The adversarial fixture selector keeps its identifiers but now lives inside More.
It is absent from Home and scoring, so it cannot float over game content.

The Settings setup waits for the exact named Larger Accessibility Sizes switch.
A generic first-switch query can read the previous page during navigation.
Landscape text input uses the visible software keyboard as its input anchor and
requires the exact field value. Return uses its current native frame when visible.
If the driver clips Return, Enter goes through e2e's keyboard route. A reported
native Return error is accepted only after a fresh capture and verified keyboard
dismissal; the test does not repeat that action.

For a focused check, set `PIPCOUNT_A11Y_HOME_ONLY=1`, `PIPCOUNT_A11Y_CONFIG_ONLY=1`,
`PIPCOUNT_A11Y_DECK_ONLY=1`, or `PIPCOUNT_A11Y_NAV_ONLY=1`. `PIPCOUNT_A11Y_APPEARANCE=light` or `dark` narrows
the appearance. These options do not replace the complete acceptance pass.
If a diagnostic changed system settings, `PIPCOUNT_SETTINGS_RESTORE_FROM` accepts
an absolute path to the same device's recorded original settings JSON. The suite
restores and verifies those values before its original-state capture.

For baseline Home utility captures, set `PIPCOUNT_HOME_TOOLS_ONLY=1` and select the baseline app bundle.
For utility captures from an already-open game, set `PIPCOUNT_CAPTURE_EXISTING=1`.
The full gallery saves its own fixture games and needs neither flag.

## Evidence

Keep the original e2e output unchanged. `manifest.jsonl` links each named state to its screenshot.
Copy PNG bytes into the comparison deliverable and record their SHA-256 hashes.
Build success and source checks do not replace runtime assertions or large-text screenshot review.


## Sequential release acceptance

Run the preserved paywall cases, native scoring/rematch journeys, and portrait/landscape paywall checks with SimSlim:

```sh
python3 scripts/run_native_acceptance.py --devices iphone,ipad --output .e2e-release-new
```

The runner creates task-owned devices when no UDID is given, applies the committed SimSlim profile, verifies required services, and runs one device at a time. It stops its private test driver and retained runner before switching devices. It shuts down devices it booted and does not erase or delete any device. It stops if an unrelated simulator is already running.

For an existing dedicated QA device, use --udid with its exact identifier. A new output directory is required so earlier evidence remains intact. The runner keeps the original boot state of an existing device and validates every selected result and cleanup state. Set --app when the built app is outside .build/DerivedData. Add --video to retain the actual UI recording.

The release smoke covers setup, typed round scores, Undo, results, a Pro rematch, and the rematch gate after consuming the last legacy start. Paywall checks include the real unavailable-product state. They do not claim purchase, restore, introductory eligibility, notification delivery or quick-action acceptance when those OS interactions have not been exercised.

This matrix uses the current device pose with PIPCOUNT_NO_FOLD=1. Run the dedicated Duo suites with --allow-fold to prove fold and open-layout behavior; a current-pose pass is not a fold pass. Use --files to select suites and --grep to select a focused regression case.
