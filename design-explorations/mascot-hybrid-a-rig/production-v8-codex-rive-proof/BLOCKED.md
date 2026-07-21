# ScoreKeeper mascot Rive proof — ready for promotion review

The approved mascot vectors and pivot-FK hierarchy remain isolated on the temporary artboard `__PROOF__ ScoreKeeper Mascot 20260716T085439Z` (`0-49117`) in the exact cloud file `https://editor.rive.app/file/untitled/2434585`. The protected canonical artboard `ScoreKeeper Cup Hybrid A - Production Rig v3` (`0-32354`) was not edited.

The temporary proof has one state machine, `ScoreKeeperMascot`, with `Entry -> Idle`, trigger-driven `Idle -> Celebrate`, and completion-driven `Celebrate -> Idle`. The single runtime trigger remains `celebrate`.

## Duration pass completed

- `idle` is a true 12.0-second looping timeline at 60 fps (`00:12:00`, 720 frames).
- Idle key timing is distributed across the full loop rather than followed by a frozen hold; the terminal pose matches the neutral loop endpoint.
- `celebrate` keeps its authored 1.6-second source timeline (`00:01:36`) and plays in the `Celebrate` state at `0.125x`, producing a 12.8-second effective one-shot without changing the authored deformation sequence.
- `Celebrate -> Idle` now uses `100%` Exit Time, so the transition follows animation completion and remains correct if source timing changes.
- Timed state-machine proof showed `Celebrate` still active at 10.5 seconds and `Idle` resumed by 14.0 seconds.

## Runtime contract

- Temporary artboard: `__PROOF__ ScoreKeeper Mascot 20260716T085439Z`
- State machine: `ScoreKeeperMascot`
- Default state: `Idle`
- Trigger: `celebrate`
- Timelines: `idle`, `celebrate`
- View Model: `ScoreKeeperMascotViewModel`

The stray `ViewModel1` has been removed and the safe View Model name is verified in the Data panel. The Problems panel now contains only the expected warning that the protected canonical artboard has no default state machine.

## Preserved artifacts

- Pre-edit backup: `../rive-backups/20260716/scorekeeper-mascot-pre-proof-20260716T084544Z.rev`
- Phase-one transaction: `phase1-report.json`
- Final read-only inventory: `final-readonly-inventory.json`
- Native pre-write capture: `evidence/native/pre-write-production-v3.jpeg`
- 72x60 visual proof strips: `evidence/contact-sheets/idle-dark-72x60-strip.png` and `evidence/contact-sheets/celebrate-dark-72x60-strip.png`
- Endpoint checks: `evidence/contact-sheets/idle-loop-terminal-to-zero.png` and `evidence/contact-sheets/celebrate-terminal-to-zero.png`
- Duration proof: `proof/animation-duration-contact-sheet.jpg`
- Transition proof: `proof/celebrate-exit-100pct.jpg`

## Visual QA completed

- Trophy/cup silhouette remains recognizable at 72x60.
- Face, twin handles, red top accessory/hair, stem, and base remain readable.
- Handle holes remain open and the compact width/height balance survives both timelines.
- Idle loops across 12 seconds and returns to its neutral endpoint.
- Celebrate preserves its authored silhouette and deformation sequence while playing for 12.8 seconds.
- Live state-machine preview verified the trigger, active Celebrate state beyond 10 seconds, completion-based exit, and automatic return to Idle.
- The safe View Model cleanup and single remaining warning were visually rechecked in the editor.

## Remaining promotion risk

The protected canonical artboard still has no default state machine. This is intentional: selecting the canonical runtime artboard/state machine is part of the later promotion step and was explicitly kept out of this proof pass. No SwiftUI or runtime integration was touched.

## Promotion definition

Promotion means replacing or adopting the approved temporary proof as the canonical/live mascot artboard and then choosing the file's runtime defaults. It does not mean publishing the app, uploading to App Store Connect, or changing SwiftUI. This pass stops before that canonical mutation.
