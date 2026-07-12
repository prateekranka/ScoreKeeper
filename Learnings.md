# ScoreKeeper Learnings

Shared memory for the ScoreKeeper Codex team. Keep this concise, factual, and durable.

## Operating Model

- Chief of Staff / Orchestrator owns task intake, thread coordination, quality bars, PR naming, and review pressure.
- QA Tester is used for PR-ready work only. Testing should be targeted, adversarial, and based on real UI interaction, not broad full regressions by default.
- Bugs should get regression tests when the codebase has a fitting test surface.
- If the same error appears twice, stop retrying blindly. Research 3-5 plausible fixes, choose the most efficient one, and implement it.
- Any change to OpenAI API interaction must be escalated with before-and-after behavior and must not ship without explicit user review.

## Project Context

- ScoreKeeper is a native iOS scorekeeping app built with SwiftUI and SwiftData.
- Supported game types currently include Scoreboard, What's for Dinner, and Phase 10.
- Navigation is centralized through `NavigationRouter` and `AppDestination` in `ScoreKeeper/App/ContentView.swift`.
- The UI screen network artifact for redesign prep lives at `docs/ui-screen-network.md`, with a generated route-strip PNG at `docs/ui-screen-network-route-strips.png`.
- Head-to-Head and Player Stats are centralized `AppDestination` routes; Home exposes Game History whenever at least one completed game exists.
- Persistent gameplay state centers on `GameSession`, `Player`, `Round`, and `ScoreEntry` models under `ScoreKeeper/Models`.
- Scoring behavior is split through engines under `ScoreKeeper/Engines`.
- UI test coverage exists in `ScoreKeeperUITests/ScoreKeeperUITests.swift` and uses `-in-memory-store`.
- Simulator preview/control tooling is available through `npm run sim`, which launches ScoreKeeper and serves the simulator at `http://localhost:3200`.
- Project environment: native SwiftUI/SwiftData, scheme `ScoreKeeper`, iOS 26.0+, bundle id `com.icequeen.scorekeeper`, team `4JRB53LG5C` (Debug automatic signing; Release manual App Store profile).

## Current Worktree Snapshot

- Current worktree: `/Users/prateekranka/Cowork/billbandit_fable/ScoreKeeper-redesign` on branch `redesign/ios26-scorecard`.
- Last observed commit: `3123c93 Round E: pixel-font pass — layout fixes, score-sheet tile icons, scoring escape hatch`.
- The July 12 premium-polish pass is uncommitted until explicitly reviewed: selective pixel typography, native SF task typography, refined light/dark palette, 10/14/18 radii, restrained elevation, compact Home metrics, adaptive game-picker features, and polished paywall/review surfaces.

## App Store Readiness

- Product-screen readiness is tracked in `docs/app-store-readiness.md`; required in-app release screens are onboarding, paywall, and review ask.
- Onboarding is redesigned and marked done for App Store readiness; remaining release screens are paywall and review ask.
- `ScoreKeeper/PrivacyInfo.xcprivacy` is present and declares UserDefaults required-reason API usage with reason `CA92.1`.
- Unsigned generic iOS Release archive passed local archive validation. Signed Release archive succeeds locally only with an Apple Development identity/profile.
- Local keychain did not have an Apple Distribution identity available during the July 7, 2026 readiness pass; App Store upload/distribution needs that account/certificate/profile path resolved.
- Full one-shot `xcodebuild test` UI-suite runs can stall at `Testing started` on the iOS 26.4/26.5 simulator runner. Use bounded `-only-testing` slices on the isolated `ScoreKeeper App Store Review 26.4` simulator when this occurs.
- On July 7, 2026, all ScoreKeeper UI tests passed via bounded `-only-testing` slices on `ScoreKeeper App Store Review 26.4`; `testPlayerStatsNavigationFromStatsEntry` also passed focused after the test helper cleanup.

## Task And PR Flow

- Convert loose notes, voice notes, or walking thoughts into structured tasks before implementation.
- Name work and PRs as `PR# + human title` once a PR number exists.
- Route every new PR through the Chief of Staff thread for review.
- QA Tester should run only after implementation is PR-ready and should focus on the changed workflow plus likely adjacent breakpoints.

## Clubhouse Scorecard Redesign (July 2026)

