# PipCount Handwritten Score Recognition Revision Plan

> **For Hermes:** Use subagent-driven-development to execute this plan task-by-task. Do not proceed past a quality gate when its measured acceptance criteria fail.

**Goal:** Replace general-purpose Vision text OCR with a small, deterministic, digit-only recognition pipeline for scores `0...99`, while fixing the unsafe retry/manual-entry behavior exposed by the 2026-08-28 recording.

**Architecture:** Keep PencilKit for drawing and Core ML as the on-device inference runtime. Separate the flow into deterministic ink normalization, one/two-digit segmentation, a PipCount-trained `0...9 + reject` classifier, confidence/margin/reject gating, and an explicit UI state machine. Uncertain input must fall back to manual entry; it must never be converted to zero or another plausible-looking score.

**Tech Stack:** Swift 6, SwiftUI, PencilKit, Core ML, XCTest/XCUITest; offline model training with PyTorch and `coremltools`, with no third-party inference runtime in the shipping app.

---

## Why this plan changed

The previous plan specified `VNRecognizeTextRequest`. The production recording showed the following real failures:

| Written | Result |
|---:|---:|
| `3` | `0` twice |
| crossed `7` | `1` |
| `9` | `9` |
| `1` | `1` |
| `2` | unreadable, then manual entry defaulted to `0` |

A dedicated model spike was run before revising the plan. Evidence is stored outside the repository at:

`/home/bobbyranka/workspace/.hermes/spikes/001-mnist-score-recognition/`

### Measured spike results

The corpus contained 115 valid one/two-digit inputs plus blank and scribble controls. Deterministic segmentation produced the expected digit count for **115/115** valid inputs.

| Model | Synthetic singles | Synthetic doubles | Recording singles | Recording-derived doubles | Decision |
|---|---:|---:|---:|---:|---|
| Apple MNISTClassifier | 10/10 | 90/90 | 1/5 | 0/10 | Reject |
| EMNIST comparison model | 10/10 | 90/90 | 4/5 | 2/10 | Reject; accuracy and licensing unsuitable |
| Apple Updatable Drawing Classifier + 420 templates | varied/overfit | varied/overfit | at most 2/5 in variants preserving synthetic accuracy | inadequate | Reject |

Both Apple MNIST and the EMNIST comparison model falsely accepted the scribble as a digit. Multiple wrong predictions carried high model confidence, so a confidence threshold alone is not a sufficient safety mechanism.

**Decision:** do not ship an off-the-shelf digit model. Train a tiny PipCount-specific classifier from scratch using permissively usable public digit data plus real, writer-diverse PencilKit samples. Retain Core ML for native inference. The feature remains blocked until the acceptance gates below pass.

---

## Scope

### In scope

- Scores `0...99`, written as one or two digits.
- Finger and Apple Pencil input through the existing `PKCanvasView`.
- Deterministic left-to-right digit segmentation.
- Small Core ML digit classifier with an explicit `reject` class.
- Explicit confirmation before a recognized value is committed.
- Safe manual fallback with no prefilled value.
- Regression assets for the exact recording failures.
- Writer-disjoint validation and screenshot evidence.

### Out of scope

- Negative handwritten scores.
- Three- or four-digit handwriting.
- General text or letter recognition.
- Cloud OCR or network inference.
- On-device user-specific training in the first production revision.
- Tesseract, ONNX Runtime, or another inference engine in the app bundle.

---

## Files

| Action | Path |
|---|---|
| Create | `ScoreKeeper/Services/ScoreDigitSegmenter.swift` |
| Create | `ScoreKeeper/Services/ScoreDigitClassifier.swift` |
| Create | `ScoreKeeper/Resources/PipCountDigitClassifier.mlpackage` |
| Modify | `ScoreKeeper/Services/ScoreRecognizer.swift` |
| Modify | `ScoreKeeper/Views/Components/ScoreWritingCanvas.swift` |
| Modify | `ScoreKeeper/Views/Scoring/RoundEntryDeckView.swift` |
| Modify | `ScoreKeeper.xcodeproj/project.pbxproj` |
| Create | `ScoreKeeperTests/ScoreDigitSegmenterTests.swift` |
| Create | `ScoreKeeperTests/ScoreDigitClassifierTests.swift` |
| Modify | `ScoreKeeperTests/ScoreRecognitionFixtures.swift` |
| Modify | `ScoreKeeperTests/ScoreRecognizerFixtureTests.swift` |
| Modify | `ScoreKeeperUITests/ScoreRecognitionE2ETests.swift` |
| Create | `ScoreKeeperTests/Fixtures/ScoreRecognition/manifest.json` |
| Create | `ScoreKeeperTests/Fixtures/ScoreRecognition/recording-3.png` and the remaining approved fixture PNGs |
| Create | `Tools/ScoreDigitModel/README.md` |
| Create | `Tools/ScoreDigitModel/requirements.lock` |
| Create | `Tools/ScoreDigitModel/train.py` |
| Create | `Tools/ScoreDigitModel/evaluate.py` |
| Create | `Tools/ScoreDigitModel/export_coreml.py` |
| Create | `docs/score-recognition-validation.md` |

