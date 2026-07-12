# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before ScoreKeeper is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Rebuilt in the Clubhouse Scorecard design system: three pages whose artwork previews the real product (ledger, setup slips, FINAL stamp) | Done for App Store review: saves completion state, supports Skip/Start, covered by a focused UI test | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Done: StoreKit 2 `PaywallView` + `StoreManager`; one-time $0.99 non-consumable `com.icequeen.scorekeeper.unlimited`; 25 free games via monotonic `gamesStartedCount`, gated at every GameSession creation site; restore + close always available | Verify the existing product in App Store Connect before submission | Local testing via `ScoreKeeper/ScoreKeeper.storekit` (see `docs/monetization.md`). UI-test hooks: `-free-games-exhausted`, `-unlock-pro`. |
| Review Ask | Done: `ReviewAskManager` + personal developer-note sheet after the 2nd and 5th completed game (max once per 120 days, never in the first session, never alongside the paywall), then StoreKit `requestReview` | None | UI-test hook: `-force-review-ask`. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates; the public-policy draft is tracked in `docs/privacy-policy.md` | Publish the policy at a stable HTTPS URL and keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | Screenshot tour passed via `test-without-building` on the iPhone 17 Pro Max iOS 26.5 simulator | Keep rerunning focused slices after app-screen work. |
| Archive validation | Release archive compiles through Apple Distribution signing inputs; final `codesign` is blocked until the dedicated signing keychain is unlocked | Unlock `ScoreKeeper-signing.keychain-db`, rerun the manual archive, then export with `build/ExportOptions-AppStore.plist`. |
| App Store Connect build | Not uploaded from this thread; app target is prepared as version `1.0` build `3` | Upload a distribution-signed archive after ASC credentials and signing profile are confirmed. |
| Product page metadata | Draft tracked in `.asc/metadata` and validated offline | Add the public support/privacy URLs and owner-only fields, then apply the reviewed metadata in App Store Connect. |
| App Store screenshots | Ten fresh iPhone 17 Pro Max captures in `screenshots/app-store-69/`; ASC CLI validation passes at 1320×2868 | Upload the curated set to the `APP_IPHONE_69`/6.7-inch slot, then review the storefront ordering. |
| Privacy nutrition label | Not completed from this thread | Complete App Store Connect privacy answers; likely "Data Not Collected" only if no analytics or third-party collection exists. |

## Implementation Order

1. Define monetization: free, paid upfront, one-time premium, or subscription.
2. Implement StoreKit-backed paywall if monetization uses in-app purchase.
3. Implement review ask using StoreKit review APIs.
4. Refresh any remaining screen network screenshots and UI tests after app-screen work.
5. Resolve Apple Distribution signing and upload.

## Release inputs still required from the account owner

- App Store Connect API key ID, issuer ID, and private `.p8` key path for the `asc` CLI.
- Public HTTPS support URL and privacy-policy URL.
- Legal copyright owner/year and App Review contact name, phone, and email.
- Confirmation that the existing non-consumable product `com.icequeen.scorekeeper.unlimited` is the product to use for this bundle ID.
- Confirmation that the Paid Apps Agreement, tax, and banking setup are active.

The release thread must not submit the version for review until these inputs are provided and the owner explicitly approves the final metadata and screenshots.
