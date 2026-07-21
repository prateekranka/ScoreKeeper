# PipCount — Bauhaus Exploration

A fresh design iteration of **PipCount** (a.k.a. ScoreKeeper, iOS 26+), built on the owner's
*Bauhaus* reference board (`pipcount bauhaus refs` + Pinterest `scorekeeper` board).

This folder is **exploratory only**. It does not alter SwiftUI files, SwiftData models,
routing, or StoreKit behavior. It follows the same static-HTML/CSS convention as the sibling
`scorekeeper-redesign` and `scorekeeper-redesign-v2` explorations.

## Direction

Pure Bauhaus / De Stijl primaries on white: **red, blue, yellow, black**, composed from the three
primary shapes — **circle, square, triangle**. A deliberate tonal pivot away from the current
"Clubhouse Scorecard" (warm paper / felt-green / brass) toward something more graphic, confident,
and contemporary.

**One sentence:** *A Bauhaus poster you can keep score with — primaries on white, geometric marks
instead of icons, opaque cards, structural black rules.*

### What that means concretely

- **Icons are geometric marks, not SF Symbols.** Timer = circle + triangular hand. Dice = square
  with primary pips. Undo = quarter-arc + triangle head. Every glyph is built from primaries so
  the icon voice is Bauhaus, not iOS.
- **Opaque cards, hard edges.** Scorecards, tiles, and slips have square corners and 2pt black
  borders — no rounded material cards, no `tint.opacity()` washes.
- **Liquid Glass is confined to iOS chrome** (status bar + the theme button). Content stays flat
  and high-contrast so the table can read it fast.
- **Monospaced heavy digits** for every score, preserving the app's `numericText` flip-scoreboard feel.
- **Yellow = active/leader.** It is always used as a fill with black ink on top (never as text on white).

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| `paper` | `#FFFFFF` | App ground |
| `paper-2` | `#F4F4F2` | Sunken wells, grouped rows |
| `ink` | `#0A0A0A` | Primary text + structural borders |
| `ink-2` | `#6B6B6B` | Muted/secondary text |
| `red` | `#E63946` | Destructive, negative delta, FINAL stamp |
| `blue` | `#1E5BC6` | Primary CTA fill (New Game, Resume) |
| `yellow` | `#F5D020` | Active round, leader highlight (black ink on top) |

Player palette stays primary-adjacent (`red`, `blue`, `amber`, `teal`, `violet`, `coral`), keeping
the order semantics of the current `PlayerColors` so a SwiftUI port is mechanical.

## Files

- `index.html` — exploration hub + palette swatches (light + dark) + screen previews.
- `home.html` — the first screen, light mode.
- `home-dark.html` — the same screen, dark mode (`data-theme="dark"` on the device).
- `styles.css` — shared tokens, dark-mode overrides, iPhone 16 Pro frame, geometric components, motion.
- `shot.mjs` — headless-Chrome capture script for both modes (run with `node shot.mjs`).
- `screenshots/` — browser captures:
  - `home.png` / `home-dark.png` — at-rest viewport, both modes.
  - `home-full.png` / `home-dark-full.png` — full scrollable content, both modes.
  - `index.png` — the exploration hub page.

## Dark mode

Dark mode is a first-class variant, not an afterthought:

- **Ground** — warm near-black paper (`#0E0E10`), sunken wells one shade lighter.
- **Ink** — off-white (`#F2F0EA`) rather than pure white, gentler on the eyes.
- **Structure inverts** — the solid black rules that define Bauhaus layout become off-white on dark
  (high contrast preserved; never black-on-black).
- **Primaries brighten** — cobalt lifts to `#4D8FFF`, yellow to `#FFD93D`, red to `#FF5466` so they
  keep their luminous identity on dark ground.
- **Black-on-yellow is invariant** — text/icons on yellow fills stay `#0A0A0A` in both modes
  (`--on-yellow` is pinned, not derived from `--ink`).
- Implemented as `.device[data-theme="dark"]` token overrides (so light + dark can sit side-by-side
  on one page) **and** mirrored via `@media (prefers-color-scheme: dark)` so a standalone device
  honors the OS. This maps 1:1 to SwiftUI's `Color(light:dark:)` dynamic tokens.

## Screen 1 — Home

Establishes the full language in one surface:

1. **Wordmark** — PipCount next to the brand mark: red circle + blue square + yellow triangle.
2. **New Game CTA** — solid blue block, sharp corners, a yellow square anchored in the corner.
3. **Metric strip** — de Stijl grid (3 cells, thick black rules), each cell a primary shape + number.
4. **Quick tools** — 4 bordered tiles with hand-built geometric icons (Timer, Dice, Starter, Undo).
5. **Active game (hero scorecard)** — game mark + Resume button, `ROUND 03 / 10` peg strip,
   ledger with a yellow leader row + crown, hairline dividers.
6. **Recent games** — aligned score slips with rotated red `FINAL` rubber stamps.
7. **Stats** — Head-to-Head link + player chips.

Content is realistic PipCount data: an active Ten Phases game in round 3 of 10, Maya leading,
and three completed games with named winners.

## iOS 26+ posture

- Target frame: iPhone 16 Pro logical viewport, 402 × 874 CSS px.
- Safe-area-aware status bar + Dynamic Island mock chrome.
- 44pt minimum touch targets; primary actions in the thumb zone.
- Liquid Glass limited to status bar + theme button.
- Score tables and player data remain opaque.
- `prefers-reduced-motion` and `prefers-reduced-transparency` fallbacks included.

## Verification

Static HTML/CSS only; no build step. Intended local preview: serve this folder over HTTP, then open
`index.html`. A screenshot is captured to `screenshots/home.png` after implementation.

## Next screens (once the language is locked)

- **Live Scoring** — the centerpiece: opaque ledger, +/- steppers as primary-color blocks,
  phase peg-strip, bottom Liquid Glass action bar.
- **Game Picker** — the three games as Bauhaus poster compositions.
- **Game Over / Summary** — big FINAL scorecard with brass→yellow leader treatment.
- **Onboarding, Paywall, Review ask** — reskinned to the new system.

The existing SwiftUI tokens (`ClubhouseTheme` → would become a `BauhausTheme`, `AppFonts`,
`AppActionButton`, `LedgerRow`, `ScorecardSurface`) map 1:1 to the CSS tokens here, so a port
is a mechanical reskin that preserves all behavior, navigation, models, and accessibility IDs.
