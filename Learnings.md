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
- The free-game count is mirrored to a device-only Keychain item as well as UserDefaults, so reinstalling does not restart the allowance. Game/session data remains local SwiftData and is removed with the app.
- The StoreKit test configuration lives at `ScoreKeeper/Configuration/ScoreKeeper.storekit`. Production access is determined from verified `Transaction.currentEntitlements` and transaction updates; Restore Purchases calls `AppStore.sync()` only after an explicit tap.
- Review requests become eligible after four successful game completions, are delayed on Game Over, and are attempted at most once per app version.
- Paywall continuation belongs to the active presentation intent and runs from the sheet's `onDismiss` after an explicit unlock outcome. Parent screens must not observe entitlement changes loosely or launch uncancelled delayed navigation tasks, because either can navigate after the initiating screen has disappeared.

## App Store Readiness

- Product-screen readiness is tracked in `docs/app-store-readiness.md`; onboarding, the StoreKit paywall, and the post-success review request are implemented.
- App Store copy and privacy-answer drafts live in `docs/app-store-metadata.md`; the publishable policy draft is `docs/privacy-policy.md`.
- App Store Connect Business compliance is complete; the Digital Services Act status is set to non-trader (July 12, 2026) and shows Active.
- Public support and privacy pages are deployed through Sites from the sibling `contenthelper-site` project. The active App Store URLs are `https://support.contenthelper.in` and `https://privacy.contenthelper.in`; DNS is managed in Cloudflare and both custom domains are active with SSL. Cloudflare Email Routing now delivers `support@contenthelper.in` to `prateek.ranka@gmail.com`; Gmail archives matching messages and applies the `scorekeeper apple support` label via a filter. A live test message on July 12, 2026 confirmed delivery and labeling.
- `ScoreKeeper/PrivacyInfo.xcprivacy` is present and declares UserDefaults required-reason API usage with reason `CA92.1`.
- Apple Distribution signing is configured for team `4JRB53LG5C` in the login keychain with certificate SHA-1 `7A3BD74D6E377B4512D66FCBF8C3701F3B4CF297`. The replacement App Store profile is `ScoreKeeper App Store Build 3` (UUID `eb3fe00e-7620-4212-af50-50f49cb1c62f`, expires July 12, 2027). The old dedicated `ScoreKeeper-signing.keychain-db` remains locked and should not be used; no raw private-key export is retained.
- A Release archive and App Store export were verified on July 12, 2026 with the replacement certificate/profile. The verified IPA is `build/ScoreKeeper-newcert-export/ScoreKeeper.ipa` (local build artifact, not committed).
- ScoreKeeper version `1.0` build `2` was uploaded through the App Store Connect Build Uploads API on July 10, 2026. Build upload/resource ID `4ac7ae41-0ba4-44d9-8bfd-ee6a969e0ff5` reached `COMPLETE` / `VALID` with no warnings or errors.
- Full one-shot `xcodebuild test` UI-suite runs can stall at `Testing started` on the iOS 26.4/26.5 simulator runner. Use bounded `-only-testing` slices on the isolated `ScoreKeeper App Store Review 26.4` simulator when this occurs.
- CLI `SKTestSession` configuration sync fails with `SKInternalErrorDomain Code=3` on the installed iOS 26.4/26.5 runtimes (an Apple-reported regression). Run the StoreKit configuration UI test on the installed iOS 27 runtime; it loads the real local product and `$0.99` price successfully.
- StoreKit's local test environment is shared and can retain a non-consumable entitlement across tests. Real purchase tests clear transactions; synthetic locked/pending UI tests use an explicit DEBUG locked-entitlement argument so they stay deterministic on runtimes where `SKTestSession` cannot initialize.
- The July 10, 2026 release pass refreshed all visibly changed route screenshots and regenerated `docs/ui-screen-network-route-strips.png`. Simulator attachment `21-game-details.png` has top-corner masking artifacts and should not be selected as an App Store marketing image.
- App Store Connect uses the public app name `PipCount` for bundle `com.icequeen.scorekeeper` (ScoreKeeper remains the internal product/UI name). On July 12, 2026, release metadata, privacy declaration, 4+ age rating, ten 6.5-inch screenshots, App Review contact details, and the non-consumable `com.icequeen.scorekeeper.unlimited` at $0.99 were entered in version 1.0; build 3 still needs to be uploaded and the Paid Apps Agreement/DSA classification is pending owner input.
- On July 7, 2026, all ScoreKeeper UI tests passed via bounded `-only-testing` slices on `ScoreKeeper App Store Review 26.4`; `testPlayerStatsNavigationFromStatsEntry` also passed focused after the test helper cleanup.

## Task And PR Flow

- Convert loose notes, voice notes, or walking thoughts into structured tasks before implementation.
- Name work and PRs as `PR# + human title` once a PR number exists.
- Route every new PR through the Chief of Staff thread for review.
- QA Tester should run only after implementation is PR-ready and should focus on the changed workflow plus likely adjacent breakpoints.
