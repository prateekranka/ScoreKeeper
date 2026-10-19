# Review the current PipCount preview

## Scope

Review this directory for the current web prototype
The native app is in ScoreKeeper at the repository root and is a separate implementation
The web prototype covers round-score entry, local recognition, sample collection and optional Jev evaluation

## Main files

| File | Responsibility |
| --- | --- |
| src/main.tsx | Score dialog, player sequence, round entries and page routing |
| src/scoring.ts | Drafts, totals, replacement and Undo state |
| src/ScoreCanvas.tsx | Pointer strokes and PNG capture |
| src/useRecognition.ts | Recognition timing, cancellation and stale-response handling |
| src/ScoreToast.tsx | Saved-total feedback and Undo |
| src/HandwritingCollection.tsx | Prompted sample capture and writer drafts |
| src/JevSetup.tsx | Key entry and measured Jev status |
| server/recognise.py | Local digits-6 recognition |
| server/preview.py | Loopback HTTP server, origin checks and API routes |
| server/handwriting.py | Collection validation, SQLite transactions and export |
| server/jev.py | Keychain credentials, SDK calls and activation policy |
| server/jev_evaluate.py | Labelled image evaluation and activation checks |

## Behaviors to preserve

One person normally enters everyone's scores at the end of a round
Clicking a player opens one large writing dialog
The current player, total and round remain visible
The action row uses clear, approve and keyboard icons in a 20:60:20 ratio
The centre action is a blue rounded rectangle with a green tick
There is no second confirmation screen
Saving advances through players with a toast and persistent Undo
Uncertain input keeps the drawing and supports keyboard entry

## Design constraints

Use warm, fluid app copy with no sentence-ending full stops
Keep functional labels concise
Preserve the cream, red, blue, yellow and black geometric design
Preserve 44-pixel controls, contrast, keyboard access, dialog focus and Reduce Motion
Keep score-entry screens free of perpetual decorative motion
Manrope and third-party model licenses are included

## Review priorities

Check digit separation when bounding boxes overlap without strokes touching
Check invalid marks and uncertain results without fitting to a few examples
Check player draft isolation, rapid edits, stale responses and Undo replacement
Check collection retries, idempotency, concurrent saves and export provenance
Check that private sample files and API credentials cannot enter Git or logs
Check that optional Jev calls receive only their intended inputs
Measure correct acceptance and rejected valid input alongside wrong acceptance

## Evidence limits

The recogniser's learned weights and confidence thresholds were not changed in digits-6
The 1757-case development stress set includes synthetic writing and MNIST regression examples
The larger MNIST set shares underlying examples and is not independent writer validation
The private sample collection was kept out of model training and threshold tuning
The raw private drawings and proof recordings are not in the product branch
No native SwiftUI, physical iPhone or folding-device acceptance is established by these browser checks
