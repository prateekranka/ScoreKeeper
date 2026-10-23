# Task A: Twin Islands and readability

Source changes are ready for review. Runtime acceptance is incomplete.

## Navigation

`ContentView` keeps one TabView and four NavigationStacks. A regular horizontal
size class or an asymmetric trailing safe-area inset of at least 60 points with
a leading inset of at most 1 point enables the shared island. This includes the
Duo's default compact open window. Compact windows with normal safe areas retain
the native tab bar. The app does not replace the
TabView when the window changes size.

The root island has Home, Games, Players, and More. It uses `tab_home`, `tab_games`,
`tab_players`, and `legal_support_button`. Filled symbols, an opaque selected
background, and the selected accessibility trait mark the active destination.
Buttons have targets of at least 56 points. Symbols use Dynamic Type. The shared
`PipCountIsland` uses `GlassEffectContainer` and the existing native `glassEffect`
wrapper. Reduce Transparency selects the existing solid paper fallback. The
capsule stacks vertically in the detected rail and horizontally in regular
windows without that rail. Its intrinsic size is anchored bottom-trailing. It
overlays content; measured tail padding inside each scroll view allows the last
item to clear it. The viewport keeps its full height, and paper extends under the
bottom safe area. No new animation is added.

Content ignores the trailing safe area. Each header pads its trailing edge by
the detected rail inset and reserves twice that inset in height for the system
camera, clock, and Wi-Fi. Content below the header can use the full window width.
This height is a layout estimate from the reviewer's observed status zone; the
SDK does not expose the individual system rail items' frames.

Scoring replaces the root buttons with back, score round, undo, round log, and
Tools. The Tools menu contains timer, dice, starter, and end game. Game Over uses
home, play again, and share. Game details use back and share. Setup uses back and continue/start. The score deck
moves Cancel into the island. Utility sheets put Done in the same component.

## SDK findings

The implementation uses public
[`toolbarVisibility(.hidden, for: .tabBar)`](https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:)).
It hides the app's native tab bar when the island is active. It also hides the native
navigation bar there, so titles remain in scrolling content and app controls do
not occupy the camera corner.

The examined SDK is `/Applications/Xcode-27.1-beta.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk`.

- `SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64-apple-ios-simulator.swiftinterface:12363` declares `toolbarVisibility`.
- The same file at line 6818 declares `EnvironmentValues.tabBarPlacement` with a getter only. Its placement values describe system placement; they do not set a rail location.
- The same file at line 12560 marks `OrnamentAttachmentAnchor` unavailable on iOS. The related `ornament` view methods are also unavailable on iOS.
- `UIKit.framework/Headers/UITabBarController.h:137` exposes `isTabBarHidden`; line 142 describes the content area unobscured by the native tab bar/sidebar.
- `UIKit.framework/Headers/UIWindowSceneGeometryPreferencesIOS.h:24` exposes orientation preferences. It does not expose a camera or status-rail placement preference.

No public API to collapse or reposition the camera/status rail was found in the
searched SwiftUI and UIKit interfaces. The implementation leaves system status
visibility alone. The reviewer confirmed that hiding native tabs removes the
app's controls from the rail while the transparent system rail remains. A1 uses
`GeometryProxy.safeAreaInsets` for detection and
`ignoresSafeArea(.container, edges: .trailing)` for full-width content. The header
reservation protects the upper status zone; the island occupies the lower rail.
The updated placement and content width still require runtime review.

## A1 reviewer follow-up

The reviewer built the preceding snapshot after correcting `pipCountIsland` to
pass `actions: actions`. That correction is retained. Their default open-pose
measurement was width 382, trailing inset 84, leading inset 0, bottom inset 34,
and compact size class: a 466-point window. Their forced-island screenshot
showed the old centered capsule covering Resume and a white bottom strip.

A1 removes the 550-point trigger, replaces the bottom safe-area bar with the
trailing overlay, and moves the debug fixture selector into More. Its existing
identifiers and fixture actions remain. Native frame assertions now cover the
default pose, full-width roots, trailing placement, reachable last controls,
scoring, and Game Over. PNG size checks remain separate from native coordinates.
The short handoff is `.build/evidence-A/A1.md`.

## Readability

Content and label tokens use body size or larger, with medium or heavier labels.
The legacy `AppFonts.caption` name remains as a body-size alias for Task B's
unchanged Paywall source. Body text no longer uses a shrink-to-fit factor.
Primary buttons select a contrasting foreground for ink and yellow fills.
Red, green, blue, brass, and muted text tokens have stronger contrast in both
appearances. Disabled manual entry no longer fades its text. The active-game
Delete target now has a minimum width of 44 points.

`ScoreKeeperTests/ThemeContrastTests.swift` uses Swift Testing. It resolves actual
SwiftUI colors through light and dark UIKit traits. It checks paper, card, sunken,
elevated, sky, player-tinted surfaces, primary fills, selected fills, and destructive
fills against a 4.5:1 threshold. Game tile text uses ink on card. Player badge names
use ink; decorative player shapes are excluded from the accessibility tree.

## Checks and remaining gates

- Swift parsing passed for all 58 app files and the new contrast test.
- Node's TypeScript syntax check passed for every file in `tests/`.
- The Xcode project file passed `plutil -lint`.
- A source-based WCAG calculation passed for 458 distinct light/dark color pairs.
  Its minimum ratio is 4.73:1. This does not replace the Swift Testing run.
- Generic simulator build was attempted with `.build/DerivedData`. Xcode could
  not launch macro implementations inside the enclosing sandbox:
  `sandbox-exec: sandbox_apply: Operation not permitted`.
