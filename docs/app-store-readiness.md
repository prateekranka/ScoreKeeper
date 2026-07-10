# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before ScoreKeeper is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Redesigned as a polished three-page first-launch `OnboardingView` in `ContentView.swift` | Done for App Store review: explains setup, live scoring/tools, history/stats/rematches; saves completion state; supports Skip/Start; covered by a focused UI test and refreshed screenshot | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Implemented | Code-ready; App Store Connect setup still required | The first 25 game starts are free. Game 26 and later require the `$0.99` non-consumable `com.icequeen.scorekeeper.unlimited`. The allowance is mirrored to a device-only Keychain item so reinstalling does not reset it. StoreKit verifies current entitlements, listens for updates, supports restore, and has a local `.storekit` configuration. Focused Home, Play Again, real local purchase, and dismissed-pending-purchase tests pass. |
| Review Ask | Implemented | Code-ready | Uses SwiftUI's StoreKit review action after the fourth successful completion, delayed on Game Over and limited to one request attempt per app version. It is disabled for UI tests and never blocks navigation. |

## Release Mechanics

| Item | Current State | Required Before Review |
| --- | --- | --- |
| Privacy manifest | Present and validates | Keep `PrivacyInfo.xcprivacy` aligned with actual app behavior. |
| UI regression tests | Monetization, onboarding, all three game modes, history, stats, and screenshot-capture slices pass. The real local `$0.99` StoreKit purchase test passes on iOS 27, including verified unlock continuation; iOS 26.4/26.5 CLI StoreKitTest sync has a known Apple regression. | Run sandbox cancellation, refund/revocation, and restore checks after the App Store Connect product exists. |
| Archive validation | Distribution signing is configured for team `4JRB53LG5C`; the signed `1.0 (2)` IPA passes strict local signature, entitlement, and embedded-profile validation. | Done for build 2. Keep the dedicated signing keychain and Store profile valid for future uploads. |
| App Store Connect build | `1.0 (2)` uploaded on July 10, 2026; App Store Connect build state is `VALID` with no upload warnings or errors. | Done for build 2. Select this build for TestFlight or the App Store version after metadata is complete. |
| Product page metadata | Drafted in `docs/app-store-metadata.md` | Provide owner/contact/legal values and enter the approved copy in App Store Connect. |
| Privacy nutrition label | Repository-reviewed draft is "Data Not Collected" | Confirm in App Store Connect and keep accurate if SDKs, sync, servers, or analytics are added. |
| Privacy policy | Drafted in `docs/privacy-policy.md` | Add a monitored contact method and host it at the required public URL. |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in app target | Reconfirm if non-exempt encryption or third-party libraries are added. |

## Implementation Order

1. Create the non-consumable product in App Store Connect with the exact product ID and `$0.99` U.S. base price.
2. Activate the Paid Apps Agreement and finish banking/tax setup.
3. Add the required support/privacy URLs, legal owner, review contact, age rating, and metadata from `docs/app-store-metadata.md`.
4. Run sandbox purchase, pending, cancellation, refund/revocation, and restore validation against the App Store Connect product. Local StoreKit coverage already verifies product loading, purchase/unlock continuation, paywall gating, and safe dismissal of a pending purchase.
5. Select App Store marketing screenshots from the refreshed screen inventory. All visibly changed screen families are refreshed; unchanged utility overlays remain available as route/QA references. Avoid the `21-game-details.png` attachment for marketing because its simulator capture includes top-corner masking artifacts.
6. **Done:** Apple Distribution signing and a matching ScoreKeeper App Store profile are installed for team `4JRB53LG5C`; version `1.0` build `2` is uploaded and valid.
