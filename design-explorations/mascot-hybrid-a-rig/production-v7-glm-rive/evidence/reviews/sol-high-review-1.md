# GPT-5.6 Sol High review 1

Verdict: `REVIEW_REVISE`

Route: fresh read-only child, `gpt-5.6-sol`, reasoning effort `high`, no inherited turns.

## Findings

- `RIVE-VIS-001` Blocker — the v7 candidate proof pack was not yet present. Required five MP4s, transparent/light/dark/72x60/stress contact views, loop seams, and v2-before/v3-after comparison.
- `RIVE-BIND-002` High — pre-cleanup structural parity was present, but post-cleanup rendered neutral parity against the immutable source was missing.
- `RIVE-EVID-003` High — the first normalized export serialized cubic curves as null. Independent live inspection nevertheless found 409/409 keyframes using the four expected live curve signatures; the correction was to re-export interpolator properties 63-66 and reject non-finite values.

## Structural gates independently confirmed

- Exact candidate artboard and source contract.
- Five timelines, durations, playback settings, controls, semantic beats, and no opacity tracks.
- One state-machine layer, five mapped animation states, Entry to Idle, and no inputs/listeners/conditions.
- Protected v2/component zero-delta hash.

The three stable findings above are the entire correction scope for review 2.
