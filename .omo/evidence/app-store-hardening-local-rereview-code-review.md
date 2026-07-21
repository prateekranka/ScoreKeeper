# App Store Hardening Local Re-Review

Review target: current working tree in `/Users/prateekranka/Cowork/ScoreKeeper` against `HEAD`.

Scope: read-only review of production/test/project/doc diffs. No app, test, project, or docs files were edited. This report artifact is the only write.

Ignored: unrelated untracked `design-explorations/mascot-hybrid-a-rig/`.

## Skill-Perspective Check

- `remove-ai-slops`: not available in the advertised skill list or local skill roots (`/Users/prateekranka/.codex/skills`, `/Users/prateekranka/.agents/skills`). Applied the prompt-provided criteria manually.
- `programming`: not available in the advertised skill list or local skill roots. Applied the prompt-provided criteria manually.
- Skill perspective result: prior local test/fixture slop around `StoreKitUnavailable.storekit` is resolved. One local error-recovery defect remains in production code.

## Evidence Inspected

- `git status --short --branch`
- `git diff --stat HEAD`
- `git diff --check HEAD` passed.
- Current diffs for:
  - `ScoreKeeper/Views/Components/ScoringComponents.swift`
  - `ScoreKeeper/Views/Home/HomeView.swift`
  - `ScoreKeeper/Views/Setup/GameConfigView.swift`
  - `ScoreKeeper/Views/Setup/PlayerSetupView.swift`
  - `ScoreKeeper/Views/Setup/PlayerRosterSheet.swift`
  - `ScoreKeeper/Views/Scoring/*`
  - `ScoreKeeper/Views/Summary/GameOverView.swift`
  - `ScoreKeeper.xcodeproj/project.pbxproj`
  - `ScoreKeeperTests/StoreManagerStoreKitTests.swift`
  - `ScoreKeeperUITests/LegalSupportAndReviewUITests.swift`
  - `docs/privacy-policy.md`
- Text search for remaining `Phase 10`/`phase`/`ScoreKeeper Pro` customer strings.
- Text search for `StoreKitUnavailable` fixture references.

## Findings

### HIGH / P1: Undo round deletion still lacks rollback on save failure

`undoLastRound()` deletes the last round from the SwiftData context before saving. If `modelContext.save()` throws, the new error path only sets `saveError`; it does not call `modelContext.rollback()` or restore the deleted round. This leaves the same local data-loss/error-recovery gap as the prior SwiftData blocker: a failed undo can remain staged in the live context and be persisted later even though the UI reports failure.

Reference:
- `ScoreKeeper/Views/Components/ScoringComponents.swift:94-104`

Required local fix:
- Capture the error message, rollback the context after the failed save, then surface the alert, matching the newly fixed create/delete/round/completion/rematch paths.

## Rechecked Prior Local Findings

- SwiftData create/delete/round/completion/rematch paths: mostly fixed with `modelContext.rollback()` after failed saves in the inspected changed files.
- Remaining customer-facing phase copy: fixed to stage wording.
- Unused `StoreKitUnavailable.storekit` fixture/resource: removed; no remaining `StoreKitUnavailable` references.
- Active-list identifier placement: changed; no local blocker found from static review.
- Local privacy draft contact: restored with support/privacy destination text.
- External live support/privacy pages: still a submission blocker outside local repo authority, per handoff; not counted as an unfixed local code defect in this re-review.

## Status

REQUEST_CHANGES_LOCAL

Blocker:
- Add rollback/restoration for failed undo-last-round save in `ScoreKeeper/Views/Components/ScoringComponents.swift:94-104`.

