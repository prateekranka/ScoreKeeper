# PipCount monetization

New installs complete or skip onboarding, then see the main full-screen paywall. There are no free game starts for new users. Closing the paywall always opens the app. Active games, history, and statistics stay viewable without Pro. Starting a game or rematch requires Pro unless the device has a remaining legacy allowance.

## Products

Runtime product IDs are defined in `ProProduct` in `ScoreKeeper/Services/ProEntitlement.swift`. The local StoreKit catalog is `ScoreKeeper/ScoreKeeper.storekit`.

| Product | Type | Local catalog price | Introductory offer | Placement |
| --- | --- | --- | --- | --- |
| `com.icequeen.scorekeeper.pro.yearly` | Auto-renewing yearly, PipCount Pro group | $19.99/year | 3-day free trial | Main paywall, preselected |
| `com.icequeen.scorekeeper.pro.yearly.gift` | Auto-renewing yearly, same group and service level | $9.99/year | 3-day free trial | Exit offer, gift notification, gift quick action |
| `com.icequeen.scorekeeper.unlimited` | Non-consumable Lifetime | Local fixture retains its previous price | None | Main paywall, second option |

The owner sets the production Lifetime price in App Store Connect. The app reads each product's `displayPrice`. It reads the introductory period and eligibility from `Product.SubscriptionInfo`; an ineligible Apple Account sees regular subscription pricing without a free-trial claim. Introductory eligibility is shared across the subscription group. [Apple permits one introductory offer per person per group](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions). The gift product is a separate annual price that renews at that price until changed through Apple's pricing process.

## Entitlement and legacy access

`StoreManager` owns one `ProEntitlement` snapshot. A verified Lifetime purchase, the existing `proUnlocked` legacy flag, or an active or billing-grace-period subscription grants Pro. Free trials grant Pro. Trial transactions with an introductory free-trial payment mode do not count as paid conversion. Paid subscription periods, Lifetime purchases, and legacy unlocks count as converted.

The manager reads `Transaction.currentEntitlements`, listens to `Transaction.updates`, and refreshes on foreground and at the next entitlement expiration. Refunds and revocations remove new StoreKit grants. New purchases never set the legacy flag. The old legacy grant remains valid by product decision.

Before any new game, the app makes a one-time grandfathering decision. A device with `gamesStartedCount > 0`, including a retained Keychain count, or any saved game keeps `max(0, 25 - used)` starts. It receives no launch paywall, even when exhausted. An exhausted start or rematch opens the main paywall. Fresh devices get no allowance. Games played during new Pro access cannot create a legacy allowance after expiration. Deleting history does not restore starts. Only grandfathered users with three or fewer starts see a compact remaining count.

## Presentation and exit offer

`PaywallRoute` has `.main` and `.gift`. `ContentView` owns the full-screen cover. Screens request that route through `StoreManager`; successful purchases can resume the blocked action. The cover is centered with a maximum content width. Its content scrolls, the primary button stays in the scrollable content at large text sizes, and X remains visible. Restore is available on both offers. Pending, cancellation, unavailable-product, and failure states remain available.

The first main-paywall X switches directly to the gift offer. UserDefaults and device-only Keychain persist that the offer was shown. Gift X closes the cover. Future normal opens show the main paywall. The gift notification and Home Screen quick action can reopen the gift. There are no timers, countdowns, or expiry claims.

## Local notifications and quick action

`NotificationScheduler` uses a small `LocalNotificationCenter` protocol. No notification permission prompt occurs at launch. A successful trial purchase asks once. A non-trial user is asked once after closing the gift offer. Denial does not cause another request.

The scheduler uses fixed identifiers and persistent dates:

- Trial reminder: 24 hours before trial expiration; opens More and Apple's subscription management.
- Gift reminder: 24 hours after gift dismissal, only without active Pro; opens the gift paywall.
- Game night: four one-shot Fridays at 18:00 local time; opens Home. Foreground refresh does not restart the four-week schedule.

Paid conversion removes all pending and delivered notifications. A persistent conversion flag prevents further scheduling or permission requests, including after expiration, refund, or reinstall. Notifications require iOS permission and are delivered by iOS; exact delivery is outside app control.

The dynamic Home Screen quick action uses the `gift` SF Symbol and title “50% off gift”. It appears only after paywall dismissal and while the user is not Pro. Trials and paid access clear it. `PipCountAppDelegate` and `PipCountSceneDelegate` handle cold and warm activation while retaining the existing SwiftUI scene configuration.

## Development and review

Select `ScoreKeeper/ScoreKeeper.storekit` under the scheme's Run options for local StoreKit testing. Build with `-derivedDataPath .build/DerivedData`. Never use Flowdeck.

All access launch hooks require `-in-memory-store`. They use isolated preferences and allowance storage, and do not read or write production Keychain items:

| Argument | State |
| --- | --- |
| `-fresh-install` | Reset onboarding and show the hard-paywall journey |
| `-grandfathered N` | N used legacy starts; no launch paywall |
| `-trial-active` | Active trial; Pro, not converted |
| `-unlock-pro` | Pro and converted |
| `-exit-offer-seen` | Main X closes without the automatic gift |
| `-open-gift` | Simulate gift quick action |
| `-free-games-exhausted` | Compatibility hook for 25 used legacy starts |

Use these access-state arguments separately. `-force-review-ask` remains the existing review-request hook.

TesterArmy `tests/paywall.e2e.ts` covers the new journey, returning start gate, converted access, grandfathering, trial/gift routing, and largest Dynamic Type. It does not fold the device. The extras suite captures both paywalls.

Reviewer gates: build, TesterArmy e2e on the current device pose, local StoreKit purchase/restore/pending/cancel/refund/renewal/grace tests, real local-notification delivery, cold/warm Home Screen quick action, and light/dark AX5 inspection. Source parsing and test discovery do not prove these runtime behaviors.

## App Store Connect checklist

1. Create one auto-renewable subscription group named **PipCount Pro**. Add localized group display information. Enable Billing Grace Period if grace access is offered.
2. Create `com.icequeen.scorekeeper.pro.yearly` in that group. Set a one-year duration, the $19.99 USD price, localized metadata, availability, tax category, and the shared service level.
3. Create `com.icequeen.scorekeeper.pro.yearly.gift` in the same group and service level. Set a one-year duration and the $9.99 USD price. Add localized metadata, availability, and tax category.
4. Add a **3-day free-trial introductory offer** to each yearly product. Confirm dates, territories, and subscription-group eligibility in sandbox. An Apple Account gets only the introductory eligibility Apple permits for that group.
5. Keep `com.icequeen.scorekeeper.unlimited` as the existing non-consumable. Name it **Lifetime** and set the owner's chosen production price. Preserve its existing purchase history.
6. Add the required in-app-purchase review screenshot for each new subscription. Supply review notes that explain the main paywall, one-time exit route, gift quick action, trial eligibility, legacy access, restore, and how to reach the gift offer. Submit the new products with the app version when required.
7. Confirm the **Paid Apps Agreement** is active. Complete the required banking and tax information.

Production products, introductory offers, price changes, review screenshots, agreements, and App Store submission are owner work. This task changes the app and local catalog only.
