# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before PipCount is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Rebuilt in the Paper Bauhaus system: three pages preview the ledger, setup, and FINAL-score workflow | Done for App Store review: saves completion state, supports Skip/Start, and is covered by focused and screenshot-tour UI tests | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Done: StoreKit 2 `PaywallView` + `StoreManager`; one-time $0.99 non-consumable `com.icequeen.scorekeeper.unlimited`; 25 free games via monotonic `gamesStartedCount`, gated at every GameSession creation site; restore + close always available | Submit the existing **Non-Consumable** with the next app version. | Local testing via `ScoreKeeper/ScoreKeeper.storekit` (see `docs/monetization.md`). If StoreKit cannot load the product, PipCount disables purchase and exposes a retry action; the restore and close controls remain available and labeled for accessibility. UI-test hooks: `-free-games-exhausted`, `-unlock-pro`. |
| Review Ask | Done: `ReviewAskManager` invokes Apple’s native StoreKit `requestReview` directly after the 2nd and 5th completed game (max once per 120 days, never in the first session, never alongside the paywall) | None | UI-test hook: `-force-review-ask`. There is no custom pre-review sheet. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates; the public-policy draft is tracked in `docs/privacy-policy.md` | Publish the policy at a stable HTTPS URL and keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | On 2026-08-23, 23 main UI checks and 3 legal/review UI checks passed. Standard, extended, Reduce Motion, accessibility-extra-large Dynamic Type, and deterministic dark-mode screenshot tours also passed on iOS 26.5. | Run the current TesterArmy e2e suites on the release commit. Evidence is under `screenshots/review-20260823`, `screenshots/review-extended-20260823`, and `screenshots/qa-accessibility`. |
| TestFlight upload | Build 10 (v1.0) archived, signed, exported, uploaded, and VALID in App Store Connect; export compliance set; attached to internal group "First Testers"; expires 2026-11-24. Signed archive/export ran through the GUI-Terminal bridge (`~/bin/gui-run.sh`) because SSH sessions cannot use the login-keychain distribution key. | For future uploads, reuse `~/bin/gui-run.sh` for archive+export steps; then poll ASC and attach groups via `asc_api.py`. |
| App Store Connect build | Live ASC checks on 2026-08-23 show builds 1–9 valid; build 9 is the latest and has export compliance cleared. Build 10 is the next unused number. Version `1.0` is `PENDING_DEVELOPER_RELEASE` with the pre-redesign build. | Cancel or reject the old pending release without releasing it, upload build 10, clear export compliance, attach build 10 and PipCount Pro, then resubmit version 1.0. |
| Product page metadata | Draft tracked in `.asc/metadata` and validated offline | Add the public support/privacy URLs and owner-only fields, then apply the reviewed metadata in App Store Connect. |
| App Store screenshots | Fresh simulator QA captures now cover the redesigned product, utilities, history/stats, paywall, Dynamic Type, Reduce Motion, and dark mode. Existing 1320×2868 storefront captures still contain stale ScoreKeeper/Phase 10 wording. | Produce the required storefront sizes from build 10, validate safe areas and copy, upload them, and review ordering before submission. |
| Privacy nutrition label | Not completed from this thread | Complete App Store Connect privacy answers; likely "Data Not Collected" only if no analytics or third-party collection exists. |
| In-app legal/support | Done: Legal & Support is reachable from the root screen; Privacy Policy and Support links use accessible PipCount labels | Done | `https://support.contenthelper.in` and `https://privacy.contenthelper.in` returned HTTP 200 with PipCount-branded pages on July 15, 2026. |

## Implementation Order

1. Define monetization: free, paid upfront, one-time premium, or subscription.
2. Implement StoreKit-backed paywall if monetization uses in-app purchase.
3. Implement review ask using StoreKit review APIs.
4. Refresh any remaining screen network screenshots and UI tests after app-screen work.
5. Resolve Apple Distribution signing and upload.

## Account and submission gates

