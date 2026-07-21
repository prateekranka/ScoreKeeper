# Fable motion-plan findings ledger

## Round 1: plan v1 to v2

- MPV1-001 — INCORPORATED. Plan v2 uses source/artboard pixels as the authoring
  unit, annotates display equivalents at 72x60, and requires a visible primary
  delta per behavior.
- MPV1-002 — INCORPORATED. Victory root apex is raised to about -22 source px
  (about 3.2 display px), with squash capped at 2.5% and visual acceptance.
- MPV1-003 — INCORPORATED. The live ownership audit found all 176 current hair
  performance keys target the `rig_hair` instance on main artboard 0-16469;
  component 0-17790 contains only defaults. The duplicated v3 instance will be
  re-queried before keys are changed, and 0-17790 will be re-audited unchanged.
- MPV1-004 — INCORPORATED. Playback modes are explicit and must be queried:
  idle/shimmy loop; hair/victory/curious one-shot.
- MPV1-005 — INCORPORATED. Both loops receive matched ease-to-rest/ease-from-rest
  boundary treatment and seam-spanning rendered proof.
- MPV1-006 — INCORPORATED. Only duplicated/auto-created v3 default timeline,
  machine, and empty-layer IDs may be deleted after an ownership allowlist is
  recorded. v2 object IDs remain protected.
- MPV1-007 — INCORPORATED. Extreme-frame QA explicitly samples transparent
  handle holes and inspects cup/base seams at 400% on light and dark.
- MPV1-008 — INCORPORATED. Curious tilt uses duplicated-value hold brackets so
  the attitude is flat and readable before recoil.
- MPV1-009 — INCORPORATED. A source search found no app-code consumers of the
  animation slugs, IDs, or durations; the duration decision is recorded in
  `duration-dependency-check.md`.
