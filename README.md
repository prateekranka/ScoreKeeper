# PipCount

PipCount is a native iPhone and iPad app for keeping score at game night. It supports 2–15 players, saved rosters, game history, player statistics, and shareable scorecards.

The app uses SwiftUI and SwiftData. Its Xcode project, scheme, and app bundle retain the name `ScoreKeeper`.

## Current handwriting prototype

The current score-entry web prototype is in [previews/handwriting](previews/handwriting/README.md). It includes the Bauhaus dialog, local digits-6 recognition, prompted sample collection and optional Jev evaluation. Start with [the review guide](previews/handwriting/REVIEW_GUIDE.md) when reviewing that version. It runs separately from the native app described below.

## Game formats

| Format | Scoring |
| --- | --- |
| Scoreboard | Track any game with round scores and a highest- or lowest-score winner. Enter scores from 0 to 99 by handwriting or keyboard. |
| What's for Dinner | Track meal reveals and hand values, with the lowest score winning. |
| Ten Phases | Track phase progress and leftover points in a ten-stage card game. |

Players can resume active games, undo the last round, review results, compare players, and start a rematch. Timer, dice, starter selection, and round-log tools support play.

Scoreboard handwriting uses Apple Vision on the device. Players confirm each suggested score before saving it. Typed entry remains available.

The app includes 25 free game starts and an optional one-time Unlimited Games purchase through StoreKit.

## Navigation and accessibility

Home, Games, Players, and More use native tabs at every window width, including iPad and the open iPhone Duo. Each tab keeps its own navigation stack. Folding preserves the active game route and score-entry draft.

The interface combines paper-style content with native glass controls. Text scales with Dynamic Type. Controls use solid backgrounds when Reduce Transparency is enabled, and motion responds to Reduce Motion.

The accessibility acceptance pass uses the largest system Dynamic Type size together with Reduce Transparency. It checks light and dark appearances, long and multilingual player names, keyboard access, scoring, and undo.

## Requirements

- macOS with Xcode and an iOS 26 or later SDK.
- An iOS 26 or later simulator runtime, or a compatible iPhone or iPad.
- Node.js 22.12 or later and npm for the development preview and TesterArmy tools.

The app targets iOS 26.0 and uses Swift 6. The current Duo and system-accessibility suites target Xcode 27.1 beta. The accessibility helper currently selects `/Applications/Xcode-27.1-beta.app/Contents/Developer` for system text-size queries.

## Build and run

Run commands from the repository root. If several Xcode installations are available, set `DEVELOPER_DIR` to the required installation.

For development, open `ScoreKeeper.xcodeproj`, select the `ScoreKeeper` scheme, and run on your selected device. For a physical device, configure your signing team in Xcode.

To build an unsigned simulator app:

```sh
xcodebuild -project ScoreKeeper.xcodeproj -scheme ScoreKeeper \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The resulting app is `.build/DerivedData/Build/Products/Debug-iphonesimulator/ScoreKeeper.app`. Its bundle identifier is `com.icequeen.scorekeeper`.

Install the locked development tools before running preview or acceptance commands:

```sh
npm ci
```

## App acceptance

Use TesterArmy e2e for app behavior, UI, and complete user flows. See [the testing guide](tests/README.md) for suite coverage, device setup, fold poses, and evidence handling.

Select an already-booted simulator and the exact app bundle from your build. Use one session per device and a separate output directory for each run. The suites install the selected bundle and use an in-memory game store.

Start with the native-tab check on a compact phone:

```sh
export PIPCOUNT_DEVICE="<already-booted-simulator-udid>"
export PIPCOUNT_APP="$PWD/.build/DerivedData/Build/Products/Debug-iphonesimulator/ScoreKeeper.app"
export PIPCOUNT_SESSION="pipcount-tabs-$(date +%s)"
export PIPCOUNT_JOURNEY_MANIFEST="$PWD/.e2e-$PIPCOUNT_SESSION/manifest.jsonl"
npx e2e run tests/native-glass-tabs.e2e.ts \
  --output ".e2e-$PIPCOUNT_SESSION" --reporter list,markdown --video=off
```

For the combined accessibility pass on the same compact phone:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1-beta.app/Contents/Developer
export PIPCOUNT_SESSION="pipcount-a11y-$(date +%s)"
export PIPCOUNT_JOURNEY_MANIFEST="$PWD/.e2e-$PIPCOUNT_SESSION/manifest.jsonl"
export PIPCOUNT_SETTINGS_RECORD="$PWD/.e2e-$PIPCOUNT_SESSION/original-settings.json"
PIPCOUNT_PHONE=1 PIPCOUNT_A11Y_POSE=compact \
  npx e2e run tests/native-glass-a11y.e2e.ts \
  --output ".e2e-$PIPCOUNT_SESSION" --reporter list,markdown --video=off
```

This suite changes the real system settings, records their original values, and restores them after the pass. It runs both light and dark cases. Review the captures for readable controls, unclipped names, reachable actions, and usable scoring with the keyboard open.

Use separate Duo runs for `inner-portrait` and `inner-landscape`, following the testing guide. The gallery, utilities, folding, and adversarial suites cover additional flows. A successful build alone does not confirm UI acceptance.

## Optional browser preview

After launching PipCount on your selected simulator, start its browser preview:

```sh
npm run sim:serve -- "<booted-simulator-udid>"
```

The preview is available at `http://localhost:3200`. Use TesterArmy for acceptance checks.

## Data and privacy

Game data and saved rosters use local SwiftData storage. Preferences use UserDefaults. The free-game allowance uses a device-only Keychain item and survives reinstall on the same device.

Handwriting recognition and scorecard creation run on the device. Sharing uses the system share sheet. See [the privacy policy](docs/privacy-policy.md) for storage, sharing, purchases, and deletion details.

## Repository guide

| Location | Purpose |
| --- | --- |
| `ScoreKeeper/App/` | App startup, native tabs, navigation, and debug fixtures. |
| `ScoreKeeper/Models/` | SwiftData models and game configuration. |
| `ScoreKeeper/Engines/` | Rules for the three game formats. |
| `ScoreKeeper/Views/` | Setup, scoring, results, statistics, and settings screens. |
| `ScoreKeeper/Theme/` | Colors, typography, spacing, and motion. |
| `ScoreKeeper/Services/` | Recognition, purchases, allowance storage, statistics, and review requests. |
| [tests/](tests/README.md) | TesterArmy suites and run instructions. |
| [Tools/ScoreDigitModel/](Tools/ScoreDigitModel/README.md) | Offline handwriting-model tooling. The custom model requires a validated corpus before production use. |
| [release/app-store-screenshots/](release/app-store-screenshots/README.md) | Editable App Store screenshot project. |
| `.github/workflows/` | Native build and validation workflows for pushes and pull requests to `main`. |
