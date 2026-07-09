# App Store Readiness

This tracks product, release, and App Store Connect work that must be true before ScoreKeeper is submitted for review.

## In-App Release Screens

| Screen | Current State | Required Before Review | Notes |
| --- | --- | --- | --- |
| Onboarding | Redesigned as a polished three-page first-launch `OnboardingView` in `ContentView.swift` | Done for App Store review: explains setup, live scoring/tools, history/stats/rematches; saves completion state; supports Skip/Start; covered by a focused UI test and refreshed screenshot | Route remains a first-launch `fullScreenCover`; no paywall or review prompt is included. |
| Paywall | Missing | Add a real paywall screen only after the monetization model and App Store Connect product IDs are known | Use StoreKit for digital subscriptions/features. Do not ship a nonfunctional paywall. |
| Review Ask | Missing | Add a lightweight post-success review ask that calls StoreKit's system review prompt when appropriate | Trigger after a positive moment such as completed games, never on first launch or as a blocking gate. |

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
