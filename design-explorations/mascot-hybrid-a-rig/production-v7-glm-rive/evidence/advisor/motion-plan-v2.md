# ScoreKeeper Cup Production Rig v3 motion plan v2

## Immutable contract

- Target file ID: 2434585. Owned temporary name includes this run's timestamp.
- Canonical source SHA-256:
  `52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75`.
- Preserve the 512x416 neutral vector render exactly. No visible redraw,
  simplification, raster body, pose swap, full-character duplicate, or opacity
  pose group. Hidden fill-only underlaps are the only permitted art addition.
- Backend remains honest pivot-FK: live schemas expose no bones, weights,
  deformers, or constraints.
- v2 artboard 0-16469, hair component 0-17790, and state machine 0-32339 are
  immutable. All edits must resolve to re-queried IDs under the owned v3 temp.

## Units and display scale

- All authored translations use source/artboard pixels.
- 72x60 display conversion: display x = source x times 0.140625; display y =
  source y times 0.144231.
  One display pixel is about 7.1 source px horizontally or 6.9 vertically.
- Rotation is unchanged by scaling. Each behavior's primary read must produce
  at least about one display-pixel translation or two degrees rotation, except
  that idle may combine a smaller breath with a clearly visible blink.
- Scale deformation is capped per behavior and is rejected if it opens a seam,
  doubles a contour, fills a hole, or creates a resting shimmer.

## Transaction sequence

1. Re-query file/artboards and refuse temp/final-name collisions.
2. Duplicate only v2 artboard 0-16469 to a unique temporary. Record the returned
   and re-queried artboard/child IDs before any mutation.
3. Prove the duplicate's neutral render and source parity before animation.
4. Re-query `rig_hair`. Current evidence shows all hair keys live on the main
   artboard instance, so do not duplicate component 0-17790 unless the duplicate
   unexpectedly resolves a performance key inside component-owned objects.
5. Delete only v3-owned duplicated/auto-created `Timeline 1`, `State Machine 1`,
   and empty default layers. The deletion allowlist must contain no protected ID.
6. Rewrite the five v3 timelines on the owned temp. Explicitly set FPS, duration,
   and playback modes: idle loop; hair one-shot; victory one-shot; curious
   one-shot; shimmy loop.
7. Create one v3 mapping-only state machine with one populated layer and
   Entry-to-Idle. Do not claim interactive inputs.
8. Re-query every setting, keyframe, moving control, state mapping, and protected
   object count before proof generation.

## Easing vocabulary

- Gentle idle/loop arc: `[0.37, 0, 0.63, 1]`.
- Snappy anticipation: `[0.55, 0, 0.80, 0.20]`.
- Fast action: `[0.20, 0.80, 0.25, 1]`.
- Soft recovery: `[0.22, 0.75, 0.35, 1]`.
- Overshoot comes from explicit keyed poses, not out-of-range cubic values.
- Loops use matched ease-to-rest and ease-from-rest treatment at the boundary;
  render frames immediately around the seam to prove no hitch.

## Performances

### idle_breathe_blink — 72f loop

- Calm breath across f0/f18/f42/f72. Cup/stem/base travel stays within about
  3-4 source px (0.4-0.6 display px); hair/handles lag 3-4f and rotate no more
  than about 2 degrees, providing the secondary visible read.
- Left eye micro-blink f49-52; right eye f52-55. Neither blink is a simultaneous
  clone. End values close exactly and the seam frames must be visually smooth.

### hair_bounce — 48f one-shot

- Anticipation f0-7; hair-led apex f14-16 at about -10 to -12 source px
  (1.4-1.7 display px) and no more than 4 degrees; reverse overshoot f24-27;
  small settle f35-38; bind at f48.
- Body participation is restrained to about 2-3 source px (0.3-0.4 display px).
  No cloned eye squash. The hair may not touch the face.

### victory_pop — 72f one-shot

- Anticipation f0-14; launch/apex f24-29 with root about -22 source px
  (3.2 display px). Cup squash/stretch is capped at 2.5%.
- Hair and handles lag 3-5f; handles differ by 2-3f and may not be exact mirrors.
  Landing f42-49, micro-settle f58-64, bind f72.
- Acceptance requires visibly more airborne energy than v2 at 72x60, with
  cup/base seam and both handle holes clean at apex and landing.

### curious_tilt — 84f one-shot

- Anticipation f0-9; gaze leads the body. Tilt reaches about 7 degrees with
  roughly 7 source px (about one display px) lateral attitude by f24-28.
- Duplicate-value keys bracket a flat readable hold around f28-f36.
- Eyes respond with a non-identical offset; opposite handle and hair provide
  counterbalance. Recoil f47-52; gentle settle f64-76; bind f84.

### celebrate_shimmy — 96f loop

- Two related but non-cloned left/right phrases. Cup translates about +/-7
  source px (about one display px) and rotates about +/-3.5 degrees.
- Handles stagger 2-4f, hair lags 3-5f, and eyes are not identical tracks.
  The second phrase varies timing/amplitude while returning exactly to bind.
- Matched boundary treatment and f93-f96/f0-f3 proof must show no loop hitch.

## Acceptance evidence

- Fresh live hierarchy, animation settings, keyframes, moving controls, and
  state-machine export with hashes.
- Neutral/source parity and protected-v2/component zero-delta audit.
- Transparent, light, dark, actual 72x60, and 100/200/400% stress proofs.
- Per-animation MP4s and semantic/extreme contact sheets from the fresh queried
  v3 keyframes; no offline substitute for live authored motion.
- Explicit extreme-frame pass/fail: hole alpha remains zero, cup/base seam stays
  continuous, no clipping/matte/hair-face collision or subpixel rest shimmer.
- OpenCode before/after manifests, event logs, result, and zero scope violations.
