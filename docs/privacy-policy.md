# PipCount Privacy Policy

Effective date: October 24, 2026

PipCount is designed to keep game-night information on your device.

## Data stored on your device

PipCount stores player names, game settings, scores, rounds, game history, saved rosters, appearance preferences, and review-prompt eligibility locally using SwiftData and UserDefaults. The legacy free-game allowance and monetization eligibility are stored separately in device-only Keychain items. Eligibility includes the grandfathering decision, whether the exit offer was shown, paywall dismissal, paid conversion, notification permission request, and fixed notification schedule dates. When migrating from the legacy UserDefaults game count, PipCount keeps the maximum of the Keychain count and the legacy count so an update cannot reduce the allowance history. That Keychain allowance survives app deletion and reinstall on the same device, but it does not move to another device and is not synced or uploaded. These values are used only to provide scoring, history, statistics, rematches, purchase access, and preference features.

PipCount does not transmit this information to the developer and does not provide cloud sync.

## Handwriting and score entry

Scoreboard scoring can read a handwritten number with Apple’s on-device Vision tools. The ink image is processed on the device to suggest a score from 0 to 99. PipCount asks you to confirm that number, redraw, or type the score before it is saved. Temporary ink used for recognition is not uploaded and is not stored as a photo library or cloud file. You can also type a score from 0 to 99 without drawing.

## User-directed sharing

After a game, you can share a scorecard image through the system share sheet. PipCount creates that image on the device. It does not upload the image or player data to a PipCount server. If you choose another app, AirDrop, or a message, that destination’s own privacy rules apply. Sharing is optional and happens only when you tap Share.

## Purchases

PipCount uses Apple StoreKit for yearly Pro subscriptions, eligible free trials, and a one-time Lifetime purchase. New installs see the paywall after onboarding. Existing users retain their remaining legacy allowance. Payment information is entered and processed by Apple outside PipCount. The developer does not receive payment-card or bank information. PipCount checks Apple-provided transaction entitlement information to determine whether Pro access is active, in a billing grace period, expired, or revoked. A free trial grants Pro access but does not count as paid conversion.

## Local notifications

PipCount asks for notification permission after a successful free-trial purchase, or once when a non-trial user closes the gift offer. It does not ask at first launch. If you allow notifications, the device can show a trial reminder 24 hours before the trial ends, one gift reminder 24 hours after gift-offer dismissal, and up to four Friday game-night reminders at 18:00 local time. Notifications open subscription management, the gift offer, or Home.

All notifications are scheduled locally. PipCount does not use a push server, upload a notification token, or send schedule data to the developer. A paid conversion removes pending and delivered notifications and stops further scheduling and permission requests. You can disable notifications in iOS Settings. Schedule anchors and the paid-conversion flag remain in the device-only Keychain across reinstall so the app does not restart the offer or four-reminder allowance.

## Data collection and tracking

PipCount has no advertising, analytics SDK, third-party tracking, developer-operated server, or account system. The developer does not collect, sell, or share personal data through the app. PipCount does not operate its own online sharing service. Any share you start uses Apple’s system share sheet at your direction.

## Retention and deletion

Game data, saved rosters, and preferences remain on your device until you delete them in the app or remove the app. Removing the app removes that local SwiftData and UserDefaults data. The legacy allowance and monetization eligibility intentionally remain in the device-only Keychain across deletion and reinstall on the same device; it is not transferred to another device. Apple may retain the purchase record associated with your Apple Account so subscriptions and Lifetime purchases can be restored; Apple’s handling of that information is governed by Apple’s privacy policy.

## Children’s privacy

PipCount does not knowingly collect personal information from children or any other users. It does not provide accounts, messaging, public profiles, or online content.

## Changes

If PipCount’s data practices change, this policy and the App Store privacy disclosure will be updated before the affected version is distributed.

## Contact

For privacy or support questions, email support@contenthelper.in or visit
https://support.contenthelper.in. The same support and privacy destinations are
reachable from PipCount’s in-app Legal & Support page.
