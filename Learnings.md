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
- SwiftData route loaders should resolve stored `PersistentIdentifier` values with typed fetches against `persistentModelID`; do not use `ModelContext.model(for:)` as an optional existence check because missing or invalid IDs can trap when a faulted model property is accessed.
- UI test coverage exists in `ScoreKeeperUITests/ScoreKeeperUITests.swift` and uses `-in-memory-store`.
- Simulator preview/control tooling is available through `npm run sim`, which launches ScoreKeeper and serves the simulator at `http://localhost:3200`.
- The shipping bundle identifier is `com.icequeen.scorekeeper`; simulator tooling and App Store Connect records must use that exact value.
- Monetization is 25 free game starts followed by the `$0.99` non-consumable `com.icequeen.scorekeeper.unlimited`. `StoreAccessManager` gates only new sessions and rematches; existing active games remain resumable.
- The StoreKit test configuration lives at `ScoreKeeper/Configuration/ScoreKeeper.storekit`. Production access is determined from verified `Transaction.currentEntitlements` and transaction updates; Restore Purchases calls `AppStore.sync()` only after an explicit tap.
- Review requests become eligible after four successful game completions, are delayed on Game Over, and are attempted at most once per app version.

## App Store Readiness

- Product-screen readiness is tracked in `docs/app-store-readiness.md`; onboarding, the StoreKit paywall, and the post-success review request are implemented.
- App Store copy and privacy-answer drafts live in `docs/app-store-metadata.md`; the publishable policy draft is `docs/privacy-policy.md`.
- `ScoreKeeper/PrivacyInfo.xcprivacy` is present and declares UserDefaults required-reason API usage with reason `CA92.1`.
- Unsigned generic iOS Release archive passed local archive validation. A signed Release archive also succeeds with an Apple Development identity/profile, but App Store export fails because team `4JRB53LG5C` has no local `iOS Distribution` certificate with private key.
- Local keychain did not have an Apple Distribution identity available during the July 7, 2026 readiness pass; App Store upload/distribution needs that account/certificate/profile path resolved.
- July 10 inspection still found no Apple Distribution identity or App Store profile. Do not change the target team (`4JRB53LG5C`) or upload until the correct account/signing assets are provided.
- Full one-shot `xcodebuild test` UI-suite runs can stall at `Testing started` on the iOS 26.4/26.5 simulator runner. Use bounded `-only-testing` slices on the isolated `ScoreKeeper App Store Review 26.4` simulator when this occurs.
- CLI `SKTestSession` configuration sync fails with `SKInternalErrorDomain Code=3` on the installed iOS 26.4/26.5 runtimes (an Apple-reported regression). Run the StoreKit configuration UI test on the installed iOS 27 runtime; it loads the real local product and `$0.99` price successfully.
- On July 7, 2026, all ScoreKeeper UI tests passed via bounded `-only-testing` slices on `ScoreKeeper App Store Review 26.4`; `testPlayerStatsNavigationFromStatsEntry` also passed focused after the test helper cleanup.

## Task And PR Flow

- Convert loose notes, voice notes, or walking thoughts into structured tasks before implementation.
- Name work and PRs as `PR# + human title` once a PR number exists.
- Route every new PR through the Chief of Staff thread for review.
- QA Tester should run only after implementation is PR-ready and should focus on the changed workflow plus likely adjacent breakpoints.
