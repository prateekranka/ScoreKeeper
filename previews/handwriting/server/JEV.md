# Jev in the PipCount web preview

This integration has two uses: engineering advice based on measured recognition results, and independent reading of score drawings

The native SwiftUI app and its Git worktrees are outside this change

## Connection

Open `/setup/jev` on the local preview or through a configured private reverse proxy

The page sends the key to the loopback server through the same preview origin
The server makes one text request to Jev for an engineering recommendation, then stores a valid key in macOS login Keychain
The key is not written to a file, browser storage, a URL or an application log
Keychain failure leaves the connection inactive and has no plaintext fallback
The password field clears when submitted
No real key is used by the automated tests

Server dependencies are pinned in `requirements.lock`
The official `typesafe-sdk` is pinned to 0.7.5 and the model to `jev-1.14.0`
The upstream URL is fixed to `https://api.typesafe.ai`
Automatic retries are disabled and each request has a 12 second timeout

## Engineering decisions

Connecting asks Jev to choose between evaluating an independent veto, evaluating a primary reader, collecting more writers or retaining the local pipeline
The request includes the measured local regression counts and the interface constraints
The response and usage are saved privately in `.runtime/jev/engineering.json`
The choice is shown on the connection page
Code continues to own score ranges, arithmetic, persistence, navigation and Undo
A recommendation does not activate cloud recognition

## Handwriting decisions

Jev receives only the drawing, the score range, the reading instructions and the answer choices
Player names, current totals, game history and expected answers are not sent with a drawing
The official SDK uploads the PNG with the experimental image header
The image is kept upright, resized within the documented limits and padded if necessary
There is no external drawing URL or image storage in this integration
An in-memory cache holds at most 128 decisions keyed by drawing hash and credential fingerprint

Activation requires a saved passing evaluation whose digest, credential, model, instructions, thresholds, verifier source, local recogniser source and both local models match the current configuration
Until then the preview uses local recognition and sends no game drawings to Jev
After activation, a locally accepted reading must also receive the same accepted value from Jev
Disagreement, uncertainty, invalid output and provider failure prevent saving that drawing
The drawing stays editable and keyboard entry remains available
There is no second confirmation page

The initial uncalibrated filters require at least 0.90 model confidence and 0.99 probability for the chosen score
These are concentration measures supplied by the model and are not probabilities that a reading is correct
They are provisional rejection filters to evaluate, not an accuracy guarantee

## Evaluation

`prepare_jev_evaluation.py` freezes a 157-image regression panel from the existing eight user examples, sixteen known local errors, a fixed random MNIST sample, synthetic two-digit pairs and invalid controls
The manifest is under the task's Jev evidence directory
These images are regression material and do not count as independent validation

After a key is connected, run the bounded panel with the isolated Python environment:

```sh
.runtime/digits-env/bin/python server/jev_evaluate.py \
  --manifest /absolute/path/to/evaluation-panel/manifest.json \
  --output /absolute/path/to/private-evaluation-results
```

The runner permits at most 220 distinct PNGs per invocation
It sends one image request per uncached drawing, without its expected label
It records local, Jev and combined readings, latency, API errors and usage
It saves progress after each image
Use `--engineering` only when a fresh engineering recommendation is needed

A manifest is a JSON array with `id`, `file`, `expected`, `split`, `independent`, `writer` and optional `userSample` fields
`file` resolves relative to the manifest, `expected` is 0–99 or null for invalid input, and duplicate image hashes are rejected
The independent holdout must be collected and labelled before examining Jev's results
Mark actual withheld handwriting as `split: "holdout"`, `independent: true`, and use a distinct anonymous writer identifier for each person

The activation gate requires all of the following:

- No wrong accepted scores on the complete evaluation panel
- At least 85 percent correct acceptance of valid scores overall and on the independent holdout
- At least 100 independent holdout drawings from at least three writers
- All eight supplied user examples accepted correctly
- At least five invalid-input controls, with Jev accepting none of them
- No provider errors
- At most five seconds at the 95th percentile for Jev response time

`--activate` writes the activation policy only if every gate passes
An unsuccessful activation attempt clears the policy
A finite passing evaluation still cannot establish error-free recognition

## Test boundaries

`jev_contract_preview.py` is an isolated system e2e fixture
It uses the real TypeSafe SDK and its request and response protocol with `httpx2.MockTransport`
Its answers are simulated and do not measure Jev's accuracy or advice quality
Its fake credential store never accesses macOS Keychain
It is never the deployed preview service
The deployed server exposes none of the `/api/test/` controls

`tests/jev.e2e.ts` covers connection, engineering request construction, CSRF, service failures, malformed replies, independent agreement and disagreement, save, advance, Undo, keyboard fallback and the evaluation gate
`tests/jev-setup-live.e2e.ts` checks the actual deployment while no key is connected
The existing digit and inline scoring suites remain in use

Official references:

- https://docs.typesafe.ai/sdk/python
- https://docs.typesafe.ai/images
- https://docs.typesafe.ai/confidence
- https://docs.typesafe.ai/models

## First live comparison

The connected Jev 1.14.0 reader was measured on 157 regression drawings on 18 October 2026
There were 152 valid scores and five invalid-input controls
Before acceptance filters, Jev's selected candidate was correct for 125 valid scores, wrong for 13 and unreadable for 14
With the original 0.90 confidence and 0.99 selected-probability filters, Jev accepted ten valid scores with no wrong accepted score on this set
Requiring agreement with the local reader accepted eight valid scores
The local reader read all eight supplied user drawings correctly
Jev selected the correct candidate on seven of those eight drawings, but none passed the strict filters
The 95th percentile response time was about 0.70 seconds
The set has no independent multi-writer holdout and does not qualify for activation
The results are regression evidence and are not an estimate of real-world accuracy

After receiving the measured results, Jev recommended collecting handwriting from more writers
The private connection page shows the measured outcome
Cloud score acceptance remains inactive

The live API returned two-decimal probability values whose total was 0.99
The adapter now accepts non-unit totals only when every value is on the two-decimal grid and a normalized distribution can exist within all rounding intervals
The original probabilities and confidence values are retained and the acceptance filters are unchanged
Invalid ranges, insufficient or excess probability mass and unrounded malformed totals are rejected
