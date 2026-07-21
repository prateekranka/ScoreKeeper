# OpenCode Implementation Brief

## Task

Create a production-quality live Rive v3 temporary by duplicating protected v2,
rewriting all five performances to the approved motion plan, and generating
fresh live-query evidence and proofs. Do not publish or rename to final.

## Status backchannel

- Update `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/opencode/opencode-status.md`
  at start, after preflight, after duplication, after neutral parity, before and
  after each live phase, before/after proof generation, and on completion/block.
- Updating that status file is the first action, before any other tool call.
- Each entry: UTC timestamp, current step, files touched, command running, live
  artboard ID/name, and blocker if any. Keep it concise; no private reasoning.

## Exact target and immutable source

- Rive URL/file ID: `https://editor.rive.app/file/untitled/2434585` / `2434585`.
- Root already opened the deep link and captured a live preflight.
- Approved source:
  `design-explorations/mascot-hybrid-a-rig/production-v5-vector-master/canonical-dimensional-pixel.svg`
- Required SHA-256:
  `52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75`.
- Canvas 512x416, 60fps, transparent, actual display about 72x60.
- Protected live v2: artboard `0-16469`, component `0-17790`, state machine
  `0-32339`. Never modify, rename, delete, or key any protected object.

## Owned names and local scope

- Use environment `OPENCODE_RUN_ID`, `RIVE_V3_TEMP_NAME`, and
  `RIVE_V3_MACHINE_NAME`. Persist their exact values in `transaction.json`.
- Local writes are allowed only under
  `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/`
  plus the single status file above. Preflight/advisor/opencode harness/brief files
  are read-only; never overwrite or rerun fixed-output v2 capture scripts.
- Never write helpers, probes, logs, or scratch data to `/tmp`, `/var/tmp`, home,
  caches, or any other path. Put every authored script and intermediate under
  `generated/`; shell heredocs are allowed only when their destination is there.
- Live writes are allowed only inside the uniquely named main temp and, only if
  required, the uniquely named conditional component temp.
- Do not edit application code, v5/v6 artifacts, scripts outside v7, config,
  dependencies, git state, deployments, or unrelated Rive objects.

## Read-only inputs

- `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/advisor/motion-plan-v2.md`
- `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/advisor/findings-ledger.md`
- `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/preflight/live-v2-audit.json`
- `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/preflight/live-v2-summary.json`
- `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/{artwork-scanlines.mjs,motion-spec-v2.mjs,build-live-rive-v2.mjs,finalize-live-rive-v2.mjs,render-live-proofs.mjs,publish-live-rive-v2.mjs,live-keyframes.json,live-build-summary.json}`
- `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/proofs/render-report.json`
- The five v6 proof MP4s and contact sheet for comparison only.
- Do not broadly explore the repository.
- Do not spawn OpenCode tasks, background agents, or subagents. This exact GLM
  session must do the bounded implementation itself.

## Hard art and rig constraints

- Preserve every visible path, contour, gradient, palette token, asymmetry,
  landmark, negative space, handle hole, draw order, and neutral bind pose.
- The one full-artboard transaction duplicate is required. Inside it, no redraw,
  raster body, nested pose image, additional full-character/pose duplicate,
  opacity-switched pose group, opacity animation, or root-only motion.
- Honest backend is pivot-FK. Do not claim bones, weights, IK, deformers,
  constraints, or interactive state-machine inputs.
- Hidden fill-only underlaps are permitted only if a fresh stress proof exposes a
  real articulation gap. Do not change visible art.

## Transaction and ownership sequence

1. Verify source hash, MCP tools/schema, exact six-artboard set, active v2 ID,
   protected names/IDs/counts, and absence of temp/final-name collisions.
2. Save a transaction JSON with run ID, phase, protected IDs/counts, and intended
   owned names. Stop before writes on mismatch.
3. Duplicate only artboard `0-16469` with `duplicate_objects`. Before any further
   mutation require exactly one new sibling Artboard, exactly seven total
   artboards, a descendant ID set disjoint from all protected IDs, then rename
   only the new ID to `RIVE_V3_TEMP_NAME`. On partial/ambiguous duplication,
   immediately undo that one call, re-query protected state, record, and stop.
4. Focus-lock by exact temp ID before each scoped phase; after two failures stop.
5. Freeze the complete v3 key/value/curve table and hash before first animation
   write. Do not invent controls or poses outside approved ranges; stop on an
   unspecified capability. Query neutral hierarchy and render parity before keys:
   mask IoU >=0.985, contour P95 <=1px, centroid drift <=0.5px, plus no visible
   delta, and identical visible path/gradient/palette/child-order projections.
6. Query every hair key residence. Animate only the new main-artboard instance.
   Never duplicate component `0-17790`; if ownership differs from preflight, stop.
