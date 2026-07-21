# ScoreKeeper Cup Hybrid A — Production Rig v3 delivery

Status: **Complete**

Published at: 2026-07-15T16:02:06.439Z  
Authorized target: `https://editor.rive.app/file/untitled/2434585`

## Final live identities

- Artboard: `ScoreKeeper Cup Hybrid A - Production Rig v3` — `0-32354`
- State machine: `ScoreKeeper Cup Hybrid A - Behaviors v3` — `0-48286`
- `idle_breathe_blink` — `0-45292`, 60 fps, 72 frames, loop
- `hair_bounce` — `0-45614`, 60 fps, 48 frames, one-shot return
- `victory_pop` — `0-45148`, 60 fps, 72 frames, one-shot return
- `curious_tilt` — `0-45726`, 60 fps, 84 frames, one-shot return
- `celebrate_shimmy` — `0-45405`, 60 fps, 96 frames, loop
- Protected v2 artboard `0-16469` and hair component `0-17790` are preserved.
- Final file inventory remains seven artboards.

## Source and bind

- Authority: `production-v5-vector-master/canonical-dimensional-pixel.svg`
- Required and verified SHA-256: `52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75`
- Canvas: 512x416, transparent.
- Neutral parity: alpha-mask IoU 1, centroid drift 0 px, contour P95 0 px, differing pixels 0, maximum channel delta 0.

## Live structural result

- Pivot-FK with independent cup, stem, base, hair, left/right handle, left/right eye, mouth-left, mouth-center, and mouth-right controls.
- 409 authored cubic motion keyframes across four approved curve families.
- Four hidden, source-color-matched internal cup seam bridges with 48 hold-opacity utility keys. Base/idle and terminal opacity are zero; bridge opacity is one only during the three rotated behaviors.
- Post-publish live query: 12,817 objects, 457 total keyframes, 409 queried cubic interpolators, five timelines, and one mapping-only state-machine layer.
- State machine: five mapped animation states, Entry to Idle, no inputs, listeners, or conditional transitions. Interactive inputs are not claimed.

## QA result

- Claude Fable 5 High, configured strictly as advisor, returned `PLAN_APPROVED` for the concrete motion brief before execution.
- Fresh exact-file/live hierarchy, keyframe, interpolator, animation-setting, and state-machine queries passed after publication.
- Transparent, light, dark, actual 72x60, 100/200/400 percent stress, loop seam, v2-before/v3-after, and five mobile MP4 proof packs passed.
- Every rendered frame passed transparent-RGB and semantic handle-hole QA.
- Known defects tested absent: mask blanking, pedestal/eye coupling, cup/base seam opening, excessive hair travel, clipping, matte/order errors, root-only motion, hair/face collision, filled handle holes, resting shimmer, and rotated y128/y170 scanline gaps.
- Fresh GPT-5.6 Sol High reviewer verdict: `REVIEW_APPROVED`; `RIVE-VIS-004` explicitly closed.

## Exact final verification commands

```sh
node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/query-live-v3.mjs
node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/make-proof-model-v3.mjs
node design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/render-live-proofs.mjs --input design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/proof-model-v3.json --output design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/proofs
node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/apply-live-underlaps-to-proofs-v3.mjs
node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/assemble-proof-pack-v3.mjs
node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/publish-v3.mjs
RIVE_V3_TEMP_NAME='ScoreKeeper Cup Hybrid A - Production Rig v3' node design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/query-live-v3.mjs
```

## OpenCode route and scope evidence

- CLI: `/Users/prateekranka/.opencode/bin/opencode` 1.17.11
- Exact requested invocation route: `--model opencode-go/glm-5.2 --variant max --format json`
- The bounded evidence harness recorded command, JSON events, stderr, heartbeat/status, and before/after manifests under `evidence/opencode/runs/`.
- GLM did not emit an implementation artifact before timeout/length limits. Root used the documented recovery boundary and authored the delivered live transaction and proof corrections. This is disclosed as an executor-authorship caveat, not represented as a successful GLM implementation.
- The early stopped `/tmp` probe was removed before live writes. Final task-local artifacts remain within `production-v7-glm-rive/`; live writes remained on owned artboard `0-32354`; unrelated repository work and all protected live artboards were untouched.

## Evidence index

- `generated/publish-report.json`
- `generated/independent-live-query.json`
- `generated/live-keyframes-v3.json`
- `generated/live-hierarchy-v3.json`
- `generated/live-state-machine-v3.json`
- `generated/live-underlaps-v3.json`
- `generated/independent-qa-v3.json`
- `generated/proof-pack-v3/proof-report-v3.json`
- `generated/proof-pack-v3/actual-size/`
- `generated/proof-pack-v3/stress/`
- `generated/proof-pack-v3/mobile-mp4/`
- `generated/proof-pack-v3/before-after/five-animation-v2-before-v3-after.png`
- `evidence/reviews/sol-high-review-4.md`
- `evidence/advisor/motion-plan-v2.md`
- `evidence/opencode/scope-report.md`
- `evidence/live-editor/native-rive-v3-candidate-preview.png`

## Caveats

- The visual frame pack is a canonical-SVG semantic reconstruction driven by freshly queried live transforms and bridge opacity. It is not a native Rive runtime frame capture. Live existence, object ownership, timeline settings, keyframes, interpolators, and state mapping were independently queried from Rive; the native editor candidate asset was separately captured.
- Repository HEAD advanced externally during the run from the observed starting commit to `34985dd`; this task did not stage, commit, reset, stash, revert, or modify unrelated work.
