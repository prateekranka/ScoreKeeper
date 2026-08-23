# PipCount release edge-case matrix

Date: 2026-08-23  
Policy: `lean-contract-tests` — cover every meaningful contract branch at the cheapest deterministic layer. Do not duplicate the same proof across unit, integration, and UI tests.

Legend:

- **Covered**: an existing test proves the contract.
- **Partial**: the route is exercised, but the durable result is not proved.
- **Gap**: no useful proof.
- **Manual**: the system or visual behavior is not reliable in automation.

Verification checkpoint (2026-08-23): 35 unit tests, 23 main UI tests, 3 legal/review UI tests, standard and extended tours, Reduce Motion, accessibility-extra-large Dynamic Type, and dark-mode evidence all passed. Remaining gaps below are explicit release risks, not silent omissions.

## Release gate: P0

| Area | Contract | Current | Proof layer |
|---|---|---:|---|
| Onboarding | Complete or Skip persists; relaunch opens Home | Covered | focused UI relaunch test |
| Player count | 1 blocked; 2 and 15 allowed; 16 blocked | Gap | pure validation test |
| Player names | Empty and whitespace-only blocked; trim cannot bypass duplicate check | Partial | duplicate-name UI test; pure boundary coverage still missing |
| Generic scoring | Direct Ledger Rail submit creates one round with one entry per player | Covered | SwiftData integration + direct UI smoke |
| Round persistence | Submitted round, totals, and next round survive relaunch | Partial | SwiftData persistence + resume UI; disk relaunch proof still missing |
| Save rollback | Failed round save leaves no partial round or entries | Gap | integration with failing save seam |
| End game rollback | Failed completion save stays in scoring and keeps game active | Gap | integration |
| Undo | Removes only latest round, restores totals, and persists | Partial | UI smoke; persistence failure branch is still missing |
| Phase progression | Complete advances once; failure follows skip option; phase caps at 10 | Covered | pure engine tests |
| Phase completion alert | Keep Playing and End Game preserve their distinct contracts | Gap | focused UI test |
| Dinner | Caller and points persist; caller resets; lowest total wins | Partial | winner engine tests + UI caller smoke |
| Resume | Active session and exact round resume after termination | Partial | active-session UI test; disk relaunch proof still missing |
| Rematch | Copies mode, settings, and players; copies no rounds; consumes one allowance | Partial | configuration unit + Play Again UI + allowance unit |
| Active deletion | Cancel changes nothing; confirm persists and cascades only the game | Gap | integration + UI confirmation |
| History deletion | Confirmed deletion remains deleted after relaunch | Gap | integration |
| Missing route | Invalid scoring, detail, or game-over identifier shows safe unavailable state | Gap | focused UI test |
| Stats | Games, wins, average, best rank, ties, and no-data values are correct | Covered | pure unit tests + extended stats UI |
| Pro purchase | Verified purchase unlocks and persists; pending/unverified do not unlock | Partial | StoreKit state/config tests; native purchase remains manual |
| Restore | Entitlement restores; no purchase stays locked; failure remains retryable | Gap | StoreKit adapter/local configuration |
| Review ask | Counts 2 and 5 only; first session, 120-day, paywall, and duplicate gates | Covered | pure manager tests + native-prompt UI |
| Accessibility | Critical controls have useful label, value, and action | Covered | focused accessibility queries + full UI suite |
| Dynamic Type | Setup, scoring, paywall, Game Over, and history keep actions reachable | Covered | accessibility-extra-large full workflow + 14-screen evidence |

## P1 before TestFlight review

| Area | Contract | Current | Proof layer |
|---|---|---:|---|
| Lowest-score game | Stored rule changes completion and winner behavior | Covered | engine tests + target-score UI flow |
| Duplicate submit | Rapid repeat cannot create two rounds | Covered | focused double-tap UI regression |
| End-game cancel | Entered state and active session remain unchanged | Gap | focused UI test |
| Roster | Cancel changes nothing; confirmed deletion persists; games retain players | Partial | roster reuse/deletion UI + session cascade integration |
| History detail | Correct game, standings, and rounds open from Home and History | Covered | extended history/detail UI tour |
| Head to Head | Empty, selected, expanded, collapse, and mixed-mode grouping are safe | Covered | calculator unit + extended UI selection |
| Tools | Timer, dice, starter, undo, and log never corrupt game state | Partial | deterministic extended UI smoke; state-isolation proof remains missing |
| Theme | Light, dark, and system selection persists across relaunch | Partial | deterministic dark UI tour; persistence proof remains missing |
| Reduce Motion | No confetti or movement fallback; data and navigation timing unchanged | Covered | full workflow with system Reduce Motion + 14-screen evidence |
| Corrupt metadata | Invalid phase JSON and unknown enum values recover without crash | Covered | model unit tests |
| Handwriting retirement | Legacy launch flag cannot restore the retired handwriting flow | Covered | focused UI regression, RED before code |

## Manual device and system checks

Automation is not the correct proof for these:

- Native StoreKit purchase and restore sheets.
- Native review request presentation.
- Haptic timing and intensity.
- VoiceOver reading order and rotor behavior.
- Touch-target feel with one hand.
- Rive motion quality and frame pacing, if Rive ships.
- Dark-mode visual hierarchy and contrast.
- External support and privacy links.
- Archive signing, IAP attachment, privacy answers, screenshots, and App Store submission state.

## Existing useful tests

Keep these as contract evidence:

- Target-score parsing, boundaries, highest/lowest completion, ties, no-target behavior, and rematch target retention.
- StoreKit product identity, stale entitlement revocation, verified entitlement persistence, cancellation mapping, safe failures, deterministic retry, allowance migration, monotonic counting, and revocation snapshot.
- Onboarding Skip and Start.
- Generic, Ten Phases, and Dinner happy paths.
- Resume and Play Again.
- Duplicate-name validation.
- Free-limit paywall and Pro bypass.
- Review request smoke path.
- Multiple active games.
- Roster reuse and deletion confirmation.
- Legal and support reachability.

Treat screenshot tours as visual evidence only. They do not prove data integrity.

## Permutation reduction

Use representative equivalence classes rather than a Cartesian matrix.

- Players: below minimum, minimum, typical four, eight, maximum, above maximum.
- Scores: zero, positive, negative where allowed, exact target, below, above.
- Modes: Generic highest, Generic lowest, Dinner, Ten Phases normal, Ten Phases skip-on-fail.
- Persistence: save/read, relaunch/resume, cancel delete, confirm delete, save failure rollback.
- Entitlement: allowance available, limit reached, purchased, restored, cancelled, pending, unverified, revoked.
- Presentation: default, dark, one accessibility Dynamic Type size, Reduce Motion.

## Test order

1. Prove data integrity and rollback.
2. Prove engine boundaries.
3. Prove entitlement and review policies.
4. Run one critical UI path per workflow.
5. Run visual and device checks.
6. Run the full suite once before archive.
