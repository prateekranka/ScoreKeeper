# GPT-5.6 Sol High review 3

Verdict: `REVIEW_REVISE`

Route: fresh read-only child, `gpt-5.6-sol`, reasoning effort `high`, no inherited turns.

## Finding

- `RIVE-VIS-004` Blocker remained open in the supplied proof pack. The four live motion-gated bridges were structurally verified, but the rendered stress frames still showed the old y128/y170 diagonal seams in curious frame 28, shimmy frame 25, and victory frame 24.

## Root-cause adjudication

The live Rive keys were correct. The proof adapter called the v6 validator before reading `bridgeOpacityTracks`; that validator intentionally normalizes unknown metadata, so every bridge was rendered at opacity zero. The adapter now reads the raw, freshly queried model for utility opacity tracks, validates all four tracks per affected behavior, and fails if frame 1 is not one or the terminal frame is not zero. Fresh proofs were regenerated before review 4.

All other live, bind, motion, machine, protected-state, transparency, and 72x60 gates passed in this review.
