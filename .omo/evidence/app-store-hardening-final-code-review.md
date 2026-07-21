# App Store Hardening Final Code Review

Review target: current working tree in `/Users/prateekranka/Cowork/ScoreKeeper` against `HEAD`.

Read-only scope: production/test source was not modified. This report artifact is the only workspace write.

Ignored: unrelated untracked `design-explorations/mascot-hybrid-a-rig/`.

## Skill-Perspective Check

- `remove-ai-slops`: not available in the advertised skill list or local skill roots (`/Users/prateekranka/.codex/skills`, `/Users/prateekranka/.agents/skills`). Applied the prompt-provided criteria manually.
- `programming`: not available in the advertised skill list or local skill roots. Applied the prompt-provided criteria manually.
- Skill perspective result: the diff has test slop/false-confidence issues in review/legal tests and one unused StoreKit fixture, listed below. Production code has a real error-recovery gap around failed SwiftData saves.

## Evidence Inspected

- `git status --short --branch`
- `git diff --stat HEAD`
- `git diff --check HEAD` passed with no whitespace errors.
- Fresh unit test run: `xcodebuild test -project ScoreKeeper.xcodeproj -scheme ScoreKeeper -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:ScoreKeeperTests -resultBundlePath /tmp/scorekeeper-code-review-unit-20260715.xcresult`
- Fresh unit test result: `/tmp/scorekeeper-code-review-unit-20260715.xcresult`, `18` passed, `0` failed.
- Legal URL checks:
  - `GET https://support.contenthelper.in` returned HTTP 200.
  - `GET https://support.contenthelper.in/privacy` returned HTTP 200.
  - Initial `HEAD` checks timed out, but app `Link` navigation performs browser GETs, and GET reachability was verified.
- Prior success claims in the task did not include artifact paths, so they were not treated as proof.

## CRITICAL / P0

None.

## HIGH / P1

### P1: In-app PipCount legal links open public pages that still brand the product as ScoreKeeper

The app now labels the root legal entry and link accessibility labels as PipCount in `ScoreKeeper/Views/Settings/LegalSupportView.swift:3-49`, and the local draft policy is now PipCount-branded in `docs/privacy-policy.md:1-23`. However, the configured live URLs still serve customer-visible pages titled and branded as ScoreKeeper. The verified `GET https://support.contenthelper.in/privacy` response includes `Privacy Policy · ScoreKeeper · Content Helper` and policy text such as `ScoreKeeper stores...`; the verified support page likewise brands itself as `ScoreKeeper · Content Helper`. `docs/app-store-readiness.md:17-24` also says the public policy still needs publishing and that no external policy page is claimed updated.

This violates the requirement that customer-visible PipCount branding be consistent and leaves a privacy/support copy mismatch on the exact links the app exposes to customers and App Review.

References:
- `ScoreKeeper/Views/Settings/LegalSupportView.swift:3`
- `ScoreKeeper/Views/Settings/LegalSupportView.swift:24`
- `ScoreKeeper/Views/Settings/LegalSupportView.swift:39`
- `docs/privacy-policy.md:1`
- `docs/app-store-readiness.md:17`
- `docs/app-store-readiness.md:24`

Required before approval: publish PipCount-branded privacy/support pages at the linked URLs or change the app/App Store URLs to already-published PipCount-branded pages, then verify the live content.

### P1: Failed SwiftData saves leave staged mutations/deletions in the live context

Several new error-handling paths stage destructive or user-visible model mutations before `try modelContext.save()`, but the `catch` blocks only set an alert string. They do not call `modelContext.rollback()`, refetch, reinsert, or otherwise restore the pre-failure state. If a save fails, the live context can still contain the pending deletion, inserted game, appended round, or completed-game mutation, so a later successful save can persist an operation that the UI told the user failed.

Concrete examples:
- Active game deletion: deletes the session before save; catch only sets `saveError` in `ScoreKeeper/Views/Home/HomeView.swift:158-170`.
- Saved roster deletion: removes selection and deletes the player before save; catch only sets `saveError` in `ScoreKeeper/Views/Setup/PlayerRosterSheet.swift:120-134`.
- Game creation: inserts a session/players and mutates saved roster before save; catch returns nil without rolling back in `ScoreKeeper/Views/Setup/GameConfigView.swift:168-188` and `ScoreKeeper/Views/Setup/PlayerSetupView.swift:152-170`.
- Round/game completion: appends a round or marks completion before save; catch only sets `saveError` in `ScoreKeeper/Views/Scoring/GenericScoringView.swift:55-96`.

