# ScoreKeeper "Paper Bauhaus" Brand Spec

Source: `paper-bauhaus-ds-light.png` and `paper-bauhaus-ds-dark.png`, pixel-sampled
for `790e137e…` on 2026-08-08. OKLCH derived from sampled hex.

A warm printed-paper field carrying a hard-edged Bauhaus ink grid: ultramarine is the
single accent, Bauhaus yellow flags the winner, red and green are status-only. The app
should read like a printed score pad on a studio table — not a glassy fintech shell.

## Core tokens — light

```css
:root[data-theme="light"] {
  --bg:      oklch(95.2% 0.016 106.7); /* paper field   #f0f0e4 */
  --surface: oklch(97.6% 0.010 67.7);  /* cream slips   #fcf6f0 */
  --fg:      oklch(20.3% 0.010 107.2); /* ink           #171712 */
  --muted:   oklch(56.8% 0.019 84.6);  /* soft grey     #7c766a */
  --border:  oklch(90.2% 0.017 84.6);  /* hairline rule #e4ded2 */
  --accent:  oklch(39.2% 0.189 262.5); /* ultramarine   #0036a8 */
  --accent-press: oklch(31.9% 0.140 261.3);             /* #002a78 */
  --yellow:  oklch(81.7% 0.167 79.1);  /* Bauhaus yellow #fcb412 */
  --red:     oklch(57.3% 0.224 27.4);  /* status red    #de181e */
  --green:   oklch(55.4% 0.149 151.1); /* status green  #008a42 */
  --sky:     oklch(89.1% 0.025 236.9); /* tint          #ccdeea */
}
```

## Core tokens — dark

```css
:root[data-theme="dark"] {
  --bg:      oklch(18.5% 0.012 285.2); /* near-black paper #121218 */
  --surface: oklch(23.7% 0.015 256.8); /* coal slips       #1a1f26 */
  --fg:      oklch(95.2% 0.016 106.7); /* warm white ink   #f0f0e4 */
  --muted:   oklch(70.9% 0.017 106.8); /*                   #a2a296 */
  --border:  oklch(30.7% 0.017 255.6); /*                   #2a3038 */
  --accent:  oklch(60.8% 0.165 261.8); /* ultramarine       #487ee4 */
  --accent-press: oklch(52% 0.17 262);                   /* #3262c8 */
  --yellow:  oklch(87.7% 0.156 91.5);  /*                   #fcd248 */
  --red:     oklch(68.5% 0.197 21.9);  /*                   #fc5a60 */
  --green:   oklch(75.0% 0.171 153.1); /*                   #3ccc78 */
  --sky:     oklch(42% 0.09 262);      /* tint              #1d2f52 */
}
```

## Typography

- Display (scoreboard brand moments, screen titles, FINAL): `Futura`, `Century Gothic`,
  `Avant Garde`, `Trebuchet MS`, geometric sans — hard, confident, Bauhaus.
- Body (labels, controls, player names): `Inter`, `-apple-system`, `SF Pro Text`,
  `Segoe UI`, system-ui sans.
- Mono / numerics (scores, round numbers, totals): `ui-monospace`, `SF Mono`,
  `JetBrains Mono`, `Menlo` — always `tabular-nums`, `.monospacedDigit()` equivalent.

## Layout posture

- Flat `--bg` paper field; slips/cards use `--surface` with a 1px `--border` rule.
  No material fills, no gradient washes, no floating glassy cards.
- Scores and totals are tabular mono, trailing-aligned, in a ruled ledger.
- Ruled hairlines (`--border`) divide rows like a printed score pad.
- Corner radii minimal: 0–10px. Primary CTA is a hard-cornered or slightly rounded
  ultramarine block with crisp pressed state.
- Accent budget: ultramarine is the one accent. Bauhaus yellow flags the winner only;
  red/green are status annotations. Never a full-screen background, never a gradient.

## Signature components

- `ScorecardSurface` — cream paper slip, hairline rule, hard corner.
- `LedgerRow` — color pip + name + trailing tabular score on a hairline rule.
- `StampBadge` — rotated ink stamp (WINNER / FINAL / ROUND N), thin border, yellow or
  ultramarine ink.
- `PipStepper` — large hard-corner +/- block with a heavy tabular score between.
- `GameCover` — picker tile with a double-ruled border (outer 1px + inner hairline).