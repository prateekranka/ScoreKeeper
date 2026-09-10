# PipCount Monetization

PipCount Pro is a one-time StoreKit 2 non-consumable:

- Product id: `com.icequeen.scorekeeper.unlimited`
- Display name: `PipCount Pro`
- Price: `$0.99`
- Local config: `ScoreKeeper/ScoreKeeper.storekit`

## Local StoreKit Testing

1. Open `ScoreKeeper.xcodeproj` in Xcode.
2. Edit the ScoreKeeper scheme.
3. Select Run > Options.
4. Set StoreKit Configuration to `ScoreKeeper/ScoreKeeper.storekit`.
5. Run the app and start games until the 25-game free limit is exhausted, or use the UI-test launch hook `-free-games-exhausted` together with `-in-memory-store`.

The UI tests do not depend on the StoreKit config or network state. They use launch arguments:

- `-free-games-exhausted`: sets the monotonic `gamesStartedCount` to 25.
- `-unlock-pro`: forces the local Pro entitlement.
- `-force-review-ask`: makes the next eligible Game Over screen call Apple's native review request API; no custom review sheet is shown.

These hooks are only honored with the existing `-in-memory-store` UI-test pattern.

## Current upgrade routes (2026-09-08)

PipCount Pro is still the one-time non-consumable `com.icequeen.scorekeeper.unlimited`. Price and territory must not be changed in this release.

Visible upgrade or remaining-count entries:

- Home: `25 free games included` through 21 used starts, then `N free games left`, with `upgrade to pipcount pro`.
- More / Legal & Support: `pipcount pro` panel, `N free games remaining`, restore on the paywall.
- iPad sidebar: remaining-count row that opens the same paywall.
- New game / rematch: paywall when 25 successful starts are used and the Apple ID is not unlocked.

A verified purchase unlocks unlimited new games. Active games and history stay available after the free allowance is used. Deleting history does not restore a free start. Native App Store sandbox purchase, restore, pending, and refund proof remains a device check, not a local `.storekit` result.
