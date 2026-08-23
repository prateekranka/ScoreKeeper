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
| UI regression tests | On 2026-08-23, 35 unit tests, 23 main UI tests, and 3 legal/review UI tests passed. Standard, extended, Reduce Motion, accessibility-extra-large Dynamic Type, and deterministic dark-mode screenshot tours also passed on iOS 26.5. | Keep the same bounded suites green on the release commit. Evidence is under `screenshots/review-20260823`, `screenshots/review-extended-20260823`, and `screenshots/qa-accessibility`. |
| Archive validation | Release build 10 archived successfully without signing on Xcode 26.6 and verified version `1.0`, build `10`, bundle `com.icequeen.scorekeeper`. A signed archive reached `CodeSign` with the installed distribution identity/profile, then the SSH session returned `errSecInternalComponent`. | Run the signed archive from an unlocked Mac login session, then export it with `ExportOptions-AppStore.plist`. The remaining block is keychain access, not compilation or provisioning selection. |
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
- Remaining release action: use an unlocked Mac login session to create and export the signed build-10 archive, upload it, replace the old pending binary, attach the non-consumable, refresh storefront screenshots/privacy answers, and submit for review.

Do not submit the App Store version until the refreshed metadata/screenshots, privacy answers, IAP, agreements, and selected build pass the final release review. TestFlight beta review is a separate gate.