7. Delete only re-queried v3-owned copies/auto-defaults (`Timeline 1`, `State
   Machine 1`, empty default layers) using a recorded owned-ID allowlist.
8. Keep the five duplicated named timelines or recreate them inside the temp;
   delete old keys only by re-queried temp-owned keyframe IDs.
9. Author the approved v2 motion plan exactly, with per-beat curves and dual-unit
   amplitudes from `motion-plan-v2.md`.
10. Explicit settings: idle 72f loop; hair 48f one-shot; victory 72f one-shot;
    curious 84f one-shot; shimmy 96f loop; all at 60fps.
11. Create exactly one mapping-only temp machine with one populated layer, five
    animation states, and Entry-to-Idle. No inputs/listeners/conditions.
12. Before and after every mutating call focus/query exact temp ID and pass explicit
    `animationId` plus exact key IDs/tuples; never use selection/visible/all
    fallbacks. Re-query every object/setting/keyframe/state mapping. Canonicalize
    protected v2/component/machine projections (IDs, names, parents, types, child
    order, properties, key targets/settings/refs; strip volatile selection/time)
    and require post-run SHA/diff zero, not count alone.

## Motion acceptance

- Every track has frame 0 and terminal keys; one-shot terminal values equal bind
  within 1e-6; values finite; no duplicate tuples. Loops close within 1e-6 and
  visually at idle f70-f72/f0-f2 and shimmy f93-f96/f0-f3.
- Use the approved curve families. Overshoot comes from poses, not invalid cubic
  values. Curious hold is flat with duplicate-value brackets.
- Assert beat windows: idle eye L f49-52/R f52-55; hair apex f14-16, reverse
  f24-27, settle f35-38, bind f48 with no eye-scale animation; victory root apex
  about -22px f24-29; curious flat f28-f36; shimmy handles stagger 2-4f and hair
  3-5f. Enforce visibly airborne victory and non-identical eye/phrase tracks.
- Multi-control motion, restrained hair, clean recovery/settle, no cloned halves,
  and no subpixel resting shimmer.

## Required v7 deliverables

- `generated/motion-spec-v3.mjs` with validation and a frozen hash.
- `generated/build-live-rive-v3.mjs` transactional builder/upgrader.
- `transaction.json`, `live-build-summary.json`, `live-keyframes-v3.json`, and
  live hierarchy/state-machine/settings/keyframe exports with SHA-256 hashes.
- Proof renderer/scripts inside v7 only; reuse v6 logic by reading/copying, never
  modifying v6.
- Five fresh MP4s, transparent semantic/extreme contact sheets, light `#F7F2E9`
  and dark `#191A1F` composites, individual 72x60 cells, 100/200/400% stress,
  loop seam strips, aggregate sheet, and v2 metric deltas. Loop MP4s use frames
  0..terminal-1; one-shots include terminal. Record ffprobe 60fps/frame counts.
  and v2-before/v3-after comparisons.
- Machine-readable QA with frame IDs/provenance/hashes and numeric checks: final
  scene hole-interior alpha=0 plus semantic cross-check, transparent RGB <=4,
  seam gap/double contour=0 at 400%, clipping/collision=0, endpoint/loop/control
  assertions, and rest-shimmer tolerance. Smoke/sparse outputs never count.
- `implementation-report.md` with exact commands, live IDs/names, checks, and
  caveats. Final name/publish must remain false.

## Verification and stop conditions

- Fresh live query is authoritative. Renderers must consume only the hashed fresh
  v3 live export; v6 SVG reconstructions are comparison-only and cannot prove
  actual nested-artboard/clipping/draw-order/antialias behavior.
- At every extreme on transparent/light/dark: handle-hole alpha stays zero;
  cup/base seam is continuous at 400%; no clipping, mask blanking, matte/fringe,
  doubled contour, filled hole, or hair/face collision.
- 72x60 before/after must visibly improve timing, asymmetry, and semantic read.
- Temp must contain exactly five named timelines, no `Timeline 1`, and exactly
  one named machine with one layer/five exact slug mappings/one Entry-to-Idle
  transition/no other transitions, inputs, listeners, or conditions.
- Do not claim independent QA; label builder checks `builder-local` for root to
  re-run separately.
- Do not publish, commit, push, reset, stash, clean, deploy, or bypass permissions.
- If exact target, focus, protected state, source hash, ownership, or bind parity
  fails, update status, preserve evidence/temp, and stop instead of guessing.
- If `duplicate_objects` fails, record the exact error and stop; do not silently
  rebuild v2 or create a new visible-art interpretation.
- Same error twice: stop retrying, preserve temp/evidence, and report the exact
  blocker for root research. Never auto-reset or broadly undo.
