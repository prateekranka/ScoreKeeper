# Changelog

## 2026-08-16

- Recovered the missing iteration work order from the latest blind critic review because the orchestrator did not emit `DIRECTIVE.md`.
- Kept score updates and hold-to-repeat feedback in place without replacing the scoring DOM, and blocked long-press text selection on score steppers.
- Recomputed persisted outcomes and canonicalized round snapshots so ties, corrupted records, and duplicate round numbers cannot invent wins or extra rounds.
- Preserved final-round undo when confirmation is cancelled, defined tied leader turn behavior, and kept dinner labels focused on choices.
- Reconciled timer deadlines on visibility changes, added interruptible toast exits, reduced-motion safeguards, accessible selected states, stronger semantic text contrast, and a landscape layout fallback.
- Removed unsupported Pro feature claims from the rendered paywall while keeping the local entitlement and restore path functional.
