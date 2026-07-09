# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before ScoreKeeper is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Redesigned as a polished three-page first-launch `OnboardingView` in `ContentView.swift` | Done for App Store review: explains setup, live scoring/tools, history/stats/rematches; saves completion state; supports Skip/Start; covered by a focused UI test and refreshed screenshot | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Implemented | Code-ready; App Store Connect setup still required | The first 25 game starts are free. Game 26 and later require the `$0.99` non-consumable `com.icequeen.scorekeeper.unlimited`. StoreKit verifies current entitlements, listens for updates, supports restore, and has a local `.storekit` configuration. Focused Home and Play Again gating tests pass. |
| Review Ask | Implemented | Code-ready | Uses SwiftUI's StoreKit review action after the fourth successful completion, delayed on Game Over and limited to one request attempt per app version. It is disabled for UI tests and never blocks navigation. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates | Keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | Monetization, onboarding, all three game modes, history, stats, and screenshot-capture slices pass. The real local `$0.99` StoreKit product test passes on iOS 27; iOS 26.4/26.5 CLI StoreKitTest sync has a known Apple regression. | Keep rerunning focused slices after app-screen work. |
| Archive validation | Unsigned and development-signed archives validate. App Store export fails with `No signing certificate "iOS Distribution" found` for team `4JRB53LG5C`. | Install/use the team’s Apple Distribution certificate/private key and App Store profile before upload. |
| App Store Connect build | Not uploaded from this thread | Upload a distribution-signed archive. |
| Product page metadata | Drafted in `docs/app-store-metadata.md` | Provide owner/contact/legal values and enter the approved copy in App Store Connect. |
| Privacy nutrition label | Repository-reviewed draft is "Data Not Collected" | Confirm in App Store Connect and keep accurate if SDKs, sync, servers, or analytics are added. |
| Privacy policy | Drafted in `docs/privacy-policy.md` | Add a monitored contact method and host it at the required public URL. |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in app target | Reconfirm if non-exempt encryption or third-party libraries are added. |

## Implementation Order

1. Create the non-consumable product in App Store Connect with the exact product ID and `$0.99` U.S. base price.
2. Activate the Paid Apps Agreement and finish banking/tax setup.
3. Add the required support/privacy URLs, legal owner, review contact, age rating, and metadata from `docs/app-store-metadata.md`.
4. Run sandbox purchase, pending, cancellation, refund/revocation, and restore validation against the App Store Connect product.
5. Review the refreshed representative screen-family screenshots (Home, setup, gameplay, summary, history/stats, and paywall); refresh utility-overlay variants only if their unchanged presentation needs new marketing captures.
6. Install/configure Apple Distribution signing for team `4JRB53LG5C`, export the validated archive, and upload.