Do not commit raw recordings, names, device metadata, or unapproved user data. Only commit tightly cropped, normalized digit fixtures that contain no personal information.

---

## Quality gates

### Gate A — deterministic segmentation

Must pass before model work is integrated:

- Expected segment count for every valid spike input: **115/115**.
- Synthetic matrix: all singles `0...9` and all doubles `10...99` split correctly.
- Crossed `7`, detached-crossbar `4`, two-loop `8`, and loop-plus-stem `9` remain one digit.
- Narrow pairs such as `11` remain two digits.
- Touching or ambiguous digits return `.ambiguous`, not a guessed split.
- Blank input returns `.noInk`.
- More than two groups returns `.unsupported`.

### Gate B — recognition safety

The model may safely reject uncertain input. It may not return a wrong accepted score.

- Exact recording regression cases: **100% correct or safely rejected**.
- Fixed synthetic single/double matrix: **100% correct**.
- Writer-disjoint validation set: **zero wrong accepted values**.
- Accepted-value precision on the fixed validation corpus: **100%**.
- Valid-input coverage target: at least **95%**; lower-confidence cases may fall back to manual entry.
- Blank, scribble, malformed, and unsupported-negative corpus: **zero digit accepts**.
- `3 → 0`, crossed `7 → 1`, and `2 → 0/1` are explicit release blockers.
- Re-running the same input must produce identical segmentation and prediction.

A model that scores well on synthetic fixtures but fails the writer-disjoint corpus must be rejected, even if its aggregate benchmark accuracy is high.

### Gate C — interaction safety

- Every recognized value requires explicit **Use N** confirmation.
- Retry returns to an editable, cleared canvas; it never reruns unchanged pixels.
- Manual entry begins empty and **Use** remains disabled until a valid value is entered.
- No invalid or empty manual value is converted to zero.
- Only one action set is visible in each UI state.
- The original drawing or a thumbnail remains visible during confirmation.

### Gate D — release verification

- Focused unit suites pass on iPhone and iPad simulators.
- Handwriting E2E passes on both device classes.
- Full app unit/UI baseline has no new failures.
- Screenshot evidence contains every acceptance case, pass or fail.
- TestFlight upload occurs only after Gates A–C pass and the final source revision is verified.

---

## Task 1: Convert the spike evidence into permanent regression fixtures

**Objective:** Ensure the real failures remain reproducible before changing production recognition code.

**Files:**
- Modify: `ScoreKeeperTests/ScoreRecognitionFixtures.swift`
- Create: `ScoreKeeperTests/Fixtures/ScoreRecognition/manifest.json`
- Create: approved cropped PNGs under `ScoreKeeperTests/Fixtures/ScoreRecognition/`
- Modify: `ScoreKeeperTests/ScoreRecognizerFixtureTests.swift`

**Step 1: Add failing regression tests**

Add tests for:

- Recording-style `3` must never be accepted as `0`.
- Crossed `7` must never be accepted as `1`.
- Recording-style `2` must produce `2` or `.unreadable`, never another success.
- Recording-style `9` and `1` remain correct.
- Composed `12`, `21`, `37`, `73`, `29`, `92`, `19`, `91`, `72`, and `27` split into exactly two digits.
- Scribble must not return `.success`.

**Step 2: Run the focused suite and verify RED**

```bash
xcodebuild test \
  -project ScoreKeeper.xcodeproj \
  -scheme ScoreKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ScoreKeeperTests/ScoreRecognizerFixtureTests
```

Expected: the recording-derived assertions fail against the current Vision implementation.

**Step 3: Verify fixture provenance**

