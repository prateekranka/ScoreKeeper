# ScoreKeeper Cup Hybrid A — production v5 vector master

This folder is a static approval package for the cleaned Hybrid A mascot. It is a compact, integer-aligned 512×416 SVG redraw: broad cup, square eyes, stepped smile, asymmetric red crown accent, top-right tab, true handle holes, and stepped stem/pedestal/base.

## Authority gate

Before rendering, `render-vector-master.mjs` verifies the locked v4 source hashes:

- `cleaned-canonical-bind.png` — `d93a520b5176a9e726e649edaa3b86ad8442d3469a2db807630925f7694bfefb`
- `cleaned-canonical.svg` — `013647cfbe1669e880c24814ce6f42cb70a6fc4ca3284466d1ead02d793fe724`

The gate passed for this build.

## Renderer and construction note

Primary renderer is native macOS `/usr/bin/sips` (`sips-316`, macOS `26.5.2`, Darwin arm64). The explicit `preflight-msvg-fixture.svg` is tested through both renderers: pinned ImageMagick `7.1.2-24` internal MSVG preserves transparent gaps but drops direct `linearGradient` paint (`directGradientPass: false`), while sips passes the gradient-plus-gap capability gate. The master applies six direct linear gradients (`goldBody`, `goldLight`, `goldShadow`, `edgeDark`, `ink`, `accent`) to closed orthogonal shapes. Every segmented cup surface uses the same canvas-space `goldBody` gradient through `gradientUnits="userSpaceOnUse"`, so the pixel silhouette remains segmented without restarting the shading. The former horizontal highlight/shadow bands have been removed. No raster is embedded; no masks, clip paths, filters, radial gradients, blend modes, curves, rigs, or animation data are used.

## Render

```sh
node render-vector-master.mjs
```

The script produces `transparent-512x416.png`, `light-composite.png`, `dark-composite.png`, `source-vs-redraw-comparison.png`, `proof-aspect-fit-72x59.png`, `72x60-proof.png`, `approval-board.png`, and machine-readable `qa.json`. It renders twice with sips and compares normalized raw RGBA hashes for deterministic output; ImageMagick remains the compositor/QA pixel reader.

## Measured result

The current run passes dimensions, corner/handle alpha-zero checks, transparent RGB matte check, compact element count, direct-gradient ordering, landmark presence, eroded seam scan, silhouette agreement, and deterministic raw RGBA repeat. A dedicated `cupGradientContinuity` regression check samples both sides of every former horizontal construction seam and fails if any RGB channel jumps by more than four levels.

The only intentional caveat is the pinned MSVG gradient limitation documented above; `qa.json` keeps the failed MSVG history and successful sips capability evidence explicit.
