# Narrow GLM Live Pass

## Outcome

Create one verified live v3 temporary in Rive file `2434585` by duplicating the
protected v2 artboard and improving its five animations. Export fresh structural
evidence. Do not render proofs and do not publish in this pass.

## First action and scope

- First update `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/opencode/opencode-status.md`.
- Local writes: only `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/`
  plus that status file. Never use `/tmp`, caches, home, or other paths.
- Do not call `task`, spawn agents, browse, explore the repo, edit app code, use
  git mutations, or bypass permissions.
- Use env `OPENCODE_RUN_ID`, `RIVE_V3_TEMP_NAME`, `RIVE_V3_MACHINE_NAME` and
  persist them in `generated/transaction.json`.
- Live writes: only the one fresh env-named artboard duplicated from `0-16469`.
  Never mutate v2 `0-16469`, hair component `0-17790`, machine `0-32339`, or any
  other existing artboard/component/object. Do not duplicate the hair component.

## Read only these inputs

1. `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/advisor/motion-plan-v2.md`
2. `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/preflight/live-v2-summary.json`
3. `design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/preflight/capture-live-v2.mjs`
4. `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/motion-spec-v2.mjs`
5. `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/build-live-rive-v2.mjs`
6. `design-explorations/mascot-hybrid-a-rig/production-v6-rive-rig/finalize-live-rive-v2.mjs`
7. Approved SVG only for hash verification:
   `design-explorations/mascot-hybrid-a-rig/production-v5-vector-master/canonical-dimensional-pixel.svg`

Do not read full `live-v2-audit.json`, `live-keyframes.json`, proof media, run
logs, or any other repository file. Required source SHA-256 is
`52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75`.

## Required authored files before live write

1. `generated/motion-spec-v3.mjs`: complete frozen five-animation table,
   per-beat cubic curves, validations, and deterministic hash.
2. `generated/build-live-rive-v3.mjs`: direct MCP HTTP transaction using the
   proven wrapper pattern; explicit IDs only; exact-focus query before/after
   every mutation; protected-state canonical hashes before/after.

Run local syntax/spec validation. If either script is incomplete or invalid,
record the blocker and stop before duplication.

## Motion contract at 60 fps

- `idle_breathe_blink`: 72f loop; calm seamless body; L blink f49-52, R f52-55;
  restrained hair; nonidentical eye timing.
- `hair_bounce`: 48f one-shot; hair apex -10..-12 source px and <=4 degrees at
  f14-16, reverse f24-27, settle f35-38, exact bind f48; no eye-scale clone.
- `victory_pop`: 72f one-shot; anticipation; root apex about -22 source px at
  f24-29; stagger/lag; squash <=2.5%; controlled landing and exact bind f72.
- `curious_tilt`: 84f one-shot; about 7 degrees/~7 source px; gaze leads;
  counterbalance; flat hold f28-36; nonidentical eyes; exact bind f84.
- `celebrate_shimmy`: 96f loop; +/-7 source px and +/-3.5 degrees; asymmetric
  handles stagger 2-4f; hair lag 3-5f; varied halves; seamless endpoint.
- Four approved curve families from `motion-plan-v2.md`; no universal easing.
- Every track has frame 0 and terminal, finite values, no duplicate tuples.
  One-shot terminals return to bind within 1e-6; loops close within 1e-6.
- Multi-control pivot-FK only. No opacity animation, root-only motion, raster,
  pose swap, full-character duplicate inside the temp, or bones/weights/IK claim.

## Live transaction gates

1. Verify MCP tools and exact six original artboards; v2 active; no temp/final
   collision. Verify source hash. Save pre-write transaction phase.
2. Freeze/hash spec before first animation write.
3. Call `duplicate_objects` once with only `0-16469`.
4. Immediately require exactly seven artboards, exactly one new sibling Artboard,
   new descendants disjoint from protected IDs; rename only new artboard to the
   env temp name. Ambiguity: undo that one call if safe, requery, record, stop.
5. Query neutral parity before keys: identical visible hierarchy/path/gradient/
   palette/order projection and bind values. Do not add underlaps in this pass.
6. Animate only temp descendants, including the duplicated main-artboard hair
   instance. Preserve all visible art and handle-hole transparency.
7. Temp ends with exactly five named timelines, no `Timeline 1`, settings above,
   and exactly one env-named mapping-only machine with one populated layer, five
   states/mappings, Entry-to-Idle, no inputs/conditions/listeners.
8. Re-query every setting/key/target/state. Protected canonical hashes must match.

## Required exports

- `generated/transaction.json`
- `generated/live-build-summary.json`
- `generated/live-keyframes-v3.json`
- `generated/live-hierarchy-v3.json`
- `generated/live-state-machine-v3.json`
- `generated/protected-before.json` and `generated/protected-after.json`
- `generated/builder-local-qa.json`
- `generated/implementation-report.md`

Record exact live artboard/machine/animation IDs, spec hash, source hash, commands,
checks, and caveats. Keep final publish/rename false. On any mismatch, update
status, preserve evidence/temp, and stop instead of guessing.
