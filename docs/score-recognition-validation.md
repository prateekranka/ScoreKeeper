# Score Recognition Validation

## Current Status

The model-tooling workstream is **blocked at the corpus gate**. No approved
12-writer corpus, production checkpoint, evaluation metrics, screenshots, or
Core ML artifact is present in this repository. The scripts are scaffolding for
the reviewed data handoff; they do not manufacture those deliverables.

The earlier spike is comparison evidence only. It found that Apple MNIST and
the EMNIST comparison model did not generalize safely to the recording-derived
inputs, and that the EMNIST artifact has GPL/AGPL licensing concerns. Those
artifacts are not imported by these tools and are not eligible for export.

## Manifest Contract

`Tools/ScoreDigitModel/dataset_manifest.schema.json` is the version 1 contract.
It requires:

- The fixed classifier class list `0` through `9` plus `reject`.
- Source version, license URL, rights status, attribution, and derivative
  model-use permission.
- Privacy review and an explicit outside-Git raw-data policy.
- Pseudonymous writer registry and consent status.
- A writer-disjoint split policy with one recorded seed and augmentation only
  after splitting.
- Reproducibility metadata for Python, preprocessing, augmentation, and seed.
- Quality-gate policy values that cannot be lowered below the plan's 12-writer,
  per-writer, reject-control, and label-balance minimums.
- SHA-256, source, writer, split, and augmentation lineage for every sample.

`digit` rows are normalized classifier crops. `score` rows are two-digit
composition controls for the separate segmentation gate. `reject` rows are
explicit out-of-distribution controls. This separation prevents the training
script from silently using an unsegmented score image as a digit label.

## Checks

The release command is fail-closed:

```sh
python3 Tools/ScoreDigitModel/validate_dataset.py \
  --manifest /private/pipcount-score-data/manifest.json \
  --data-root /private/pipcount-score-data \
  --mode release \
  --json
```

It rejects:

- Missing or unknown writer/source references and missing sample files.
- Absolute paths, traversal, symlinks escaping the data root, or SHA-256
  mismatches.
- Duplicate sample paths or hashes, including hashes shared across splits.
- A writer appearing in both train and validation, or a writer/list mismatch.
- Augmented samples whose parent changes writer/split, is missing, or forms a
  lineage cycle.
- GPL/AGPL/LGPL/Affero source labels.
- Pending privacy/consent/rights metadata in release mode.
- Fewer than 12 writers, missing per-writer digits, missing required doubles,
  absent reject controls, or split label imbalance.

Draft mode is useful while collecting data, but it does not satisfy the release
gate and is rejected by `train.py`, `evaluate.py`, and `export_coreml.py`.

## Evidence Protocol

After the external corpus has been collected and reviewed:

1. Run draft validation and resolve every error without using `--skip-file-checks`.
2. Freeze the manifest and run release validation. Preserve the JSON report and
   exact manifest SHA-256 with the run outputs.
3. Train from scratch with the manifest seed. Preserve the checkpoint,
   training metadata, requirements lock, architecture, preprocessing, source
   licenses, and checkpoint SHA-256 outside Git or in the reviewed release
   evidence location.
4. Evaluate only the untouched validation writer group. Preserve the complete
   JSON case output, confusion matrix, thresholds, wrong-accepted list, safe
   rejection counts, and hashes.
5. Stop immediately if any valid input is accepted as the wrong value or any
   reject control is accepted as a digit. Safe rejection is allowed; wrong
   acceptance is not.
6. Export Core ML only when the evaluator reports zero wrong accepted values,
   100% accepted precision, and at least 95% valid-input coverage. Preserve
   the export metadata and artifact SHA-256.
7. Keep app integration and the final Xcode resource out of this tooling step.
   A separate app workstream must review the candidate and rerun the Swift
   gates before any model is placed in the app target.

The training/evaluation/export scripts use deterministic CPU defaults and
record the effective seed. Any seed override must equal
`reproducibility.seed` in the manifest, so a run cannot quietly diverge from
the declared split/provenance record.

## Gate Record

| Gate | Required evidence | Status in this worktree |
|---|---|---|
| Dataset contract | Reviewed manifest, hashes, provenance, licenses | Blocked: no corpus/manifest supplied |
| Writer-disjoint split | Separate writer groups and no hash/lineage leakage | Blocked: no corpus supplied |
| Corpus minimum | 12 writers, required digits/doubles/reject controls | Blocked: no corpus supplied |
| Model training | From-scratch checkpoint and reproducibility metadata | Not run |
| Recognition safety | Zero wrong accepted values; 100% accepted precision; >=95% valid coverage | Not measured |
| Core ML export | Passing evaluation and artifact hash | Blocked; no production artifact created |
| App integration | Swift/Xcode resource and parity tests | Out of scope for this workstream |

No metric in this document is a result of the new tooling. Existing spike
measurements remain in the external spike report and are not a substitute for
the required writer-disjoint acceptance run.
