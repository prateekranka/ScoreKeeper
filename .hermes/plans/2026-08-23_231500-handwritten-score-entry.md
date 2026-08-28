# PipCount Round-Entry Card Deck Implementation Plan

> **For Hermes:** Single implementation agent (Luna max) writes all Swift code locally, pushes to branch. Central Mac verification after.

**Goal:** Replace the per-row scoring table with a full-screen card deck. User taps "Score Round", gets one card per player, draws each score with their finger, taps ✓ to see the recognized number in a confirm overlay, accepts or retries, then swipes left (or auto-advances after accepting) to the next card. Last card submits the round.

**Confirmed flow (from prototype iteration):**
1. Scoring screen shows running totals + big **Score Round** button.
2. Tap Score Round → full-screen deck opens. First-time users get a 3-step coach overlay.
3. Card N of M: player marker + name + total up top; large white canvas below; readout + ⌫ + ✓ at bottom.
4. User draws a number (1–2 digits) with their finger.
5. Tap ✓ → Vision framework recognizes → confirm overlay replaces the canvas showing the number large with "is this right?" and two icon buttons (↺ retry / ✓ accept).
6. Retry → clears canvas, back to drawing. Accept → commits readout with flash, auto-advances to next card after ~250 ms.
7. User can also swipe left/right on the card edges to navigate (swipe does NOT commit unaccepted drawings).
8. Last card accept → auto-submits round, closes deck, returns to scoring screen.
9. Cancel (✕ top-right) closes deck without committing anything.

**Architecture:** Three new files plus modification to GenericScoringView.

---

## Files

| Action | Path |
|---|---|
| Create | `ScoreKeeper/Services/ScoreRecognizer.swift` |
| Create | `ScoreKeeper/Views/Components/ScoreWritingCanvas.swift` |
| Create | `ScoreKeeper/Views/Scoring/RoundEntryDeckView.swift` |
| Modify | `ScoreKeeper/Views/Scoring/GenericScoringView.swift` |

## Implementation notes

### ScoreRecognizer.swift
- Static func `recognize(_ image: UIImage) async -> Int?`
- Uses `VNRecognizeTextRequest` (Vision) with `recognitionLevel = .fast`, `usesLanguageCorrection = false`
- Filters results to digit characters only, sorts by bounding-box x-position, joins and parses
- Clamps to `-9999...9999`
- Returns nil if no digits found

### ScoreWritingCanvas.swift
- `UIViewRepresentable` wrapping `PKCanvasView`
- `drawingPolicy = .anyInput` (finger works)
- Stroke: black, width ~8, on white background
- Exposes `clear()` via a binding-triggered action or `@Binding var clearTrigger: Int`
- Function `captureImage() -> UIImage` renders the canvas to a UIImage for recognition
- Accessibility identifier set from outside

### RoundEntryDeckView.swift
- Presented as `.fullScreenCover(isPresented:)` from GenericScoringView
- Properties: `session: GameSession`, `onSubmit: (UUID: Int) -> Void`, `onCancel: () -> Void`
- State: `currentIndex`, `scores: [UUID: Int]`, `clearTriggers: [UUID: Int]`, `confirmingPlayer: Player?`, `confirmedValue: Int?`
- Layout per card: header (marker/name/total), canvas (flex), confirm overlay (conditional), footer (readout/⌫/✓)
- Confirm overlay: `.fullScreenCover` style within the card using `ZStack`; shows recognized number large + two icon buttons
- Deck navigation: custom drag gesture OR `TabView(pageIndicatorStyle:.never)`; swipe threshold >60pt horizontal >1.5× vertical
- Coach overlay: shown when `!UserDefaults.standard.bool(forKey:"hasSeenScoreDeckTutorial")`; 3 steps; sets flag on completion/skip
- Progress dots at bottom; ✕ close button top-right
- Reduce Motion: cross-fade instead of slide between cards

### GenericScoringView.swift changes
- Remove `CompactRoundScoreTable` usage from body
- Replace with: compact running-totals `List` or `ForEach` showing marker+name+total+last-round-delta, plus large blue "✎ Score Round" button
- Add `@State private var showDeck = false`
- Present `RoundEntryDeckView` as `.fullScreenCover(isPresented:$showDeck)`
- `onSubmit` closure receives scores dict, calls existing `submitRound(using:)`
- Keep `ScoringScreenLayout` wrapper (header, undo, log, end-game unchanged)
- Keep `RoundHistoryStrip` footer

## Contracts preserved

- Duplicate-submit guard in `ScoringScreenLayout.performAction()` untouched
- Undo, Round Log, End Game flows untouched
- Engine/model/paywall/review-policy untouched
- All existing accessibility identifiers on non-changed surfaces preserved
- `-force-handwriting-entry` legacy flag: harmless no-op (deck is always available)

## Test plan

### Unit tests (ScoreKeeperTests)
- `ScoreRecognizerTests.swift`: feed synthetic images with drawn digits, assert correct integer returned. Also test empty image → nil, multi-digit → parsed correctly.

### UI tests (ScoreKeeperUITests)
- Rewrite `testGenericScoringIgnoresLegacyHandwritingFlagAndSubmitsDirectly` → `testDeckOpensAndSubmitsRound`
- New: `testDeckCancelDiscardsDrafts`
- New: `testDeckSwipeNavigationReachesAllPlayers`

## Verification

```bash
ssh prateekranka@100.96.165.70 '/usr/bin/xcodebuild test \
  -project "$HOME/Cowork/ScoreKeeper-worktrees/app-dev-pipcount/ScoreKeeper.xcodeproj" \
  -scheme ScoreKeeper \
  -destination "platform=iOS Simulator,id=B04ECE5E-A620-4317-9678-A73B8B7007D9" \
  -derivedDataPath /tmp/pip-deck-dd \
  CODE_SIGNING_ALLOWED=NO'
```

Then screenshot tour + unsigned Release archive sanity (version 1.0, build 11).
