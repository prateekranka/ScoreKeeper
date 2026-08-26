# PipCount hero kinetic artwork — black-disc reference system

Date: 2026-08-26. Status: **implemented in SwiftUI, pending Mac compile check.**

## What changed

`KineticBauhausComposition.skyline(sparse:)` in
`ScoreKeeper/Views/Components/ClubhouseComponents.swift` was replaced. The old
flat-blocks + starbursts skyline is gone. The new hero follows the four
ChatGPT-generated references in `references/reference-{1..4}.png`.

## The system (matches the references)

Ivory paper ground (`ClubhouseTheme.paper`). One matte-black anchor disc,
slightly left of center. A −46° black launch beam with a thin ivory
split-stripe crosses the full canvas. Translucent planes drift behind: red
panel upper-right (+ faint red echo), deep-blue band lower-right (+ pale blue
echo), golden-yellow block bottom-right, small green rotated square mid-right.
A yellow orbital arc with a traveling node circles the disc; a heavier ink arc
hugs the disc's upper-left. A fan of hairline trajectories rises from the
lower-left, some dashed, some with pulsing endpoint dots. Sparse variants drop
the echo planes, green square, grid, and red satellite ring.

## Motion design (read from the reference sequence)

The 4 references read as one system caught at different motion moments:

| Element | Motion | Reduce-motion behavior |
|---|---|---|
| Anchor disc | Static anchor; ±0.6% breathe only | Fixed |
| Beam stripe | Shimmer offset along the beam | Static |
| Orbit node | Continuous orbit (~16°/s) + fading tail dot | Pinned at base angle |
| Planes | ±3 px slow drift on phase offsets | Static |
| Trajectory lines | ±5 px drift along their own axis | Static |
| Endpoint dots / grid dots | Opacity pulse 0.5–0.8 | Fixed 0.6–0.7 |
| Entrance | Staggered artElement entrance (guides → planes → fan → orbits → disc → beam → satellites), 0.9 s | Full composition visible |

All motion runs through the existing `TimelineView(.animation)` at 30 fps and
`wave(phase:amplitude:)`, which already zeroes out under
`accessibilityReduceMotion`. Entrance uses the existing `artElement` modifier.

## Scene mapping (unchanged)

`.home`/`.onboardingHistory` → skyline; `.homeEmpty` → skyline(sparse). All
other scenes keep their existing compositions. Home header, BauhausBlocksArtwork,
PipCountAssetArtwork(.hero), AppSurfaces empty/paywall, ScoringComponents all
render through this path automatically.

## Verification

- HTML replica with identical geometry/timing:
  `index.html` (this folder). Rendered headless via CDP and visually checked
  against the references — planes, partial orbit, beam split-stripe, fan, grid
  all land correctly; no overflow or misalignment.
- Swift change is static-reviewed only (builder patterns, tuple types, helper
  signatures). Compile + Simulator screenshot pending Mac link.
