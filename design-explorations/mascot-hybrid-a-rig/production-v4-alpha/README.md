# ScoreKeeper mascot v4-alpha — Victory Lift

This directory is a deterministic offline production package for a 3.0-second, 60 fps hero performance built from the approved Hybrid A canonical SVG. It does not import or modify live Rive.

## Render

```sh
cd /Users/prateekranka/Cowork/ScoreKeeper/design-explorations/mascot-hybrid-a-rig/production-v4-alpha
node render-v4-alpha.mjs
```

The renderer uses a PID/heartbeat lock, a private staging directory, post-raster alpha masks, and atomic publication of the frame/inspection/video outputs. It emits exactly 180 RGBA PNG frames (`frames/0000.png` … `frames/0179.png`), `cleaned-canonical.svg` plus its `cleaned-canonical-bind.png`, a ProRes 4444 alpha master, an opaque blue-proof H.264 preview, contact sheet, inspection crops, and `qa.json`.

For a fast visual gate before the full render:

```sh
node render-v4-alpha.mjs --keyframes-only
```

For a cleaned-bind-only alpha proof:

```sh
node render-v4-alpha.mjs --bind-only
```

## Contract and controls

The performance beats are anticipation, launch/turn, expressive apex, landing/overshoot, and settle. Semantic controls with authored tracks are `rig_root`, `cup`, `pedestal`, `handleL`, `handleR`, `hair_cap`, `hair_fringe`, `eyeL`, `eyeR`, `mouth`, and `shine`. Handles have independent staggered overlap; eyes blink twice with a deliberately offset right-eye timing; hair cap and fringe are separate follow-through components.

Canonical cleanup is restricted to the requested left handle-hole union (18, 152, 156), right handle-hole union (17, 89, 151), and high-confidence external fringe removals (41, 70, 99, 126, 142, 157). Shine entries 29, 98, and 139 remain unchanged. Structural shading 52, 58, 147, and 158 is retained. The moving hole masks are rasterized separately and alpha-multiplied after cup/handle transforms; alpha-zero RGB is normalized to zero.

The renderer enumerates two synthetic underlaps separately: cup-local hair underlap (`#EFB944`) from the six original hair contours and a bounded pedestal seam underlap (`#8C651F`, x205–305/y258–276). These are dynamic-only; frame 0 and frame 179 are rendered from the cleaned canonical bind, so endpoint diffs are exact zero.

`source_002 contour1` is the combined cup + outer-handle silhouette. It remains cup-owned, so the semantic handle controls animate the exact v2 handle contours while this coupled outer shell cannot deform independently.

## Output facts

`v4-alpha-hero-alpha-prores4444.mov` is encoded with `prores_ks`, profile 4, `yuva444p10le`, and `alpha_bits 16` (the decoder reports the platform's `yuva444p12le` representation). Alpha is decoded and compared against every PNG frame; `qa.json` records the maximum delta and any mismatches. `v4-alpha-hero-opaque-blue-preview.mp4` is explicitly composited over `#0057FF`, H.264 `yuv420p`, and has no audio.

`qa.json` records frame-set completeness, endpoint RGB/alpha AE, cleanup bind diff and AA tolerance, ownership accounting, all-frame moving-hole-mask leak checks, all-frame alpha-zero RGB and viewport checks, ProRes decoded alpha proof, ffprobe facts, sampled background composites (black, blue, magenta, warm checker), inspection scales (100%, 200%, 400%), renderer versions, and normalized frame hashes for deterministic reruns.