- `asc doctor` finds the `ScoreKeeper Release` system-keychain profile, but direct `asc` queries from SSH cannot resolve its credentials. The file-backed ASC API route used by `altool` and the release helper successfully verified the live app and build state on 2026-08-23.
- Public support and privacy URLs are live and PipCount-branded.
- App Review contact is Esha Bhoon, `+91-7208406820`, `eshabhoon@gmail.com`; copyright year is 2026.
- Live App Store Connect verification on July 22 confirmed `com.icequeen.scorekeeper.unlimited` is PipCount Pro, $0.99, type **Non-Consumable**, and ready for review. App Review's “consumable item” wording did not reflect the configured product type.
- The Paid Apps Agreement is active through April 30, 2027; banking and tax forms are active.
- Complete/export compliance for the selected build, publish the privacy answers, refresh screenshots, and submit the IAP with the App Store version.

## Verified Release Checkpoint — 2026-08-23

- Branch: `app-dev/pipcount-bauhaus-motion`.
- Candidate: PipCount 1.0 build 10. Build 10 is reserved locally and is not uploaded.
- Product QA: all automated suites and both screenshot tours pass; Reduce Motion, accessibility-extra-large Dynamic Type, and dark mode have captured evidence.
- Release compile: unsigned App Store archive succeeds and validates the exact version, build, and bundle identity.
- Live ASC: PipCount remains `PENDING_DEVELOPER_RELEASE`; the attached approved binary is the pre-redesign version and must not be released.
- Build 10 is live on internal TestFlight (2026-08-26). Remaining release actions: fix the one failing UI test (testThemeToggleAndHeadToHeadStatsNavigation), attach the non-consumable IAP to the App Store version, refresh storefront screenshots/privacy answers, then submit for review.

Do not submit the App Store version until the refreshed metadata/screenshots, privacy answers, IAP, agreements, and selected build pass the final release review. TestFlight beta review is a separate gate.

## Draft checkpoint — 2026-09-08 (supersedes build-10 instructions above)

The 2026-08-23 receipt remains historical. Do not copy its build-10 upload steps.

- Candidate worktree: `app-dev/pipcount-b16-copy` at the local frozen-scope tree.
- Product version: `1.0`. Live attached App Store binary is still **build 9** and must not be released.
- Latest previously uploaded binary at plan time: **build 16**, `VALID`. If this tree’s code or assets change, upload a new unused build after a live inventory. Never reuse 16.
- Device families: iPhone and native iPad. Storefront screenshots must include the iPad class required for the selected binary.
- Pro routes in the current UI: Home upgrade card, More / Legal & Support, iPad sidebar countdown, and the paywall after 25 successful game starts. Do not tell reviewers to use a removed Home-only label.
- Local privacy draft: `docs/privacy-policy.md` now describes on-device Vision handwriting, typed 0–99 entry, and user-directed system share. Publish the live `https://privacy.contenthelper.in` page only after approval. Confirm ContentHelper’s page on the same host is not overwritten.
- App Privacy answers: not verifiable through the public ASC API. Complete them in the authenticated portal. Likely “Data Not Collected” if that still matches the packaged `PrivacyInfo.xcprivacy` (UserDefaults `CA92.1`, no collected data, no tracking).
- Local StoreKit tests are not proof of App Store sandbox purchase or restore.

### App Review notes draft (do not publish until approved)

No account or special hardware is required for ordinary scorekeeping.

1. Launch the app. Skip or complete the three onboarding pages.
2. Tap start new game, choose Scoreboard, Ten Phases, or What’s for Dinner, add at least two players, and start.
3. Scoreboard: tap score round, draw a number or tap Type score, confirm with Use, or Redraw. Round scores are 0–99. Totals may be higher. Undo last round from the scoring screen.
4. A target score ends the game after a qualifying submitted round. Otherwise use End game.
5. PipCount Pro is a one-time non-consumable. Open it from Home, from More, or from the iPad sidebar. Restore purchases is on the paywall. The paywall also appears when starting a 26th game. StoreKit needs a network. Do not expect a purchase to work offline.
6. After a game, Share uses the system share sheet. That is optional and user-directed.

### What’s New draft (en-US)

Score game night on a rebuilt score pad. Pick a scoreboard, ten phases, or dinner scoring. Draw or type each round, confirm before it saves, and keep history, stats, and rematches on this device. The first 25 games are free. A one-time purchase unlocks unlimited games. No subscription.

