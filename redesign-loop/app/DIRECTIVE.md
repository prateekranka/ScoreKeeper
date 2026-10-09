# Recovered Iteration Directive

The orchestrator did not emit the expected file. This work order is recovered from
the latest blind critic review and the current prototype state. Existing fixes listed
in CHANGELOG.md remain in force.

## Blockers

1. Repair live scoring updates in `app.js`. Keep the scoring DOM mounted for +/- and
   undo, update the visible score, leader marks, progress, and live announcement in
   place, and accept exactly one mutation per press. Acceptance: every accepted tap
   changes the visible score immediately without a full-screen rerender or Safari
   zoom.
2. Make final-round persistence atomic. Do not file a round before the user confirms
   the final result; upsert the current round exactly once when the result is stamped.
   Acceptance: cancelling the end dialog, editing the score, and confirming later
   produces one final round and no stale snapshot.

## Major

3. Make save failures truthful. All mutations must use the boolean result of
   `persist()`: success toasts only follow a successful write, while a failed write
   keeps the persistent retry banner visible. Clipboard support must report failure
   when both clipboard paths fail.
4. Keep direct score entry and improve the hold accelerator. The score remains a
   tappable numeric editor; long-press repeats from the current value, accelerates
   in bounded steps, and remains zero-safe. Teach the gesture on first scoring use.
5. Harden live-game navigation. Browser Back/edge-swipe must restore the scoring
   route and open the existing End game confirmation, never overwrite an active game
   through setup. Preserve immediate Rematch and the populated-home New game path.
6. Use one restrained navigation motion system. Frequent tabs use a short opacity-only
   transition; hierarchical routes use the View Transition old/new layers once, with
   no second page keyframe or double exposure. Modal, sheet, toast, press, and reduced
   motion behavior stay interruptible and under 300ms.
7. Finish the timer interaction honestly. Keep the deadline-based clock and mounted
   sheet, retain pointer capture, damping, velocity dismissal near `0.11`, and ensure
   unsupported completion cues expose an unavailable state instead of silent success.
8. Raise functional typography and semantics. Keep the Paper Bauhaus type roles,
   but bring labels/metadata to readable sizes, use stable table/list semantics, and
   preserve focus and safe-bottom action shelves across rerenders.

## Minor

9. Keep the color discipline exact. Ultramarine is the interaction accent, yellow is
   reserved for confirmed winners, and red/green are status-only. Use the existing
   neutral shape system for player identity and preserve dark yellow ink contrast.
10. Remove shadowed legacy renderers and stale motion code. Leave one renderer per
    screen, keep every `VALID_SCREENS` route and declared action wired, and replace
    placeholder navigation glyphs with a consistent CSS icon family without adding a
    dependency.

## Dropped From This Pass

- New mode-specific scoring entities were not expanded: the current strategy already
  records phases and dinner choices, and a framework rewrite would exceed this pass.
- Monetization behavior was not added: the current local entitlement copy is honest
  and intentionally has no purchase claim or premium gate.
- A new palette or glass/material treatment is explicitly rejected by brand-spec.md.
