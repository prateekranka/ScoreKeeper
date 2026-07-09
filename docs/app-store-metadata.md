# ScoreKeeper App Store Metadata

Drafted for App Store Connect on July 10, 2026. Values marked **Owner input required** cannot be completed from the repository alone.

## App Information

- Name: `ScoreKeeper`
- Subtitle: `Fast scores for game night`
- Primary language: English (U.S.)
- Bundle ID: `com.icequeen.scorekeeper`
- Version: `1.0`
- Primary category: Utilities
- Secondary category: Entertainment
- Copyright: **Owner input required: legal owner name and year**
- Support URL: **Owner input required: hosted URL**
- Privacy Policy URL: **Owner input required: host `docs/privacy-policy.md` at a public URL**
- Marketing URL: Optional

## Promotional Text

Set up the table, score every round, settle the winner, and keep game-night history without passing paper around.

## Description

ScoreKeeper keeps casual game nights moving.

Choose a game, add your players, and record each round with clear totals and generous controls. ScoreKeeper supports a flexible scoreboard, Phase 10, and What’s for Dinner, with the right scoring flow for each game.

During play, built-in tools keep the table organized:

- Live standings and round history
- Fast score controls and safe undo
- Timer, dice, and random starter tools
- Saved rosters for quicker rematches

When the game ends, ScoreKeeper saves the result on your device so you can revisit final standings, compare players, view head-to-head results, and start a rematch.

Your first 25 games are free. After that, a one-time in-app purchase unlocks unlimited new games and rematches. There is no subscription.

ScoreKeeper requires no account and includes no advertising or tracking.

## Keywords

`scorekeeper,scoreboard,game night,phase 10,card games,party games,scores,stats,rounds`

## In-App Purchase

- Type: Non-Consumable
- Reference name: `Unlimited Games`
- Product ID: `com.icequeen.scorekeeper.unlimited`
- Display name: `Unlimited Games`
- Description: `Start unlimited new games and rematches.`
- U.S. base price: `$0.99`
- Family Sharing: Off
- Review screenshot: `screenshots/app-screens/31-paywall.png`
- Review notes: `The paywall appears when the customer attempts to start game 26 or a rematch after using all 25 free games. Tap Restore Purchases to explicitly synchronize a prior purchase.`
- Tax category: **Owner/App Store Connect input required**

Before sandbox testing, the Account Holder must have an active Paid Apps Agreement with banking and tax information. Product metadata can take time to appear in the sandbox after creation.

## App Review Notes

ScoreKeeper does not require an account, login, network content, or special hardware.

To review the core workflow:

1. Launch the app and skip or complete the three-page onboarding.
2. Tap New Game.
3. Choose Scoreboard, add at least two uniquely named players, and choose a win condition.
4. Submit a round, then use End Game to reach the result screen.

The app offers 25 free game starts. The non-consumable `com.icequeen.scorekeeper.unlimited` unlocks unlimited new games and rematches. The purchase screen includes a Restore Purchases action. StoreKit entitlement verification controls access; the app does not maintain an account or external purchase server.

All game data remains on the device. The app contains no ads, analytics SDKs, tracking, or user-generated online content.

Review contact name, phone number, and email: **Owner input required**

## Privacy Nutrition Label

Repository review supports selecting: `No, we do not collect data from this app.`

- Game sessions, player names, scores, history, preferences, allowance counters, and review-prompt state remain on device. The anonymous allowance count uses this device’s private Keychain so reinstalling does not reset the introductory limit.
- The developer has no server or analytics integration.
- StoreKit handles payment entry outside the app; the developer does not receive payment information.
- Reconfirm this answer if analytics, crash reporting, cloud sync, customer support SDKs, or any other third-party code is added.

## Age Rating Questionnaire

Expected posture based on the current binary:

- In-app controls/capabilities: none
- User-generated online content or messaging: none
- Advertising: none
- Violence, mature themes, profanity, substances, horror, medical content, or sexual content: none
- Simulated gambling: none; the app records scores and provides a generic die roller but does not simulate wagering or casino play
- Gambling or loot boxes: no
- Contests: no
- Age-category override: not applicable

App Store Connect calculates the final regional rating from the completed questionnaire.

## Release Inputs Still Required

- Public support and privacy-policy URLs
- Legal copyright owner and App Review contact details
- Active Paid Apps Agreement, banking, and tax setup
- App Store Connect app record matching `com.icequeen.scorekeeper`
- Non-consumable product created with the exact product ID above and submitted with the app version
- Apple Distribution certificate/profile or working automatic-distribution signing for team `4JRB53LG5C`
- Final App Store screenshots and any required localization

Apple references: [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [create a non-consumable](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases), and [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
