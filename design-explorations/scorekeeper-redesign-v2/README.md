# ScoreKeeper Redesign Exploration V2

Second exploration pass for ScoreKeeper, targeting iPhone 16 Pro on iOS 26+.

This folder is exploratory only. It does not alter SwiftUI files, SwiftData models, routing, or OpenAI API behavior.

## What Changed From V1

The first pass was too neutral. This pass adds:

- Named mascots for each direction.
- Generated raster visual assets.
- CSS animations for score moments.
- Stronger texture and art direction.
- iPhone 16 Pro framing and iOS 26+ control posture.

## Files

- `index.html` - V2 comparison entry point.
- `styles.css` - shared iPhone frame, tokens, components, and motion.
- `pip-table.html` - tactile game-night direction.
- `ref9-arcade.html` - kinetic official-scoreboard direction.
- `badge-party.html` - bright patch/sticker direction.
- `assets/` - generated mascot/visual assets copied into the project.
- `screenshots/` - browser captures generated during verification.

## Design Systems

### Pip's Table

Positioning: a tactile table companion where a score-token mascot keeps game night warm, quick, and legible.

- Mascot: Pip, a lacquered score token.
- Visual assets: tabletop scene, cards, pencil, tally slips.
- Palette: deep green, ivory, lacquer red, restrained brass.
- Components: companion hero, tally rows, token actions, roster slips.
- Motion: gentle mascot bob, score pop, drifting table tokens.
- Fit: best for cozy game-night identity without losing fast score entry.

### Ref-9 Arcade

Positioning: a kinetic official-scoreboard system with command energy, animated totals, and a confident mascot.

- Mascot: Ref-9, a scoreboard official.
- Visual assets: arcade score booth, visor lights, dark console surfaces.
- Palette: graphite, electric cyan, coral, small lime highlights.
- Components: command rail, score ticker, audit rows, dense score grid.
- Motion: score pulses, command emphasis, phase glow.
- Fit: best when ScoreKeeper should feel like the official scoring console at the table.

### Badge Party

Positioning: a bright sticker-and-patch score ledger for families and friends, with celebratory motion.

- Mascot: Badge, an embroidered trophy patch.
- Visual assets: patch, stickers, crisp score sheets, confetti forms.
- Palette: white, navy, coral, cobalt, mint, sunflower accents.
- Components: patch hero, player ribbons, large steppers, phase stickers.
- Motion: confetti fall, score bounce, phase glow.
- Fit: best when ScoreKeeper should feel fun and social without becoming hard to read.

## Screen Coverage

Each design direction includes:

1. Home / active games and recent history.
2. Game type picker + setup/player roster.
3. Live generic scoreboard scoring screen.
4. Phase 10 scoring/status screen.
5. Game over / summary + stats/history detail.

## iOS 26+ Posture

- Target frame: iPhone 16 Pro logical viewport, 402 x 874 CSS px.
- Safe-area-aware status/Dynamic Island mock chrome.
- 44pt minimum touch targets for interactive controls.
- Primary actions in the bottom thumb zone where possible.
- Liquid Glass-like treatment is limited to app chrome, chips, and controls.
- Score tables and player data remain opaque for contrast and readability.
- Reduced-motion and reduced-transparency fallbacks are included in CSS.

## Generated Assets

Created with the built-in image generation tool and copied into `assets/`:

- `pip-token.png`
- `ref9.png`
- `badge-trophy.png`

The prompts requested no logos, watermarks, or readable text. Some source images contain score-like visual marks or scoreboard digits as non-copy visual texture.

## Verification Notes

- Static HTML/CSS only; no build step required.
- Intended local preview: serve this folder over HTTP, then open `index.html`.
- Browser screenshots were captured after implementation.
- Console should remain clean; `favicon` uses a data URL to avoid 404 noise.
