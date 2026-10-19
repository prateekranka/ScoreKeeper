# Local recognition stress checks

The private web preview uses the digits-6 local recogniser on the Mac
The native SwiftUI worktrees are separate and remain unchanged

## Recognition changes

- Preserve every empty vertical column gap so nearby digits do not merge into one glyph
- Use substantial connected components to separate two digits whose vertical projections overlap under tilt
- Reject detached horizontal marks so a visible minus sign cannot disappear into a score
- Composite transparent PNG input against white and reject multi-frame PNGs
- Keep the reviewed model artifacts and existing confidence and margin thresholds
- Report the loaded implementation hash through the recogniser identity endpoint

Both digit CNNs must still agree across all applicable stroke-weight views
A finite set cannot prove error-free recognition on future handwriting

The PNG composition follows [Pillow's alpha-compositing API](https://pillow.readthedocs.io/en/stable/reference/Image.html#PIL.Image.alpha_composite)

## Data separation

The 1757-case development stress set contains scripted writing variants, invalid controls and MNIST regression images
The 65 contributed drawings remain outside training and threshold tuning
They are regression validation examples with anonymous writer IDs, not independently verified writers
The eight older screenshot examples remain an explicit regression gate

Two additional confidence approaches were measured and rejected
A per-view confidence floor rejected a previously readable handwritten 8
Additional rotation consensus rejected another contributed drawing
The selected version keeps the geometric and PNG fixes without those confidence changes

## Commands

Set PIPCOUNT_STRESS_EVIDENCE to the frozen fixture directory shown in the task results
Set PIPCOUNT_MNIST_MANIFEST to the earlier complete MNIST JSON fixture
All behavior and system checks use TesterArmy e2e

```sh
PIPCOUNT_STRESS_PHASE=final PIPCOUNT_STRESS_MEASURE=1 PIPCOUNT_STRESS_FULL=1 PIPCOUNT_STRESS_VALIDATE=1 npx --no-install e2e run tests/local-stress.e2e.ts --config recognition.e2e.config.ts --target local
npx --no-install e2e run tests/local-recogniser-api.e2e.ts tests/inline-scoring.e2e.ts tests/digit-recognition.e2e.ts --config recognition-preview.e2e.config.ts --target preview
```

The pointer-drawing suite also requires PIPCOUNT_DIGIT_EVIDENCE and PIPCOUNT_PREVIOUS_DIGIT_EVIDENCE
The preview config starts one isolated server on a dynamically allocated local port and stops it after the tests
Its handwriting database is separate from the real collection

Jev's aggregate engineering review is opt-in through PIPCOUNT_STRESS_ADVICE=1
The review sends benchmark counts and software-change descriptions only
It does not send images, per-drawing labels, writer IDs or game data

## Proof limits

The synthetic variants and MNIST results are regression checks
They do not establish accuracy for new writers or physical iPhone touch input
Closely spaced digits in this set remain physically separate
Touching digits and unusual handwriting still need wider validation
The existing inline score, explicit save, keyboard alternative and Undo remain available
