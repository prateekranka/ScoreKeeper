# PipCount Score Digit Model Tooling

This directory contains offline dataset validation, training, evaluation, and
Core ML export tooling for the handwritten score recognition revision. It does
not contain a dataset, raw handwriting, comparison weights, a trained model,
metrics, or screenshots.

The production feature is intentionally blocked until a real writer-diverse
corpus passes the release profile. The tooling never turns a draft corpus or a
failed evaluation into a production artifact.

## Data Boundary

Raw images must live outside Git and outside the repository. The manifest may
be stored wherever the data owner keeps the private corpus, and each `path` is
resolved relative to the explicit `--data-root` argument. Do not put names,
recordings, device metadata, or unapproved user data in this repository.

Each manifest sample is one of three kinds:

- `digit`: a normalized one-digit crop used by the classifier; `label` is `0`
  through `9`.
- `score`: an untouched two-digit composition used to exercise segmentation;
  `score` is `10` through `99`. These samples are not silently treated as
  classifier crops.
- `reject`: a blank, scribble, partial digit, touching pair, or unsupported
  negative; `label` is `reject` and `reject_reason` records why.

The manifest is described by
`dataset_manifest.schema.json`. Every row includes a writer ID, split, source
ID, SHA-256, and augmentation lineage. Writer IDs are pseudonymous IDs, not
names. Augmented rows must point to a parent in the same writer and split.

## Required Corpus

The release validator enforces the plan's corpus gate, rather than trusting a
caller to lower it in the manifest:

- At least 12 writers, with separate train and validation writer groups.
- Every writer contributes every single digit at least twice.
- Every writer contributes at least 12 distinct two-digit score values,
  including `11`, `12`, `20`, `25`, `37`, `50`, `69`, `72`, `90`, and `99`.
- The corpus includes crossed and uncrossed `7`, open and closed `4`, looped
  and straight `9`, both angular and curved `2`, and varied stroke width and
  placement.
- Reject controls include blank, scribble, partial digit, touching digits,
  and unsupported negative input.
- Each split has all digit labels with the configured minimum count and a
  maximum digit-count ratio no greater than 2:1.

The repository currently contains no manifest or real corpus. Consequently,
the release profile is expected to fail until the data owner supplies the
external files and reviewed metadata.

## Validation

Use Python 3.11 or another interpreter supported by the locked ML packages.
The validator itself uses only the standard library.

Draft collection checks still enforce schema shape, references, SHA-256, path
safety, writer-disjointness, duplicate hashes, and prohibited licenses. Draft
mode does not claim that the corpus meets the 12-writer gate.

```sh
python3 Tools/ScoreDigitModel/validate_dataset.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --mode draft
```

The default is the fail-closed release profile. `--json` emits a report with
`ok`, `errors`, `warnings`, and aggregate counts for CI or audit logs.

```sh
python3 Tools/ScoreDigitModel/validate_dataset.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --mode release \
  --json > /private/pipcount-score-data/validation.json
```

`--skip-file-checks` is for schema/metadata review only. It does not make a
release corpus valid and must not be used for training, evaluation, or export.

## Reproducible Pipeline

Create an isolated environment outside the repository. The lock contains
top-level pins for Pillow, PyTorch, NumPy, and coremltools; use a supported
CPython 3.11 environment because the host interpreter may be newer than those
packages support.

```sh
python3.11 -m venv /tmp/pipcount-score-model-venv
/tmp/pipcount-score-model-venv/bin/python -m pip install -r \
  Tools/ScoreDigitModel/requirements.lock
```

Training refuses a draft manifest and records the exact manifest hash, dataset
version, seed, preprocessing/augmentation versions, architecture, source
licenses, and the fact that it started from scratch. It writes only a
checkpoint and metadata to the requested output directory.

```sh
/tmp/pipcount-score-model-venv/bin/python Tools/ScoreDigitModel/train.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --output-dir /private/pipcount-score-runs/run-001 \
  --epochs 20 \
  --batch-size 32
```

The classifier has exactly 11 classes: `0` through `9` plus `reject`. It uses
28x28 grayscale input with black ink represented as one. Training augmentation
is limited to small translation, rotation, scale, width, and antialiasing
changes, and is deterministic per sample from the manifest seed.

Evaluation reloads the exact checkpoint/manifest pair and reads only the
untouched validation writer group. Acceptance requires both top-class
probability and top-two margin. A rejected prediction is safe; a wrong
accepted value fails the command and is listed in the JSON output.

```sh
/tmp/pipcount-score-model-venv/bin/python Tools/ScoreDigitModel/evaluate.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --checkpoint /private/pipcount-score-runs/run-001/pipcount_digit_classifier.pt \
  --output /private/pipcount-score-runs/run-001/evaluation.json \
  --min-probability 0.90 \
  --min-margin 0.20
```

The evaluation command returns a non-zero status when the safety gate fails.
Its report records confusion counts, every wrong accepted case, accepted
precision, valid-input coverage, safe rejection counts, thresholds, hashes,
and seed metadata. Thresholds are explicit inputs; the script does not claim
that they are calibrated until the untouched validation protocol demonstrates
the release criteria.

Core ML export has no bypass option. It requires a passing evaluation generated
from the exact checkpoint and manifest, zero wrong accepted values, 100%
accepted precision, at least 95% valid-input coverage, approved source rights,
and checkpoint provenance proving from-scratch training with no comparison
weights. It refuses to overwrite an existing output.

```sh
/tmp/pipcount-score-model-venv/bin/python Tools/ScoreDigitModel/export_coreml.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --checkpoint /private/pipcount-score-runs/run-001/pipcount_digit_classifier.pt \
  --evaluation /private/pipcount-score-runs/run-001/evaluation.json \
  --output /private/pipcount-score-runs/run-001/PipCountDigitClassifier.mlpackage
```

The export command writes a candidate and a hash metadata file only after all
gates pass. It does not modify `ScoreKeeper/`, add an Xcode resource, or claim
that app integration is complete. The expected current behavior is an early
gate failure because no approved corpus, checkpoint, evaluation, or Core ML
artifact exists.

## Licensing

Every source must carry a version, license name and URL, rights status,
attribution, and explicit derivative-model permission. The validator rejects
GPL, AGPL, LGPL, and Affero license labels. The spike's EMNIST comparison
model and all other comparison weights remain outside this pipeline and must
not be copied into a checkpoint or app bundle.

## Exit Status

- `0`: requested check or pipeline stage passed.
- `1`: validation/evaluation/export gate failed after running the requested
  operation.
- `2`: invalid command, missing input, missing dependency, or release preflight
  failure before the operation could run.