Document source, crop bounds, expected label, and SHA-256 in `manifest.json`. Verify each fixture contains only the handwritten ink and neutral background.

**Step 4: Commit**

```bash
git add ScoreKeeperTests/Fixtures/ScoreRecognition \
  ScoreKeeperTests/ScoreRecognitionFixtures.swift \
  ScoreKeeperTests/ScoreRecognizerFixtureTests.swift
git commit -m 'test(recognition): preserve real handwriting regressions'
```

---

## Task 2: Implement deterministic one/two-digit segmentation

**Objective:** Separate segmentation from classification and prove all valid scores are partitioned correctly.

**Files:**
- Create: `ScoreKeeper/Services/ScoreDigitSegmenter.swift`
- Create: `ScoreKeeperTests/ScoreDigitSegmenterTests.swift`
- Modify: `ScoreKeeperTests/ScoreRecognitionFixtures.swift`

**Proposed API:**

```swift
enum ScoreDigitSegmentation: Equatable {
    case noInk
    case digits([CGImage])
    case ambiguous
    case unsupported
}

struct ScoreDigitSegmenter {
    static func segment(_ image: CGImage) -> ScoreDigitSegmentation
}
```

**Algorithm:**

1. Convert to a binary ink mask using the same orientation and polarity as production capture.
2. Remove components below a documented noise-area threshold.
3. Crop to the union of meaningful ink.
4. Compute the horizontal ink projection.
5. Merge small internal gaps caused by disconnected strokes inside one digit.
6. Permit either one group or two clearly separated groups.
7. If more than two groups remain, or the only split is not sufficiently separated, return `.ambiguous`/`.unsupported`.
8. Normalize each resulting group independently for model input.

Do not special-case particular expected values in segmentation.

**TDD sequence:**

1. Single connected digit.
2. Two clearly separated digits.
3. Detached-crossbar `4` remains one digit.
4. Two-loop `8` remains one digit.
5. Crossed `7` remains one digit.
6. Narrow `11` remains two digits.
7. All values `10...99` produce two groups.
8. Blank, noise, touching digits, and more-than-two groups fail safely.

After each test, verify RED, add minimal implementation, verify GREEN, then run the entire segmenter suite.

**Gate:** Gate A must pass before Task 3 is allowed to land.

---

## Task 3: Build a real, writer-diverse training and validation corpus

**Objective:** Eliminate the synthetic-only blind spot demonstrated by the spike.

**Files:**
- Create: `Tools/ScoreDigitModel/README.md`
- Create: `Tools/ScoreDigitModel/dataset_manifest.schema.json`
- Create: `Tools/ScoreDigitModel/validate_dataset.py`
- Create: `docs/score-recognition-validation.md`

**Minimum corpus:**

- At least 12 writers.
- Every writer supplies each single digit `0...9` at least twice.
- Every writer supplies a balanced list of at least 12 double-digit scores, including `11`, `12`, `20`, `25`, `37`, `50`, `69`, `72`, `90`, and `99`.
- Include crossed and uncrossed `7`, open and closed `4`, looped and straight `9`, angular and curved `2`, and varied stroke thickness/position.
- Include blank taps, scribbles, partial digits, touching digits, and unsupported negatives as `reject` examples.

**Split rule:** Split by writer before augmentation. No sample or augmentation derived from a validation writer may enter training.

**Privacy:** Store raw samples outside Git. Commit only the manifest, hashes, approved regression crops, and aggregate metrics.

**Verification:** `validate_dataset.py` fails on label imbalance, duplicate hashes across splits, missing writer IDs, or leakage between train and validation.

---

## Task 4: Train and export a tiny PipCount digit classifier

**Objective:** Produce a reproducible, legally reviewable Core ML model that recognizes digits and rejects out-of-distribution ink.

**Files:**
- Create: `Tools/ScoreDigitModel/requirements.lock`
- Create: `Tools/ScoreDigitModel/train.py`
- Create: `Tools/ScoreDigitModel/evaluate.py`
- Create: `Tools/ScoreDigitModel/export_coreml.py`
- Create: `ScoreKeeper/Resources/PipCountDigitClassifier.mlpackage`

**Model constraints:**

