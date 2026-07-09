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

## Current Worktree Snapshot

- Current branch: `claude/show-claude-md-0Z8wn`.
- Last observed commit: `f162084 Prepare ScoreKeeper redesign and release readiness`.
- Current uncommitted changes include UI-screen-network docs/artifacts, redesign exploration artifacts, and UI-test cleanup. Treat docs/design artifacts as thread outputs unless verified.
- The previous scoring screen WIP is included in commit `f162084`; `ScoringComponents.swift` and `GenericScoringView.swift` are currently clean.

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

- Branch `redesign/ios26-scorecard` carries the full visual redesign (spec: `docs/redesign-spec.md`): ClubhouseTheme paper/ink/felt/lacquer/brass tokens, serif display type, ledger components, plus onboarding rebuild, StoreKit 2 paywall ($0.99 one-time, 10 free games), and the personal review ask.
- `ScoreKeeperUITests/testScreenshotTour` is an env-gated design-QA tour: set `TEST_RUNNER_SCREENSHOT_DIR=<dir>` and run it with `-only-testing` to capture every screen (onboarding, setup, scoring, game over, paywall, review ask) as PNGs.
- Monetization test hooks (honored only with `-in-memory-store`): `-unlock-pro`, `-free-games-exhausted`, `-force-review-ask`.
