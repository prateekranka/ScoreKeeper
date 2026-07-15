# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before PipCount is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Rebuilt in the Clubhouse Scorecard design system: three pages whose artwork previews the real product (ledger, setup slips, FINAL stamp) | Done for App Store review: saves completion state, supports Skip/Start, covered by a focused UI test | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Done: StoreKit 2 `PaywallView` + `StoreManager`; one-time $0.99 non-consumable `com.icequeen.scorekeeper.unlimited`; 25 free games via monotonic `gamesStartedCount`, gated at every GameSession creation site; restore + close always available | Verify the existing product in App Store Connect before submission | Local testing via `ScoreKeeper/ScoreKeeper.storekit` (see `docs/monetization.md`). If StoreKit cannot load the product, PipCount disables purchase and exposes a retry action; the restore and close controls remain available and labeled for accessibility. UI-test hooks: `-free-games-exhausted`, `-unlock-pro`. |
| Review Ask | Done: `ReviewAskManager` invokes Apple’s native StoreKit `requestReview` directly after the 2nd and 5th completed game (max once per 120 days, never in the first session, never alongside the paywall) | None | UI-test hook: `-force-review-ask`. There is no custom pre-review sheet. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates; the public-policy draft is tracked in `docs/privacy-policy.md` | Publish the policy at a stable HTTPS URL and keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | Screenshot tour passed via `test-without-building` on the iPhone 17 Pro Max iOS 26.5 simulator | Keep rerunning focused slices after app-screen work. |
| Archive validation | Build 6 archived, exported, uploaded, and is valid in App Store Connect. Stable Xcode 26.6 and the installed Apple Distribution identity/profile are the release toolchain. | Archive build 7 from the exact reviewed commit, verify its embedded version/build, then upload with the validated ASC keychain profile. |
| App Store Connect build | Version `1.0` has valid build 6 attached; live ASC preflight confirms build 7 is the next unused number | Upload build 7 for TestFlight/release validation, then attach the chosen build to the App Store version. |
| Product page metadata | Draft tracked in `.asc/metadata` and validated offline | Add the public support/privacy URLs and owner-only fields, then apply the reviewed metadata in App Store Connect. |
| App Store screenshots | Existing 1320×2868 captures still contain stale ScoreKeeper/Phase 10 wording | Refresh the PipCount/Ten Phases storefront set from the reviewed build, validate it, upload it, and review ordering before App Store version submission. |
| Privacy nutrition label | Not completed from this thread | Complete App Store Connect privacy answers; likely "Data Not Collected" only if no analytics or third-party collection exists. |
| In-app legal/support | Done: Legal & Support is reachable from the root screen; Privacy Policy and Support links use accessible PipCount labels | Done | `https://support.contenthelper.in` and `https://privacy.contenthelper.in` returned HTTP 200 with PipCount-branded pages on July 15, 2026. |

## Implementation Order

1. Define monetization: free, paid upfront, one-time premium, or subscription.
2. Implement StoreKit-backed paywall if monetization uses in-app purchase.
3. Implement review ask using StoreKit review APIs.
4. Refresh any remaining screen network screenshots and UI tests after app-screen work.
5. Resolve Apple Distribution signing and upload.

## Account and submission gates

- ASC Admin authentication is active through the `ScoreKeeper Release` system-keychain profile (key `Y3G56JD647`, issuer `50b76771-2e18-454c-81fd-845e94864820`).
- Public support and privacy URLs are live and PipCount-branded.
- App Review contact is Esha Bhoon, `+91-7208406820`, `eshabhoon@gmail.com`; copyright year is 2026.
- The confirmed non-consumable is `com.icequeen.scorekeeper.unlimited`, PipCount Pro, $0.99, and is Ready to Submit.
- Recheck Paid Apps agreement, banking, and tax status in App Store Connect before the paid App Store submission; the public API does not expose a reliable final status.
- Complete/export compliance for the selected build, publish the privacy answers, refresh screenshots, and submit the IAP with the App Store version.

Do not submit the App Store version until the refreshed metadata/screenshots, privacy answers, IAP, agreements, and selected build pass the final release review. TestFlight beta review is a separate gate.