- A separate `build-for-testing -only-testing:ScoreKeeperTests` attempt met the
  same macro blocker. Those original sandbox attempts did not produce a build.
- The reviewer subsequently reported a successful build after the closure fix.
  That result precedes A1 and does not establish that A1 builds.
- The read-only Duo preflight failed because the sandbox could not connect to
  CoreSimulatorService. No simulator was booted, erased, shut down, or changed.
- A1 has source syntax checks only. No A1 build, unit-test, e2e, or AX5 runtime
  pass is claimed. The reviewer will run those checks outside this sandbox.
- Build logs and the source color calculation are under `.build/evidence-A/`.

Run the unit target on Duo `E00E0899-9FCB-49BE-9D05-E469A89371EA` outside this
sandbox. Use `DEVELOPER_DIR=/Applications/Xcode-27.1-beta.app/Contents/Developer`
and worktree-local `.build/DerivedData`. Then run the existing e2e suites with a
private `AGENT_DEVICE_STATE_DIR`, `--video off`, and the same Duo only. Run the two
open poses separately. Wait if the Mac load average is above about 40. Capture
open Home, Games, Players, More, scoring, Game Over, folded Home, and AX5 dark Home.

## Removed visible strings

Dynamic values below use braces for the original data interpolation. Titles,
button labels, errors, legal text, accessibility meaning, and real scores remain.
Some strings remain in source for accessibility or another screen; this list
records where their visible use was removed.

### Home

- `every night\nbecomes history`
- `track any game. add your crew. see the story build over time`
- `game night, organized`
- `round {number} is waiting`
- `{count} active games are waiting`
- `ready to play?`
- `{count} completed game` / `{count} completed games` from the header kicker
- `start something new or bring your regular crew back to the table`

### Home utility sheets

- `keep turns moving`
- `roll a quick number`
- `choose who starts`
- `fix mistakes safely`
- `a visible timer reduces table drift without leaving the score sheet`
- `use a fast 1–6 roll when a game needs a tie-breaker or random choice`
- `start or resume a game to pick from its player list`
- `randomly pick from the current players`
- `scorekeeping mistakes happen. the live sheet keeps undo close to the submit button`
- `use the live scoring toolbar timer during a game`
- `during scoring, tap undo last before submitting the next round`

Timer and undo sheets now offer the existing start/resume action instead of a
paragraph. Their accessibility hints explain the available scoring tool.

### Games

- `track any game`
- `lowest hand wins`
- `ten-stage card-game scoring`

The full game descriptions remain in the tiles' accessibility labels.

### Players and roster

- `players are saved automatically after you start your first game`
- `play a game to save player names to your roster`

### Player setup

- `build tonight's lineup`
- `tap names to fill the table faster`

### Game settings

- `set this once. pipcount handles the rest`
- `players advance to the next stage every round, even when they do not complete the current stage`
- `ready to score`
- `calibrate the rules for tonight`
- `the first player to reach {targetScore} after a submitted round ends the game; highest total wins`
- `when any player reaches {targetScore} after a submitted round, the game ends; lowest total wins`
- `leave blank for manual-only completion`

The toggle and target field retain their accessibility explanations.

### Scoring and round log

- `pipcount` from the large scoring header
- `add this round with handwriting`
- `saved rounds appear here after you enter the scores`

### Ten Phases

- `write this round's leftover points with the score deck`

### What's for Dinner

- `choose the player who called it, then write every hand with the score deck`
- `tap to pick`
- `caller` (selection uses a checkmark and the selected accessibility trait)

### Handwriting and manual entry

- `write it. check it. keep playing`
- `use your finger or apple pencil. pipcount reads the score, then asks you to confirm it before moving on`
- `redraw or type the score`
- `then tap use to confirm`
- `draw each player's score, tap ✓ to read it, then confirm. swipe from either edge to move between players. confirm the last card last — that submits the round, so confirm it again if you jump back`

### Game Over

- `final` from the repeated stamp

- `the scores are saved. the rematch is one tap away`
- `tonight belongs to {winner}`
- `a perfectly unresolved game night`
- `a quick memory of how the table finished`
- `highest score wins` / `lowest score wins` from the standings subtitle
- `most stages wins. ties go to the fewest points` from the standings subtitle
- `played`
- `at the table`
- `game time`

Tied player names remain visible.

### Game details

- `final` from the eyebrow stamp

- `highest score wins` / `lowest score wins` from the standings subtitle
- `most stages wins. ties go to the fewest points` from the standings subtitle
- `every submitted score, in order`
- `played`
- `at the table`
- `game time`

### Shared scorecard

- `highest score wins` / `lowest score wins` from the standings subtitle
- `most stages wins. ties go to the fewest points` from the standings subtitle

### History

- `every night\nbecomes history` (title changed to `game history`)
- `final scores, rematches, and the story of your table — saved automatically`
- `complete a game and its recap will appear here`

### Player statistics

- `every result, remembered`
- `finish a game with {playerName} and their history will appear here`
- `played`
- `finished first`
- `all games`
- `score` from the repeated metric detail

### Head to head

- `see how two regulars have finished against each other`
- `pipcount compares completed games shared by both players`
- `{playerA} and {playerB} do not have a completed matchup yet`
- `their shared record will appear here, separated by game type`

### More

- `how pipcount handles your information`
- `get help or contact the pipcount team`

Privacy and support accessibility hints remain. Paywall source and purchase,
entitlement, and free-game counting logic are unchanged.

### Onboarding

- `pipcount replaces the notes app, napkin, and 'who's winning?'`
- `pick a game, add your crew once, reuse them every night`
- `final scores, stats, and rematches — saved automatically`
- `game night archive`
