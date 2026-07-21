# Narrow GLM follow-up: RIVE-VIS-004 only

## Finding

Fresh GPT-5.6 Sol High returned `REVIEW_REVISE` only because rotated frames expose anti-aliased seams between adjacent scanline rectangles. Evidence: `generated/proof-pack-v3/stress/curious_tilt-f0028-100pct.png`, plus 200/400% versions and shimmy/victory stress frames. All motion, structure, source, state-machine, curve, alpha, and scope gates otherwise pass.

## Objective

Author a safe, resume-aware script at `generated/add-underlaps-v3.mjs` that adds same-color, fill-only underlap rectangles to owned temp artboard `0-32354` only. Do not execute it. Root will inspect and execute.

## Allowed reads

- `generated/underlap-spec-v3.mjs`
- `generated/live-hierarchy-v3.json`
- `generated/query-live-v3.mjs` for MCP request conventions only
- `evidence/reviews/sol-high-review-2.md` if present

Do not explore other repo areas.

## Exact live contract

- Rive MCP: `http://127.0.0.1:9791/mcp`, exact file 2434585.
- Candidate: `0-32354`, exact temp name already recorded.
- Protected: v2 `0-16469`, hair component `0-17790`, machine `0-32339`.
- Underlap names must start `__V3_UNDERLAP__`; stop on an unexpected collision.
- Source rect underlaps are specified by `UNDERLAPS` and `CONTROL_PIVOTS`.
- Each underlap must inherit the matching semantic control transform and sit behind the scanline layer of the same source fill, but above lower source layers. Prefer parenting to the backmost zero-transform scanline Shape of the matching live `lNN` layer, then sending the owned child to back within that parent.
- Verify representative scanline parents have neutral x=0, y=0, rotation=0, scale=1, opacity=1 before creation.
- Filled paths are closed rectangles; use exact sampled color; expand only y by 1 source pixel above/below. Do not enlarge x, fill handle holes, or change visible contour.
- Create no timelines, keys, inputs, components, nested artboards, raster assets, or full-character duplicates.
- Re-query every created object and its parent. Record IDs, names, parent layer, geometry, and before/after object counts in `generated/live-underlaps-v3.json`.
- Verify exactly seven artboards and protected IDs/names before and after.
- Refuse to rename/publish/delete/undo anything.

## Local scope

May write only:
- `generated/add-underlaps-v3.mjs`
- `evidence/opencode/underlap-implementation-note.md`
- append one concise status line to `evidence/opencode/opencode-status.md`

No `/tmp`, no app code, no git mutation, no live execution.

## Handoff

Run `node --check` on the authored script. Report the chosen parent/layer mapping, idempotency behavior, expected created underlap count 38, and any schema uncertainty. Stop after the local script and note are complete.
