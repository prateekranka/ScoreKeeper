# ScoreKeeper iOS 26 Redesign — "Clubhouse Scorecard" Spec

This is the frozen spec for the full visual redesign plus release screens (onboarding, paywall,
review ask). Implementation happens on branch `redesign/ios26-scorecard`.

## Design Direction

The owner's reference board is entirely **physical scorekeeping artifacts**: vintage baseball
scorecards, paper score pads and tally notepads, laser-cut maple Phase 10 peg boards, brass/wood
snooker scoreboards, dry-erase game-night boards, flip-number scoreboards. The redesign brings that
analog warmth to a native iOS 26 app.

**One sentence:** *A beautifully printed scorecard on a clubhouse table — paper, ink, felt green,
lacquer red, and brass — with iOS 26 Liquid Glass reserved for the app chrome.*

Anti-goals (what makes the current UI feel like AI slop, to be removed everywhere):
- Pastel candy palette (coral/teal/sunny-yellow/purple) and `tint.opacity(0.15)` washes.
- `design: .rounded` fonts everywhere.
- Diagonal pastel background gradients.
- `.regularMaterial` cards floating on gradients.
- Generic `RoundedRectangle` + SF Symbol + capsule-chip composition on every screen.

## Design Tokens

Create `ScoreKeeper/Theme/ClubhouseTheme.swift` (replaces the guts of `AppTheme.swift`; keep the
`appBackground()` entry point working so call sites migrate mechanically). All colors defined for
light AND dark via dynamic `Color(light:dark:)` helper (UIColor trait initializer).

### Color (light / dark)

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `paper` | #F4F2EC | #151310 | App background (dark = near-black clubhouse) |
| `paperCard` | #FFFDF8 | #211E19 | Cards, sheets, score slips |
| `paperSunken` | #EAE6DC | #100F0D | Inset wells, grouped rows |
| `ink` | #242522 | #F5F1E8 | Primary text |
| `inkMuted` | #65645E | #B9B2A6 | Secondary text |
| `rule` | ink 14% | ink 14% | Hairline ruled lines, borders |
| `felt` | #2F664B | #74B58E | Primary brand green (buttons, selection, links) |
| `feltDeep` | #244F3A | #4B8D68 | Pressed states, hero surfaces |
| `lacquer` | #A73D32 | #F07164 | Destructive, negative deltas, "FINAL" stamp |
| `brass` | #80661C | #E4B44A | Winner/leader accents, crowns, premium |
| `onFelt` | #FFFFFF | #102016 | Text/icons on felt fills |

### Player palette (`PlayerColors.palette`, muted print-ink colors, same order semantics)

