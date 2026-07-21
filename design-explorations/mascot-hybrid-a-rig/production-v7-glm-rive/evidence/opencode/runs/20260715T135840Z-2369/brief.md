# GLM pass 1: motion spec only

## Outcome

Author and validate the complete production v3 motion table. Do not connect to or
mutate Rive in this pass.

## Scope

- First update `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/opencode/opencode-status.md`.
- Write only:
  - `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/motion-spec-v3.mjs`
  - `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/spec-validation.json`
  - the status file above.
- Do not use `/tmp`, call `task`, spawn agents, browse, explore, touch git/config,
  read run logs, connect to Rive, or create any other file.

## Read only

1. `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/advisor/motion-plan-v2.md`
2. `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/preflight/live-v2-summary.json`
3. `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/motion-spec-v2.mjs`

## Required table at 60 fps

- `idle_breathe_blink`: 72f loop; seamless calm body; L blink f49-52, R f52-55;
  restrained hair; nonidentical eye timing.
- `hair_bounce`: 48f one-shot; hair apex -10..-12 source px/<=4 degrees at
  f14-16, reverse f24-27, settle f35-38, exact bind f48; no eye-scale track.
- `victory_pop`: 72f one-shot; anticipation; root apex about -22 source px at
  f24-29; stagger/lag; squash <=2.5%; controlled landing; bind f72.
- `curious_tilt`: 84f one-shot; about 7 degrees/~7 source px; gaze leads;
  counterbalance; flat hold f28-36; nonidentical eyes; bind f84.
- `celebrate_shimmy`: 96f loop; +/-7 source px and +/-3.5 degrees; asymmetric
  handles stagger 2-4f; hair lag 3-5f; varied halves; seamless endpoint.
- Use the four approved curve families in the motion plan; never one universal
  curve. Overshoot is keyed pose, not invalid cubic values.
- Multi-control pivot-FK only. Preserve control names/property keys established by
  v2. No opacity, root-only motion, raster/pose swaps, bones, weights, or IK.

## Validation

- Freeze the full canonical table and compute deterministic SHA-256.
- Exactly five slugs/settings above; every track has frame 0 and terminal; finite
  values; strictly increasing unique frames; no duplicate property tuple.
- One-shot terminal values equal bind within 1e-6. Loop endpoints close within
  1e-6. Curious hold brackets are equal. Eye timing is nonidentical. Hair bounce
  has no eye scale. Victory root apex meets the contract. Shimmy handle/hair
  staggering is machine-asserted.
- `spec-validation.json` records source inputs, spec hash, per-animation
  duration/loop/track/key counts, every assertion, and `passed: true|false`.
- Run `node --check` and the module's own validator. If any assertion fails,
  update status and stop with `passed:false`; do not soften the contract.