- Classes: `0...9` plus `reject`.
- Small CNN; target shipping artifact at or below 1 MB unless evidence justifies more.
- Train from scratch. Do not reuse the comparison model's GPL/AGPL weights.
- Record dataset versions/licenses, random seeds, architecture, preprocessing, and artifact SHA-256.
- Use augmentations that match PencilKit: translation, small rotation, scale, width, and antialiasing—not arbitrary distortions.

**TDD/evaluation sequence:**

1. Add evaluator tests that fail when a known wrong accepted value appears.
2. Establish a baseline and record its failures.
3. Train the minimal classifier.
4. Evaluate against the untouched writer-disjoint set.
5. Calibrate acceptance using both top-class probability and top-two margin, with the explicit reject class.
6. Export to Core ML.
7. Compare Python and Core ML outputs on the same fixture hashes; labels must match exactly.
8. Record confusion matrix, accepted precision, coverage, and rejection metrics.

**Gate:** Gate B must pass. A model that merely improves the spike but still accepts one wrong score does not ship.

---

## Task 5: Add a Core ML classifier boundary to the app

**Objective:** Make model inference replaceable, testable, and independent of UI state.

**Files:**
- Create: `ScoreKeeper/Services/ScoreDigitClassifier.swift`
- Create: `ScoreKeeperTests/ScoreDigitClassifierTests.swift`
- Modify: `ScoreKeeper.xcodeproj/project.pbxproj`

**Proposed API:**

```swift
struct ScoreDigitPrediction: Equatable {
    let digit: Int
    let probability: Double
    let runnerUpProbability: Double
}

protocol ScoreDigitClassifying: Sendable {
    func classify(_ image: CVPixelBuffer) async throws -> ScoreDigitPrediction
}
```

The production implementation loads `PipCountDigitClassifier` once, runs off the main actor, and returns raw calibrated values. It does not decide whether the complete score should be accepted.

Tests must cover model loading, all fixed single-digit fixtures, deterministic repeat inference, and Python/Core ML parity.

---

## Task 6: Replace Vision OCR in `ScoreRecognizer`

**Objective:** Orchestrate ink validation, segmentation, classification, and safe rejection without text aliases.

**Files:**
- Modify: `ScoreKeeper/Services/ScoreRecognizer.swift`
- Modify: `ScoreKeeperTests/ScoreRecognizerFixtureTests.swift`

**Required behavior:**

1. Reject blank input before model invocation.
2. Reject unsupported leading-minus input.
3. Segment into one or two digits.
4. Classify each segment.
5. Reject the entire score if any segment is `reject`, below its calibrated acceptance threshold, or below the runner-up margin.
6. Join accepted digits left to right.
7. Permit only `0...99`.
8. Return diagnostic confidence without mapping letters to numbers.

Delete:

- `VNRecognizeTextRequest` use.
- `O/o → 0` aliases.
- `I/l/| → 1` aliases.
- First-candidate-wins text parsing.
- Special fallbacks that manufacture a zero from topology after OCR fails.

Run the full recognizer corpus after each vertical behavior slice.

---

## Task 7: Replace independent booleans with one score-entry state machine

**Objective:** Prevent contradictory controls and stale recognition state.

**Files:**
- Modify: `ScoreKeeper/Views/Scoring/RoundEntryDeckView.swift`
- Modify: `ScoreKeeperUITests/ScoreRecognitionE2ETests.swift`

**Proposed state:**

```swift
enum ScoreEntryPhase: Equatable {
    case drawing
    case recognizing(requestID: UUID)
    case confirming(value: Int, confidence: Double, thumbnail: UIImage)
    case manual(reason: ScoreRecognitionFailure, text: String)
}
```

**State-specific controls:**

- Drawing: **Clear**, **Read score**.
- Recognizing: progress only; canvas/actions disabled.
- Confirming: drawing thumbnail, **Redraw**, **Use N**.
- Manual: empty numeric field, **Redraw**, **Use N** only when valid.

Late results whose `requestID` is no longer current must be discarded.

---

## Task 8: Fix retry and manual-entry safety

**Objective:** Remove the two most dangerous interaction failures from the recording.

**Files:**
- Modify: `ScoreKeeper/Views/Scoring/RoundEntryDeckView.swift`
- Modify: `ScoreKeeperUITests/ScoreRecognitionE2ETests.swift`

**Failing tests first:**