### IAP review note draft (do not publish until the version is editable)

PipCount Pro is a one-time non-consumable. Open it from Home (`upgrade to pipcount pro`), from More / Legal & Support, or from the iPad sidebar remaining-count row. The paywall also appears when starting a 26th game or a rematch after 25 successful starts. Restore purchases is on the paywall. StoreKit needs a network.

Live note still says only Home. Keep that fact until Bobby approves the replacement text. Home still has an upgrade card.

## Local implementation ledger — 2026-09-08

| ID | Defect or obligation | Action | Status |
|---|---|---|---|
| PC-01 | History delete swallowed save errors | Same save/rollback/alert pattern as Home | Done locally |
| PC-02 | Three UI tests overstated coverage | Existing tests now prove auto-finish, rapid submit, and resume | Done locally |
| PC-03 | No direct typed-score route | Type score control on the drawing card; 0–99 Use confirm kept | Done locally |
| C-3 | Invalid typed score had no recovery copy | Caption `enter a score between 0 and 99` | Done locally |
| PC-06 | CI built but did not test; branch omitted | Scheme test job + `app-dev/pipcount-b16-copy` trigger on the existing production-validation workflow | Local edit only; push needs GitHub publication approval |
| PC-09 | Other worktrees hold unshipped experiments | No import from root, Interfacecraft, or ML Kit | Preserved in place |
| PC-10 | iPad sidebar squeezed player setup and game settings | Stack vs side-by-side now follows remaining detail width, not size class alone | Done locally on iPad Air 11 simulator |
| PC-11 | Cosmetic/dead-code/test pruning | Deferred | Not done |

## Local evidence — 2026-09-08 final tree

- Full scheme on PipCount Bauhaus QA (iPhone 17 Pro Max, iOS 26.5) after PC-10: `result=Passed`, `passedTests=140`, `skippedTests=2` (screenshot tours), `failedTests=0`, `totalTestCount=142`. Bundle: `build/pc-fix-20260908/full-pc10.xcresult`. Earlier same-day pre-fix run: `build/pc-fix-20260908/full.xcresult`.
- Focused UI proofs for auto-finish, resume, rapid submit, typed score, and 0–99 hint: 7 passed. Bundle: `build/pc-fix-20260908/ui-focused.xcresult`.
- Unit/StoreKit local contracts: 110 passed. Bundle: `build/pc-fix-20260908/unit.xcresult`.
- Unsigned archive after PC-10: `build/pc-fix-20260908/PipCount-1.0-b17-pc10.xcarchive`. Identity: PipCount `1.0` build `17`, bundle `com.icequeen.scorekeeper`, device family `[1,2]`, iOS 26.0, `ITSAppUsesNonExemptEncryption=NO`, `PrivacyInfo.xcprivacy` packaged, signing identity empty. Not uploaded.
- Local storefront drafts: `build/pc-fix-20260908/storefront/APP_IPHONE_67` (1320×2868) and `APP_IPAD_PRO_3GEN_129` (2064×2752). Extra iPad Air 11 drafts: `APP_IPAD_PRO_3GEN_11` (1640×2360). Do not upload without Bobby approval. Live ASC still has 4 old iPhone images and no iPad set.
- PC-10 iPad Air 11 simulator (iOS 26.5, not 26.6): sidebar-open portrait stacks player setup and game settings so names and win labels stay readable. Sidebar closed uses side-by-side. Landscape keeps Continue and Start reachable. Evidence: `build/pc-fix-20260908/ipad-layout/`. Physical TestFlight install remains Gate H.
- Native App Store sandbox purchase/restore was not run. Local `.storekit` tests are not that proof.
- Paper file `01KY2MC0H77PJPKKT5XDQDYJ6Y` was not edited. Free-account MCP quota is exhausted and no GUI control window was available. Gate P stays open.
- App Store version `1.0` remains `PENDING_DEVELOPER_RELEASE` / `MANUAL` with attached build 9. Latest uploaded binary is still build 16 `VALID`. Next unused number is 17. Withdrawal, metadata publish, screenshot upload, IAP note edit, signed upload, and review submit stay gated.