This does not satisfy the requested deletion/error-recovery hardening and creates data-loss/inconsistent-allowance risk in exactly the save-failure cases the diff now surfaces to users.

Required before approval: add rollback/restoration behavior for failed destructive and creation/completion saves, and add focused regression coverage where practical.

## MEDIUM / P2

### P2: Review-request UI tests provide false confidence that native requestReview is invoked

The new/updated UI tests assert the old custom review controls are absent after game completion, but they do not verify that `ContentView` actually consumes `reviewRequestPending` and invokes the native `requestReview` environment action. This is a remove-ai-slops issue: the tests primarily verify requested removal/absence and their names imply native behavior that they cannot observe.

References:
- `ScoreKeeperUITests/LegalSupportAndReviewUITests.swift:46-72`
- `ScoreKeeperUITests/ScoreKeeperUITests.swift:339-348`
- `ScoreKeeper/App/ContentView.swift:90-94`

Recommended fix: keep one negative UI assertion if useful, but add a small unit/view-level seam or manager test that proves the pending review signal is consumed and the request action path is called.

### P2: Customer-facing Ten Phases settings copy still uses phase wording

Most protected `Phase 10` references were replaced with Ten Phases/stage wording, but the settings explanation still says `Players advance to the next phase...` in customer-facing UI. The requirement asked for protected-game references to be replaced with Ten Phases/generic ten-stage wording, and this screen otherwise uses Ten Phases/stage language.

Reference:
- `ScoreKeeper/Views/Setup/GameConfigView.swift:99-106`

Recommended fix: change this remaining visible copy to stage/ten-stage wording.

## LOW / P3

### P3: New UI test class emits Xcode 27 main-actor isolation warnings

The fresh unit-test command built the UI test target and emitted many warnings from `LegalSupportAndReviewUITests`: the class is `@MainActor`, but `setUpWithError`, `tearDownWithError`, and XCTest autoclosures are still treated as nonisolated contexts by the compiler. Tests currently pass/build, but this is warning debt in newly added test code.

References:
- `ScoreKeeperUITests/LegalSupportAndReviewUITests.swift:3-17`
- `ScoreKeeperUITests/LegalSupportAndReviewUITests.swift:20-22`

Recommended fix: align the XCTest lifecycle methods and assertions with the project’s established UI-test concurrency pattern, or remove the class-level actor annotation if not needed.

### P3: `StoreKitUnavailable.storekit` is added but not actually used by tests

The empty StoreKit fixture is added to the test target resources, but the unavailable/retry test uses `StubStoreProductLoader` instead. The test comment references the fixture, yet no code loads it. This is minor test fixture slop and can confuse future StoreKit coverage.

References:
- `ScoreKeeperTests/StoreManagerStoreKitTests.swift:42-48`
- `ScoreKeeper.xcodeproj/project.pbxproj:376-379`
- `ScoreKeeper.xcodeproj/project.pbxproj:549-553`

Recommended fix: either use the fixture in a real StoreKitTest path or remove it and update the comment.

## Positive Verification

- Bundle identifier remains `com.icequeen.scorekeeper`; IAP product identifier remains `com.icequeen.scorekeeper.unlimited`.
- App display name/build setting is now PipCount.
- Target-score engine behavior is covered by fresh unit tests, including highest/lowest winner selection and ties.
- StoreKit empty-product/unavailable paths no longer expose a hardcoded `$0.99` fallback in the tested manager surface.
- `ReviewAskView.swift` is deleted and production wiring calls `requestReview()` directly from `ContentView`.
- Active games are listed rather than only showing the first in-progress session.

## Status

codeQualityStatus: BLOCK

recommendation: REQUEST_CHANGES

blockers:
- Publish or link to live PipCount-branded privacy/support pages; current linked public pages still say ScoreKeeper.
- Add rollback/restoration for failed SwiftData saves in destructive and creation/completion paths.

