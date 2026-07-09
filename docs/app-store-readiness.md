# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before ScoreKeeper is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Rebuilt in the Clubhouse Scorecard design system: three pages whose artwork previews the real product (ledger, setup slips, FINAL stamp) | Done for App Store review: saves completion state, supports Skip/Start, covered by a focused UI test | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Done: StoreKit 2 `PaywallView` + `StoreManager`; one-time $0.99 non-consumable `com.icequeen.scorekeeper.pro`; 10 free games via monotonic `gamesStartedCount`, gated at every GameSession creation site; restore + close always available | Create the matching product in App Store Connect before submission | Local testing via `ScoreKeeper/ScoreKeeper.storekit` (see `docs/monetization.md`). UI-test hooks: `-free-games-exhausted`, `-unlock-pro`. |
| Review Ask | Done: `ReviewAskManager` + personal developer-note sheet after the 2nd and 5th completed game (max once per 120 days, never in the first session, never alongside the paywall), then StoreKit `requestReview` | None | UI-test hook: `-force-review-ask`. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates | Keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | Passed via bounded `-only-testing` slices on iOS 26.4 simulator | Keep rerunning focused slices after app-screen work. |
| Archive validation | Unsigned archive validation passed; signed archive used development identity | Install/use Apple Distribution signing before upload. |
| App Store Connect build | Not uploaded from this thread | Upload a distribution-signed archive. |
| Product page metadata | Not tracked in repo | Complete name, subtitle, description, keywords, category, age rating, support URL, privacy policy URL, pricing/availability, screenshots, and review notes in App Store Connect. |
| Privacy nutrition label | Not completed from this thread | Complete App Store Connect privacy answers; likely "Data Not Collected" only if no analytics or third-party collection exists. |

## Implementation Order

1. Define monetization: free, paid upfront, one-time premium, or subscription.
2. Implement StoreKit-backed paywall if monetization uses in-app purchase.
3. Implement review ask using StoreKit review APIs.
4. Refresh any remaining screen network screenshots and UI tests after app-screen work.
5. Resolve Apple Distribution signing and upload.
