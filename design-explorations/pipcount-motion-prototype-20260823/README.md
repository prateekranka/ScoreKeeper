# PipCount scoring motion prototypes — 2026-08-23

Interactive scoring exploration based on Emil Kowalski's prototype, animation, and Apple fluid-interface principles.

Open `scoring-picker.html` in a browser.

- `1` — **Ledger Rail**: stable full-table ledger; direct player-to-control mapping.
- `2` — **Token Stage**: one-player focus; strongest single task focus, but adds player switching.
- `3` — **Score Wall**: maximum four-player glanceability; does not scale safely to larger groups.
- Arrow keys switch variants.
- `R` replays the entrance.

## Decision

**Ledger Rail ships.** It is the most useful at a table, supports larger groups, and maps directly to PipCount's common scoring shell.

## Motion rules tested

- Press feedback: 100ms in, 140ms out, scale 0.97.
- Score changes update immediately.
- No whole-screen animation on score input.
- One-time screen entrance: 240ms with 45ms group stagger.
- Submit uses one brief saved state.
- Reduce Motion removes transforms and keeps opacity feedback.

## Verification

Run:

```bash
node verify-prototype.mjs
```

The verifier launches headless Chromium, opens all three variants, changes a score, submits a round, and writes screenshots under `screenshots/`.
