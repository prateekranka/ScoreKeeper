# Monetization

ScoreKeeper Pro is a one-time StoreKit 2 non-consumable:

- Product id: `com.icequeen.scorekeeper.unlimited`
- Display name: `ScoreKeeper Pro`
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
- `-force-review-ask`: shows the review note after the next Game Over screen.

These hooks are only honored with the existing `-in-memory-store` UI-test pattern.
