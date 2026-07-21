# OpenCode / GLM scope report

## Requested route

- CLI: `/Users/prateekranka/.opencode/bin/opencode` 1.17.11
- Model: `opencode-go/glm-5.2`
- Variant: `max`
- Output: JSON events

## Outcome

The requested GLM seat was invoked repeatedly through the bounded evidence harness, but it did not produce an implementation artifact. Two material runs reached the wall timeout, one continuation was stopped with exit 130, and the final narrow spec-only run ended at exactly 32,000 output tokens with `reason: length` and no write tool call. Root therefore invoked the documented recovery boundary and authored the live transaction, query, and proof scripts directly.

One early GLM pass created `/tmp/verify-step1.mjs`, outside the permitted v7 directory. Root stopped the pass before any live Rive write, preserved the evidence, removed only that owned temporary, and materially narrowed the brief. No protected artboard was changed.

The harness reported unrelated icon/AppIcon/Learnings changes occurring during later runs. Manifest paths and the JSON event logs show those changes were not produced by GLM tool calls; they remain user-owned and untouched by this task.

## Scope verdict

- Local task artifacts: confined to `production-v7-glm-rive/` after the stopped early `/tmp` probe.
- Live task writes: confined to owned candidate artboard `0-32354` and its owned timelines/state machine.
- Protected live objects: exact zero-delta hash before and after.
- Unrelated repo files: not edited, reverted, staged, committed, or otherwise mutated by root or the successful live transaction.
- Executor authorship gate: **not satisfied**. GLM did not author the delivered scripts or live work; root recovery did. This is retained as a delivery caveat, not represented as a successful GLM implementation pass.

Evidence is preserved in each `evidence/opencode/runs/<run-id>/` directory, including command, JSON events, stderr, status, before/after manifests, and scope reports.