- Branch `redesign/ios26-scorecard` carries the full visual redesign (spec: `docs/redesign-spec.md`): ClubhouseTheme paper/ink/felt/lacquer/brass tokens, selective Press Start 2P/VT323 accents with SF task typography, ledger components, onboarding, StoreKit 2 paywall ($0.99 one-time after 25 free games), and the personal review ask.
- `ScoreKeeperUITests/testScreenshotTour` is an env-gated design-QA tour: set `SCREENSHOT_DIR=<dir>` in the test-run environment (or the generated `.xctestrun` `TestingEnvironmentVariables`) and run it with `-only-testing` to capture every screen (onboarding, setup, scoring, game over, paywall, review ask) as PNGs.
- Monetization test hooks (honored only with `-in-memory-store`): `-unlock-pro`, `-free-games-exhausted`, `-force-review-ask`.
- Premium-polish verification captures live under `screenshots/premium-polish/`; the July 12 tour passed on `ScoreKeeper App Store Review` (iOS 26.5).
- Motion uses the shared `AppMotion` tokens in `AppTheme.swift`: 100/140ms press feedback, 160ms fades, 180ms state changes, 240ms page changes, and a critically damped spring only for rare entrance emphasis. Frequent navigation and page loads arrive immediately.
- Every custom motion path must honor Reduce Motion. Keep scale entrances at 0.96 or above, avoid decorative bounce, and reserve long-running animation for the game-over confetti celebration.
- The official Emil Kowalski `apple-design`, `emil-design-eng`, `improve-animations`, and `review-animations` skills are installed in `~/.codex/skills`; restart Codex before relying on automatic discovery in a fresh session.
- Motion-polish verification captures live under `screenshots/motion-polish/`; the 14-screen July 12 tour and focused onboarding, score-stepper, paywall, and review-ask flows pass on iOS 26.5.
- Paywall and review-ask release sheets now share the product's scorecard vocabulary: compact native section headers, ledger-style rows, 18pt surfaces, and gameplay-style bottom actions. Light-mode proof lives under `screenshots/sheet-alignment/`.
- Do not attach an `accessibilityIdentifier` to the root of a SwiftUI sheet: on iOS 26 it can propagate over descendant identifiers. Identify the meaningful title and controls individually instead.
- `scripts/serve-sim.mjs` must launch `com.icequeen.scorekeeper`; the older `com.prateekranka.scorekeeper` value was stale.

## App Store Submission Prep (July 12, 2026)

- The existing ASC product is `com.icequeen.scorekeeper.unlimited`; redesign `StoreManager` and `ScoreKeeper.storekit` now use that identifier (the UI may still call the product “ScoreKeeper Pro”).
- Version `1.0` is prepared as build `3` because the sibling release already has build `2` in ASC. The target and project signing team are `4JRB53LG5C`.
- `.asc/metadata` contains English app-info/version drafts and passes `asc metadata validate`. URLs, copyright, review contact, categories, age rating, privacy answers, and pricing still require account-owner input.
- `docs/privacy-policy.md` reflects the redesign implementation: SwiftData/UserDefaults on-device storage, StoreKit purchases, and no analytics, tracking, ads, server, or Keychain claim.
- `screenshots/app-store-raw/` contains a 14-screen iPhone 17 Pro Max tour; `screenshots/app-store-69/` is the curated 10-screen upload set. Both use 1320×2868 PNGs and pass `asc screenshots validate --device-type IPHONE_69`.
- Distribution archive compilation reaches the Apple Distribution identity `CAE26F5B5BED4BC39DFA4BCAD84727C7ED68795F` and profile `ScoreKeeper App Store Build 2`, but the dedicated `ScoreKeeper-signing.keychain-db` is locked in this environment. Unlock it before running the manual archive/export again.
- `asc auth status`/`asc auth doctor` show no App Store Connect API credentials. Upload and metadata apply require `ASC_KEY_ID`, `ASC_ISSUER_ID`, and a private `.p8` path, plus public support/privacy URLs.
- The sibling `ColorFlow` GitHub repository (`prateekranka/Coloringbook`) has Actions secrets named `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8_BASE64`; GitHub does not expose secret values locally, and no public support/privacy URLs were found there.
