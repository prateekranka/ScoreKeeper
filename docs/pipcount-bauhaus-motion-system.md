# PipCount Paper Bauhaus motion system

Status: **shipping direction**  
Decision date: 2026-08-23  
Prototype: `design-explorations/pipcount-motion-prototype-20260823/scoring-picker.html`

## Product rule

PipCount must feel faster and safer than a paper score pad. Bauhaus identity comes from the grid, rules, player geometry, color discipline, type, and direct controls. It does not come from moving wallpaper.

## Selected scoring model: Ledger Rail

Ship **Ledger Rail** as the common scoring structure.

- It shows all players, totals, and current-round values at once.
- Every control is next to the player it changes.
- It works for two to eight players without a separate selection step.
- It supports Scoreboard, Ten Phases, and What's for Dinner.
- It keeps rows stable while the user enters a round.

Do not ship Token Stage as the default. It adds a player-selection step to a shared-table task. Do not ship Score Wall as the default. It is visually strong but becomes dense and fragile above four players.

## Visual system

### Color

| Role | Token | Rule |
|---|---|---|
| Field | `paper` | Warm flat paper. No gradient. |
| Content | `paperCard` | Opaque score slips and forms. |
| Inset | `paperSunken` | Input wells and quiet grouped rows. |
| Text | `ink`, `inkMuted` | Primary and secondary information. |
| Interaction | `blue`, `blueDeep` | Primary action, selection, and focus. |
| Destructive | `red` | Delete, end, invalid, and negative score. |
| Winner | `yellow` / readable `brass` | Confirmed leader, winner, lifetime unlock. |
| Success | `green` | Brief saved or completed state only. |

Player identity uses color **and** geometry: circle, square, triangle, and diamond. Large red, yellow, and green fields are not normal UI surfaces.

This mapping supersedes the older split between felt-green primary controls and the current ultramarine implementation. **Ultramarine is the final primary interaction color.**

### Shape

- Small radius: 6pt.
- Medium radius: 10pt.
- Large score slip: 14pt.
- Use 1–1.5pt ink or rule strokes.
- Use a restrained offset print shadow on interactive paper only.
- Use hard rectangles and rules for score entry.
- Use Liquid Glass only for native floating chrome. Do not use glass for content cards.

### Type

- Display: heavy condensed system sans. Use it for PipCount, screen statements, game covers, and Game Over.
- Task text: system body and headline styles.
- Scores: system monospaced heavy digits with `monospacedDigit()`.
- Labels: uppercase condensed caption with tracking.
- Do not use a decorative display face for player names, instructions, or editable values.

## Motion gate

Every motion must have one purpose: feedback, state indication, spatial consistency, explanation, preventing a jarring change, or rare delight.

| Frequency | Rule |
|---|---|
| Each score tap | Immediate. Press feedback only. No row or card entrance. |
| Row selection and list edit | Local state change, at most 180ms. |
| Sheet or dialog | Native presentation. Do not add a second entrance. |
| First launch and onboarding | Up to 240ms explanation motion. |
| Game completion | One restrained completion sequence. |

### Tokens

| Token | Value | Use |
|---|---|---|
| `pressIn` | 100ms, strong ease-out | Touch-down scale to 0.97. |
| `pressOut` | 140ms, strong ease-out | Release to 1.0. |
| `fade` | 160ms ease-out | Visibility and reduced-motion replacement. |
| `state` | 180ms strong ease-out | Selection, expansion, row insertion. |
| `page` | 240ms strong ease-out | Onboarding and rare explanatory changes. |
| `theme` | 220ms strong ease-in-out | Color and material only. |
| `completion` | response 0.30–0.34, damping 1.0 | Final scorecard or winner mark. |

### Scoring

- Update the current-round number in the same input event.
- Keep every row in place.
- Do not animate live values with rolling numeric transitions.
- Use numeric text transition only when a round is committed and totals change.
- Use one light impact after a successful round save.
- Use warning feedback only after a successful undo.
- No floating score delta over readable totals.
- No delayed review, navigation, or paywall action owned by an unstructured task.

### Game completion

The scorecard is visible first. The winner mark follows.

1. Final scorecard: opacity plus scale 0.97 to 1.0, 240ms.
2. Winner mark: critically damped scale/fade after the card is stable.
3. Optional Pip celebration: one 1.5s Rive sequence that does not cover standings.
4. Reduce Motion: static mascot frame and short opacity change.

Do not run a three-second confetti layer over final scores.

## Screen application

### Home

- Reduce the geometric hero height so the next action and one useful state remain visible without a long poster scroll.
- Active game is the dominant score slip.
- Empty state uses one clear Start New Game action.
- Recent games are final score slips.
- Dashboard and tools stay secondary.
- The bottom dock must not cover the final row or tool controls.

### Game Picker

- Three vertical game covers with distinct geometry.
- Double-rule or hard ink border.
- One line of explanation.
- One-time entrance only. Selection itself is immediate.

### Player Setup and roster

- Ruled player rows.
- Geometric identity at the leading edge.
- Player name field uses a ruled line, not a floating generic card.
- Add and delete must preserve keyboard focus.
- Saved groups are paper chips or slips.

### Configuration

- Printed form layout.
- Win condition and target score use direct labels.
- Validation appears next to the field.
- Start is the single primary action.

### Scoring

- Ledger Rail is the stable shared shell.
- Columns: PLAYER, TOTAL, ROUND.
- Large direct minus, current value, plus.
- Quick values remain secondary.
- Undo and Submit Round stay in the bottom action shelf.
- Ten Phases adds a ten-peg strip.
- Dinner adds caller state without changing the ledger structure.

### Game Over

- Final scorecard and winner first.
- Rematch is primary. Home is secondary.
- Recap and trend follow the standings.
- Review ask must not compete with the result.

### History and stats

- Calm archive and almanac surfaces.
- No decorative chart animation.
- Expansion can use the local 180ms state transition.

### Paywall

- Paper lifetime membership card.
- One-time price comes from StoreKit.
- Close and restore are always available.
- Purchase success proceeds immediately. No timer-driven delay.

### Onboarding

- Three pages: score, setup, history.
- Show real controls and real product states.
- Use short explanatory motion.
- Skip is immediate.

## Asset boundary

- UI art can use the current theme and newly authored geometric components.
- Mascot art is from-scratch only.
- Do not reuse the legacy cup mascot, old pip-token art, or mascot-hybrid rigs.
- Approved candidate: `design-explorations/mascot-rive/pip-mascot.riv` with `pip-hero-transparent.png` as the reduced-motion and failure fallback.
- Add Rive only behind one adapter and only after the native UI is green.

## Verification bar

- Build succeeds on the iPhone 17 Pro Max iOS 26.5 simulator.
- Critical workflows pass focused UI tests.
- Behavior contracts pass at the cheapest deterministic layer.
- Every major screen is checked in light, dark, Dynamic Type XL, and Reduce Motion.
- Scoring is tested for two, four, eight, and maximum supported players.
- Visual feel is reviewed from live simulator captures, not only static HTML.