1. Lacquer `#C0554A` 2. Pine `#2E6B52` 3. Brass `#A9843B` 4. Navy `#34557E`
5. Terracotta `#BC7434` 6. Plum `#6E4B72` 7. Slate teal `#3F7C86` 8. Rosewood `#8E4A5B`
Each needs a dark-mode variant lightened ~15% (define pairs, don't compute at runtime with opacity).
Keep `color(for:)` API. `lightColor(for:)` should return a 12% tint wash (used sparingly for row fills).

### Typography (`AppFonts` rewrite, keep member names, add new ones)

- `display` / `largeTitle`: Press Start 2P, scaled with Dynamic Type — reserve the pixel voice for
  brand moments, onboarding statements, game covers, winner moments, and the paywall headline.
- `title`, `headline`, `body`, `caption`: SF default design. Task UI, instructions, controls, and
  player names must prioritize native iOS legibility over decorative pixel styling.
- `tileTitle`: Press Start 2P for the three game-cover titles only.
- `columnHeader`: caption, semibold, `design: .default`, uppercase with tracking(0.8) —
  scorecard column-header style ("ROUND", "TOTAL", "PLAYER"). Provide a `View` helper
  `.columnHeaderStyle()` that applies uppercase + tracking + `inkMuted`.
- Scores: `scoreDisplay`/`scoreMedium`/`scoreSmall` use VT323 for the scoreboard voice, and every
  score render site must use `.monospacedDigit()` and
  `.contentTransition(.numericText(value:))` — the digital equivalent of a flip scoreboard.

### Shape & texture

- Corner radii: 10 (small), 14 (medium), 18 (large sheets).
- Cards: `paperCard` fill + 1pt `rule` stroke. Static content surfaces stay flat; only interactive
  surfaces receive a restrained 6pt shadow. NO material fills on content surfaces.
- Background: flat `paper` (kill both gradients). Optional: an ultra-subtle procedural paper-grain
  (Canvas dots at 1.5% ink opacity) behind Home only — skip if it costs any scroll performance.
- Ruled ledger: score tables use hairline `rule` dividers between rows, like a printed score pad.
- Liquid Glass (`.glassEffect`, iOS 26): ONLY on floating action bars, toolbar buttons, and chips
  overlaying scrolling content. Content cards stay opaque paper.

### Signature components (new file `ScoreKeeper/Views/Components/ClubhouseComponents.swift` + refactors)

1. `ScorecardSurface` — the paper card described above (replaces AppSurfaces material cards).
2. `LedgerRow` — player row: color pip (small filled circle w/ ring), name, spacer, score in
   monospaced heavy digits. Hairline rule below. Leader variant gets a small brass crown.
3. `StampBadge(text:)` — rubber-stamp look: uppercase tracked text, 1.5pt lacquer border,
   lacquer text at 85% opacity, rotated -4°, slight texture via opacity. Used for "FINAL" on
   completed games, "WINNER" on game over, "PRO" where relevant.
4. `BrassCrown` — small crown icon in `brass` (replaces yellow `crown.fill` tints).
5. Primary button style: felt fill, `onFelt` SF-semibold label, pressed = `feltDeep`,
   14pt radius. Secondary: paper fill + rule stroke + ink label. Destructive: lacquer.
   Rework `AppActionButton`/`PressableButtonStyle` to these.
6. `PipStepper` — the scoring +/- control: large 56pt-tall paper buttons with ink glyphs and a
   felt fill on press; the score between them in heavy monospaced digits.

## Screen-by-screen

Keep ALL existing behavior, navigation (`NavigationRouter`/`AppDestination`), SwiftData models,
engines, and accessibility identifiers exactly as they are. This is a reskin + layout tightening,
not a rearchitecture. Every screen must respect Dynamic Type, dark mode, reduce-motion, 44pt targets.

- **Home**: flat paper background. Header: "ScoreKeeper" in serif bold with a short ruled underline
  flourish. Active game (if any) as the hero scorecard with a live ledger preview and "Resume" felt
  button. "New Game" is the single primary felt button. Recent games render as stacked score slips
  (slightly rotated ±1° alternating, `ScorecardSurface`) with `StampBadge("FINAL")` and winner in
  brass. Stats/History entries as quiet ink text buttons with chevrons, ruled separators.
- **GamePicker**: game types as scorecard covers — tall cards with a serif game name, a thin double
  ruled border (outer 1pt + inner 0.5pt inset 4pt, like a printed certificate), a small ink
  line-art SF Symbol, and a one-line description in `inkMuted`. Selected/pressed = felt border.
- **PlayerSetup / PlayerRosterSheet**: roster as tally slips — each player a `LedgerRow`-style row
  with their ink color pip; add-player field styled as a blank ruled line (underline, not a
  rounded box). Saved-roster chips = paper chips with rule strokes.
- **GameConfig**: settings as a printed form — ruled rows, uppercase `columnHeader` section labels,
  felt toggles/steppers.
- **Scoring screens (Generic, Phase10, WhatsForDinner)**: the centerpiece. Opaque ledger table:
  uppercase column headers, hairline rules, monospaced heavy totals with `.numericText` transitions.
  Current player/round highlighted with a 12% player-color wash. Entry controls live in a bottom
  Liquid Glass bar (`PipStepper` + submit). Phase 10 phase tracker becomes a **peg-board strip**:
  10 small circles that fill in felt as phases complete (nod to the maple peg board). Round tracker
  = "ROUND 4" stamp-style label. Undo remains visible.
- **GameOverView**: the "FINAL" moment. Full scorecard rendered as one big paper sheet: serif
  "Final Score" title, ledger of all players, winner row highlighted brass with crown,
  `StampBadge("FINAL")` rotated across the top corner. Confetti stays but recolored to the muted
  player palette. Rematch = primary felt button. This screen must feel like tearing off a finished
  score sheet — worth extra polish.
- **GameDetailView / GameHistoryListView**: history as an archive of slips: date in `columnHeader`
  style, ledger rows, FINAL stamps. Detail = the same big scorecard as GameOver minus celebration.
- **HeadToHead / PlayerStats**: "almanac" styling: serif stat headlines, big monospaced numbers,
  ruled tables. No pastel chart colors — use player palette + felt.
- **ConfettiOverlay / AnimatedScoreChange**: recolor to new palette; keep reduce-motion paths.

## Onboarding (rebuild in the new system)

Keep: 3 pages, TabView paging, Skip button, completion via `hasCompletedOnboarding`, the
`-reset-onboarding` test hook, `onboarding_skip_button` / `onboarding_primary_button` /
`onboarding_page_title` accessibility identifiers, reduce-motion handling.

Change:
- Artwork panels become miniature paper scorecards using the real new components (LedgerRow,
  PipStepper, peg strip, FINAL stamp) so onboarding literally previews the product.
- Serif titles; tighter copy (max ~14 words per message). Suggested copy:
  1. **"Put the score pad down."** — "ScoreKeeper replaces the notes app, the napkin, and the
     'wait, who's winning?'" (artwork: live ledger with steppers)
  2. **"Set up in seconds."** — "Pick a game, add your crew once, reuse them every night."
     (artwork: game covers + roster slips)
  3. **"Every night becomes history."** — "Final scores, stats, and rematches — saved
     automatically." (artwork: stamped FINAL slip + stats line)
- Page dots become small ink pips (felt when active).
- Bottom bar: Liquid Glass with the felt primary button ("Continue" → "Start keeping score").
- IMPORTANT: onboarding must only promise features that actually exist in the app. Verify before
  writing copy (e.g. if there is no dice/timer tool, don't show one).

## Monetization — $0.99 one-time unlock, 25 free games

New files: `ScoreKeeper/Services/StoreManager.swift`, `ScoreKeeper/Views/Paywall/PaywallView.swift`,
`ScoreKeeper/ScoreKeeper.storekit`.

- Product: non-consumable, id `com.icequeen.scorekeeper.unlimited`, display name "PipCount Pro",
  $0.99. Create the `.storekit` config file with this product and register it in the project
  (document in `docs/monetization.md` how to select it in the scheme for local testing).
- `StoreManager` (@MainActor @Observable, StoreKit 2): loads product, `purchase()`, `restore()`,
  entitlement from `Transaction.currentEntitlements`, background `Transaction.updates` listener,
  `isUnlocked` published state persisted defensively to UserDefaults (`proUnlocked`) so offline
  launches stay unlocked.
- Free limit: **25 games**. Monotonic counter `gamesStartedCount` in UserDefaults, incremented
  whenever a `GameSession` is created (GameConfig start path + rematch path). Deleting games must
  NOT refund free slots. Remaining-games logic: `remainingFreeGames = max(0, 25 - count)`.
- Gate: when the user initiates a new game (or rematch) with `remainingFreeGames == 0` and not
  unlocked → present `PaywallView` as a sheet instead of creating the session. Never gate viewing
  history/stats or finishing an in-progress game. No paywall during onboarding or first launch.
- Soft signal: from the 8th game on, a quiet one-line note on Home: "X free games left" in
  `inkMuted` with a small brass "Unlock" link. Nothing louder than that.
- `PaywallView` design — a **clubhouse membership card**: paper sheet, double-ruled border, serif
  "ScoreKeeper Pro" title, brass StampBadge("LIFETIME"), 3 short benefit lines (Unlimited games /
  One-time purchase, no subscription / Every future feature included), price pulled from
  `product.displayPrice`, felt primary button "Unlock forever — $0.99", plain-text "Restore
  purchase" button, close (X) always available. A small footer line from the developer:
  "Made by one person who also just wanted game night to be simpler. — Prateek". Handles purchase
  states (loading/success/failure) gracefully; success = brief brass confetti + auto-dismiss +
  proceed into the game the user was trying to start.
- Test hooks: launch args `-unlock-pro` (forces unlocked), `-free-games-exhausted` (sets counter
  to 25), both only honored alongside the existing test-argument patterns.

## Review Ask — a personal note, not a system beg

New: `ScoreKeeper/Services/ReviewAskManager.swift` + small sheet `ReviewAskView`.

- Trigger: after a game FINISHES (GameOver appears), when: total completed games is exactly 2 or 5,
  never during the first app session, at most once per 120 days (store `lastReviewAskDate`), never
  again if the user tapped "Leave a rating" (store `didAcceptReviewAsk`), and never in the same
  session as a paywall presentation. All state in UserDefaults.
- Presentation: a compact sheet (`.presentationDetents([.medium])`) styled as a handwritten-feeling
  note on paper: small avatar-less header "A note from the developer" in `columnHeader` style,
  then serif body:
  > "Hi — I'm Prateek. I built ScoreKeeper because our game nights kept getting interrupted by
  > score-math in the Notes app. It's just me building this, and a quick rating genuinely decides
  > whether the app gets found. Either way, thanks for letting it keep score at your table."
  > — Prateek
- Buttons: felt primary "Sure, I'll rate it" → dismiss then `requestReview` (SwiftUI
  `@Environment(\.requestReview)`); quiet secondary "Maybe later". No guilt copy on the decline.
- Test hook: launch arg `-force-review-ask` presents it after the next game over.

## Engineering constraints

### Motion system

- Use `AppMotion` rather than one-off curves: press feedback is 100/140ms, fades 160ms, state changes 180ms, page changes 240ms, and theme changes 220ms.
- Frequent navigation and screen loading are immediate. Animate only the state that changed; do not attach broad implicit animation to an entire scoring screen.
- Press feedback scales to 0.97. Other entrances must start at 0.96 or above and use strong ease-out or a critically damped spring, never decorative bounce.
- Reduce Motion replaces movement and scale with short fades. Game-over confetti is the sole long-running celebration and is disabled when Reduce Motion is enabled.
- Motion must be interruptible: cancel delayed score-feedback tasks when a newer score arrives or the view disappears.

- iOS 26.0 deployment target; use iOS 26 APIs freely (`.glassEffect`, `.contentTransition`).
- Classic pbxproj (objectVersion 77, explicit PBXFileReference/PBXBuildFile): every new file MUST
  be registered in `ScoreKeeper.xcodeproj/project.pbxproj` (file ref + build file + group child +
  Sources phase). Verify with a clean `xcodebuild build`.
- Don't touch: SwiftData model files' stored properties, engines' scoring logic, NavigationRouter
  semantics, PrivacyInfo.xcprivacy (unless StoreKit requires additions), UI test helper patterns.
- Keep/extend UI tests: existing suite must still pass (`-in-memory-store` pattern). Add focused
  UI tests: paywall appears when exhausted + `-unlock-pro` bypasses; review ask appears with
  `-force-review-ask`; onboarding still completes.
- Simulator for tests: the isolated `ScoreKeeper App Store Review 26.4` device, bounded
  `-only-testing` slices (full-suite runs can stall — see Learnings.md).
- Every changed screen: verify in light + dark, Dynamic Type XL, reduce motion.
