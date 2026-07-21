# Production v6 live-Rive proof renderer

This folder is a fail-closed proof pipeline. It accepts a normalized export of keyframes queried from the live Rive artboard and never contains an offline motion spec. The approved source art is fixed to `../production-v5-vector-master/canonical-dimensional-pixel.svg` (SHA-256 `52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75`).

## Commands

From this directory:

```sh
# Missing input is expected to fail with LIVE_KEYFRAMES_INVALID.
node validate-live-keyframes.mjs

# Validate a live export at an explicit path.
node validate-live-keyframes.mjs --input ./live-keyframes.json

# Render all five proofs. Output is created only after validation succeeds.
node render-live-proofs.mjs --input ./live-keyframes.json

# Fast sparse-frame renderer for toolchain checks (still emits MP4s and QA).
node render-live-proofs.mjs --input ./live-keyframes.json --smoke --output ./proofs-smoke
```

The default input is `./live-keyframes.json`; this file is intentionally absent until the live Rive query supplies it. The default output is `./proofs/`.

## Exact normalized input contract

The machine-readable contract is [`live-keyframes.schema.json`](./live-keyframes.schema.json). The runtime validator additionally verifies the source exists, resolves to the approved SVG path, and hashes to the approved digest.

```json
{
  "schema": "scorekeeper.rive-live-keyframes/v1",
  "source": {
    "path": "../production-v5-vector-master/canonical-dimensional-pixel.svg",
    "sha256": "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75"
  },
  "canvas": { "width": 512, "height": 416 },
  "fps": 30,
  "artboard": "ScoreKeeper Cup Hybrid A - Articulated Rig v1",
  "nodes": [
    {
      "name": "rig_root",
      "parent": null,
      "kind": "pivot",
      "transform": {
        "x": 0,
        "y": 0,
        "rotationDeg": 0,
        "scaleX": 1,
        "scaleY": 1,
        "opacity": 1,
        "pivot": { "x": 256, "y": 208 }
      }
    },
    {
      "name": "rig_body",
      "parent": "rig_root",
      "kind": "pivot",
      "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 }
    },
    {
      "name": "rig_hair",
      "parent": "rig_root",
      "kind": "pivot",
      "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 }
    },
    { "name": "asset_tab", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "tab", "sourceElementIndices": [0, 1], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_cup", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "cup", "sourceElementIndices": [2, 3, 20, 21, 22, 23, 24, 25, 29, 30, 31, 32], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_handle_l", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "handle_l", "sourceElementIndices": [4, 5, 6, 7, 8, 9, 10, 11], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_handle_r", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "handle_r", "sourceElementIndices": [12, 13, 14, 15, 16, 17, 18, 19], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_hair", "parent": "rig_hair", "kind": "asset", "source": "canonical-svg", "semanticPart": "hair", "sourceElementIndices": [26], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_badge", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "badge", "sourceElementIndices": [27, 28], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_eye_l", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "eye_l", "sourceElementIndices": [33], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_eye_r", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "eye_r", "sourceElementIndices": [34], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_mouth", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "mouth", "sourceElementIndices": [35, 36, 37], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_stem", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "stem", "sourceElementIndices": [38, 39, 40, 41], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 } },
    { "name": "asset_base", "parent": "rig_body", "kind": "asset", "source": "canonical-svg", "semanticPart": "base", "sourceElementIndices": [42, 43, 44, 45, 46, 47], "transform": { "x": 0, "y": 0, "rotationDeg": 0, "scaleX": 1, "scaleY": 1, "opacity": 1 }
    }
  ],
  "animations": {
    "idle_breathe_blink": {
      "label": "Idle breathe + blink",
      "durationFrames": 60,
      "loop": true,
      "tracks": {}
    },
    "hair_bounce": { "durationFrames": 36, "loop": false, "tracks": {} },
    "victory_pop": { "durationFrames": 48, "loop": false, "tracks": {} },
    "curious_tilt": { "durationFrames": 42, "loop": true, "tracks": {} },
    "celebrate_shimmy": { "durationFrames": 72, "loop": true, "tracks": {} }
  }
}
```

The example above is a shape-only illustration; it is not checked in as `live-keyframes.json` and must not be used as a substitute for the live export. Each required animation slug must be present: `idle_breathe_blink`, `hair_bounce`, `victory_pop`, `curious_tilt`, and `celebrate_shimmy`.

`nodes` is a connected parent hierarchy with 11 canonical semantic asset nodes. Transform nodes may be `pivot` or `nestedArtboard` (for the live `rig_hair` nested artboard). Each asset declares `source: "canonical-svg"` plus `semanticPart` and/or its exact `sourceElementIndices`; all 48 visible SVG elements must be covered exactly once. The renderer preserves source z-order and shared gradient defs while applying each asset's live world transform. Transforms are local to the parent and use `T(translation) · T(pivot) · R(rotation) · S(scale) · T(-pivot)`. Track properties `x`/`y` are absolute local translations; `dx`/`dy` are supported as mutually exclusive additive aliases for exports that report deltas.

The required source partition is: `tab=[0,1]`, `cup=[2,3,20…25,29…32]`, `handle_l=[4…11]`, `handle_r=[12…19]`, `hair=[26]`, `badge=[27,28]`, `eye_l=[33]`, `eye_r=[34]`, `mouth=[35…37]`, `stem=[38…41]`, and `base=[42…47]`.

Keyframes can be `[frame, value]` (linear) or objects with `frame`, `value`, and optional `interpolation`/`easing`: `linear`, `hold`, or `cubic`. A keyframe's mode controls the outgoing segment; the terminal keyframe's mode is inert. Cubic keys may declare `[x1,y1,x2,y2]` or `{x1,y1,x2,y2}` in `curve`; the renderer solves the x component and evaluates the y component deterministically. Values are never inferred from a slug.

## Outputs and QA

For each slug, the renderer writes:

- `proofs/<slug>/rgba-frames/frame-XXXX.png`: transparent 512×416 RGBA frames;
- `proofs/<slug>/<slug>-transparent-contact-sheet.png`: transparent contact sheet of the declared/default review frames;
- `proofs/<slug>/composites/frame-XXXX.png`: checker, light, and dark stacked composites;
- `proofs/<slug>.mp4`: H.264/yuv420p mobile-friendly portrait proof (checker, light, dark panels stacked vertically).
- `proofs/five-animation-transparent-contact-sheet.png`: aggregate transparent contact sheet for all five slugs.

`proofs/render-report.json` records the source hash, semantic partition, frame set, output paths, and per-frame alpha QA. Alpha QA fails on RGB in fully transparent pixels above 4 (white fringe) or any covered pixel in the canonical handle-hole rectangles after the live asset world transform is applied. A failed QA aborts the render before a report is written.

The renderer validates before touching the output directory. Missing, malformed, stale, or wrong-source input exits non-zero with `LIVE_KEYFRAMES_INVALID` and does not fabricate frames or videos.
