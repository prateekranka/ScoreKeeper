# ScoreKeeper Redesign Exploration

Static HTML exploration artifacts for three complete ScoreKeeper redesign directions, framed for iPhone 16 Pro on iOS 26+.

These files are exploratory only. They do not change SwiftUI source, SwiftData models, app routing, or OpenAI API behavior.

## Product Context Used

- Native iOS scorekeeping app built with SwiftUI and SwiftData.
- Core job: help small groups track casual games quickly, confidently, and without spreadsheet friction.
- Current game types: Scoreboard, What's for Dinner, and Phase 10.
- Core flows: choose game type, configure players, enter round-by-round scores, see standings/live totals, complete game, view history/details, and view player stats/head-to-head.
- Register: product UI.
- Target surface: iPhone 16 Pro on iOS 26+, logical viewport 402 x 874 CSS pixels, DPR 3.
- Design priorities: task clarity, fast score entry, reliable hierarchy, readable standings, accessible controls, and useful empty/error/loading states.
- iOS 26+ posture: use Liquid Glass-like treatment only for app chrome and interactive controls; keep score content opaque and high contrast.

The `impeccable` context script reported `NO_PRODUCT_MD`. Per the delegation, these assumptions stand in for project-level product context, and this README stays inside the artifact folder rather than writing root `PRODUCT.md` or `DESIGN.md`.

## Files

- `index.html` - comparison entry point linking to all three systems.
- `styles.css` - shared static CSS, design tokens, responsive mockup layout, and component vocabulary.
- `club-table.html` - Club Table direction.
- `referee-console.html` - Referee Console direction.
- `playful-ledger.html` - Playful Ledger direction.

## Screen Coverage

Each design direction mocks the same representative screens:

1. Home / active games and recent history.
2. Game type picker + setup/player roster.
3. Live generic scoreboard scoring screen.
4. Phase 10 scoring/status screen.
5. Game over / summary + stats/history detail.

Each mock screen is framed as an iPhone 16 Pro viewport rather than a generic mobile or tablet surface. The desktop page layout is only a comparison board around those phone frames.

## Design Systems

### Club Table

Positioning: tactile, social, and restrained for game night without sliding into parchment or nostalgia props.

- Physical scene: a shared phone on a crowded table in a dim living room.
- Color strategy: deep green environmental shell, light score sheets, copper warmth, and green success states.
- Typography: system UI family with tabular numeric scores.
- Spacing: relaxed 8/12/16/24 rhythm to support quick glances.
- Navigation model: home table, setup sheet, score sheet with sticky submit action.
- Component vocabulary: table mats, player placards, compact steppers, tally rows, plain history lists.
- iOS 26+ fit: status chrome and tappable actions take the glass treatment; table/score content remains solid for legibility.
- Motion: 150-200 ms pressed states and numeric score flips; reduced motion falls back to instant state changes.
- Fit: best when ScoreKeeper should feel warm and social but still product-focused.

### Referee Console

Positioning: dense, official, and table-first for a scorer who needs to see every number and command at once.

- Physical scene: a scorer at a side table under overhead light, checking totals while others play.
- Color strategy: graphite shell, slate panels, cyan active state, amber warnings, strong line contrast.
- Typography: system UI plus tabular/monospace score values.
- Spacing: compact 4/8/12/16 rhythm for high information density.
- Navigation model: top status bar, tabs, command rail, detail pane.
- Component vocabulary: command bars, editable score grids, audit tables, status badges.
- iOS 26+ fit: glass appears on command controls and status chrome while dense data grids stay opaque and measurable.
- Motion: direct row and command state changes around 150 ms; no decorative transitions.
- Fit: best when ScoreKeeper should feel like a confident score-official product.

### Playful Ledger

Positioning: colorful and state-rich for families and friends, with player identity doing real work in the score sheet.

- Physical scene: a shared phone passed around a couch or kitchen table.
- Color strategy: light neutral base with coral action, blue totals, green success, violet support accents, and player identity colors.
- Typography: system UI family, larger touch targets, tabular numeric scores.
- Spacing: forgiving 8/12/16/24 rhythm with stable score-control widths.
- Navigation model: activity home, friendly setup steps, player-led score rows.
- Component vocabulary: ledger strips, player chips, phase trails, large steppers, activity history.
- iOS 26+ fit: glass treatment reinforces touchable controls, while color-coded player ledgers stay readable under Dynamic Type.
- Motion: quick confirmation and button compression; reduced motion keeps the state change without transition.
- Fit: best when ScoreKeeper should feel approachable for families and casual groups without losing clarity.

## States Included

- Active game resume.
- Recent completed games.
- Roster setup and duplicate/minimum-player validation states.
- Scoreboard win condition.
- Draft round scores and undo affordance.
- Phase 10 completion and pending phase states.
- Game complete summary, standings, score trend, and replay actions.

## Quality Notes

- Uses local, static HTML/CSS only. No external assets, network fonts, or build step.
- Uses OKLCH tokens and iOS-style 44pt minimum touch targets for interactive controls.
- Avoids decorative glassmorphism, gradient text, side-stripe accents, nested card stacks, and over-rounded card surfaces.
- Prioritizes iOS product UI conventions: safe-area-aware phone chrome, clear buttons, segmented controls, rows/tables, badges, inline errors, skeleton-ready layout structure, reduced-motion support, and reduced-transparency fallback.
- Ready as a visual source for a later Argent Lens redesign pass.