- Retry/redraw clears the canvas and returns to `.drawing`.
- Retry does not invoke recognition on unchanged ink.
- Manual fallback starts with `""`, not `"0"`.
- Invalid/empty input keeps **Use** disabled.
- Entering `0` explicitly enables **Use 0**.
- Manual `25` commits exactly 25.
- Recognition and drawing toolbars never coexist.
- The source thumbnail remains visible during confirmation.

Delete any `Int(digits) ?? 0` conversion from the commit path.

**Gate:** Gate C must pass.

---

## Task 9: Simplify the scoring-card hierarchy

**Objective:** Remove duplicated instructions and ambiguous icon-only actions without redesigning the entire deck.

**Files:**
- Modify: `ScoreKeeper/Views/Scoring/RoundEntryDeckView.swift`

**Changes:**

- Use one heading for the current player and score task.
- Keep one progress indicator; remove duplicate `Player 1 of 2`, `1 / 2`, and dot representations.
- Hide drawing instructions while recognizing, confirming, or entering manually.
- Replace icon-only retry/accept actions with visible **Redraw** and **Use N** labels.
- Keep decorative artwork only where it does not compete with the scoring action.
- Verify Dynamic Type, VoiceOver labels, iPhone safe areas, and iPad split-view layout.

---

## Task 10: Run end-to-end evidence and release gates

**Objective:** Prove the final implementation on real app surfaces and preserve every result.

**Files:**
- Modify: `ScoreKeeperUITests/ScoreRecognitionE2ETests.swift`
- Create/modify: `docs/score-recognition-validation.md`

**Automated verification:**

```bash
xcodebuild test \
  -project ScoreKeeper.xcodeproj \
  -scheme ScoreKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ScoreKeeperTests/ScoreDigitSegmenterTests \
  -only-testing:ScoreKeeperTests/ScoreDigitClassifierTests \
  -only-testing:ScoreKeeperTests/ScoreRecognizerFixtureTests
```

Repeat on the supported iPad simulator, then run focused handwriting E2E and the complete unit/UI baseline.

**Evidence requirements:**

- One PNG per single/double/rejection fixture showing source, segments, expected value, result, and confidence/margin.
- Contact sheets for singles, all doubles, recording regressions, and rejection controls.
- JSON/CSV raw result exports.
- Model and fixture hashes.
- Explicit list of every rejection and every wrong accepted value.

**Release rule:** If any fixed regression or held-out case returns a wrong accepted score, stop. Do not archive or upload. Safe rejection is permitted; wrong acceptance is not.

After all gates pass:

1. Run `git diff --check` and the full test matrix.
2. Review the final source/model diff independently.
3. Commit and push the intended branch.
4. Build from a clean worktree pinned to the verified commit.
5. Increment the build number.
6. Upload to TestFlight.
7. Verify App Store Connect processing reaches `VALID` and internal beta distribution reaches `IN_BETA_TESTING`.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Synthetic tests create false confidence | Writer-disjoint real PencilKit corpus is mandatory. |
| Wrong predictions carry high confidence | Reject class, margin calibration, and zero-wrong-accept gate. |
| Double-digit resampling changes a digit class | Normalize each digit only after deterministic segmentation; add composition regressions. |
| Training data leaks into validation | Split by writer before augmentation; hash-based leakage check. |
| Model/license provenance is unclear | Train from scratch; record dataset/model licenses and hashes; do not ship comparison weights. |
| UI allows accidental zero | Empty optional manual value; explicit `Use N`; never default parse to zero. |
| Retry loops on identical pixels | Retry means redraw and clears ink. |
| Async result updates stale card | Request ID in the state machine; ignore superseded responses. |
| Model update increases app complexity | Ship a static Core ML artifact; keep training tools out of the app target. |

---

## Final acceptance checklist

- [ ] Vision text OCR and letter aliases removed.
- [ ] Gate A segmentation passes.
- [ ] Gate B has zero wrong accepted scores.
- [ ] Gate C interaction safety passes.
- [ ] Recording `3`, crossed `7`, `9`, `1`, and `2` are correct or safely rejected.
- [ ] Every synthetic score `0...99` is correct.
- [ ] Blank, scribble, malformed, and negative inputs never become scores.
- [ ] Retry redraws instead of rerunning unchanged ink.
- [ ] Manual entry starts empty and never implies zero.
- [ ] Only one action set is visible per state.
- [ ] Per-test screenshots and raw machine-readable results are archived.
- [ ] iPhone and iPad focused/full test gates pass.
- [ ] TestFlight build is created only from the verified source/model revision.
