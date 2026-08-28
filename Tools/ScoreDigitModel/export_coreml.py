#!/usr/bin/env python3
"""Export a passing, from-scratch checkpoint to Core ML.

There is no bypass flag.  An untouched writer-disjoint evaluation result with
zero wrong accepted values is required before this command imports
coremltools or writes an artifact.
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path
from typing import Any

from model import (
    CLASS_NAMES,
    MODEL_VERSION,
    artifact_digest,
    build_model,
    manifest_digest,
)
from validate_dataset import FORBIDDEN_LICENSE, ROOT, validate_manifest


MAX_ARTIFACT_BYTES = 1_000_000


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export a passing PipCount checkpoint to a gated Core ML package."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--evaluation", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help=".mlpackage or .mlmodel output path; do not point this at the app target until release review",
    )
    parser.add_argument(
        "--metadata-output",
        type=Path,
        help="optional export metadata path (default: <output>.metadata.json)",
    )
    return parser


def _load_json(path: Path, description: str) -> dict[str, Any]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"could not read {description} {path}: {error}") from error
    if not isinstance(value, dict):
        raise RuntimeError(f"{description} must contain a JSON object: {path}")
    return value


def _load_dependencies() -> tuple[Any, Any]:
    try:
        import coremltools as ct
    except ImportError as error:
        raise RuntimeError(
            "coremltools is required for export. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock in an isolated environment."
        ) from error
    try:
        import torch
    except ImportError as error:
        raise RuntimeError(
            "PyTorch is required to load and trace the checkpoint. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock."
        ) from error
    return torch, ct


def _load_checkpoint(torch: Any, path: Path) -> dict[str, Any]:
    checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    if not isinstance(checkpoint, dict):
        raise RuntimeError("checkpoint must contain a metadata dictionary")
    return checkpoint


def _check_evaluation_gate(
    evaluation: dict[str, Any], manifest_hash: str, checkpoint_hash: str
) -> None:
    if evaluation.get("evaluation_protocol") != "writer-disjoint-validation":
        raise RuntimeError("evaluation is not marked as writer-disjoint validation")
    if evaluation.get("gate_passed") is not True:
        raise RuntimeError(
            "evaluation gate is not passed; export requires zero wrong accepted values and at least 95% valid coverage"
        )
    dataset = evaluation.get("dataset")
    if not isinstance(dataset, dict) or dataset.get("manifest_sha256") != manifest_hash:
        raise RuntimeError("evaluation was not produced from the exact supplied manifest")
    if evaluation.get("checkpoint_sha256") != checkpoint_hash:
        raise RuntimeError("evaluation was not produced from the exact supplied checkpoint")
    metrics = evaluation.get("metrics")
    if not isinstance(metrics, dict):
        raise RuntimeError("evaluation is missing metrics")
    wrong_accepted_examples = metrics.get("wrong_accepted_examples")
    if (
        not isinstance(wrong_accepted_examples, int)
        or isinstance(wrong_accepted_examples, bool)
        or wrong_accepted_examples != 0
        or metrics.get("wrong_accepted") != []
    ):
        raise RuntimeError("evaluation contains a wrong accepted value; export is blocked")
    accepted_precision = metrics.get("accepted_precision")
    if (
        not isinstance(accepted_precision, (int, float))
        or isinstance(accepted_precision, bool)
        or accepted_precision != 1.0
    ):
        raise RuntimeError("accepted precision is not exactly 100%; export is blocked")
    valid_coverage = metrics.get("valid_coverage")
    if (
        not isinstance(valid_coverage, (int, float))
        or isinstance(valid_coverage, bool)
        or valid_coverage < 0.95
    ):
        raise RuntimeError("valid-input coverage is below 95%; export is blocked")


def _check_training_provenance(checkpoint: dict[str, Any]) -> None:
    if checkpoint.get("model_version") != MODEL_VERSION:
        raise RuntimeError(f"checkpoint model_version must be {MODEL_VERSION!r}")
    if checkpoint.get("classes") != list(CLASS_NAMES):
        raise RuntimeError("checkpoint classes do not match the 0-9 plus reject contract")
    provenance = checkpoint.get("training_provenance")
    if not isinstance(provenance, dict):
        raise RuntimeError("checkpoint is missing training provenance")
    if provenance.get("method") != "from-scratch":
        raise RuntimeError("export requires a from-scratch checkpoint")
    if provenance.get("comparison_weights_used") is not False:
        raise RuntimeError("comparison or pretrained weights are not permitted")
    if provenance.get("raw_samples_embedded") is not False:
        raise RuntimeError("checkpoint must not embed raw samples")
    licenses = provenance.get("source_licenses")
    if not isinstance(licenses, dict) or not licenses:
        raise RuntimeError("checkpoint is missing source license metadata")
    for source_id, license_name in licenses.items():
        if not isinstance(license_name, str) or FORBIDDEN_LICENSE.search(license_name):
            raise RuntimeError(f"prohibited or invalid source license for {source_id}")


def _artifact_size(path: Path) -> int:
    if path.is_file():
        return path.stat().st_size
    return sum(child.stat().st_size for child in path.rglob("*") if child.is_file())


def export(args: argparse.Namespace) -> int:
    output_path = Path(args.output).expanduser().resolve()
    if output_path.suffix not in {".mlpackage", ".mlmodel"}:
        print("ERROR: --output must end in .mlpackage or .mlmodel", file=sys.stderr)
        return 2
    if output_path.exists():
        print(f"ERROR: refusing to overwrite existing export: {output_path}", file=sys.stderr)
        return 2
    metadata_path = (
        Path(args.metadata_output).expanduser().resolve()
        if args.metadata_output
        else output_path.parent / f"{output_path.name}.metadata.json"
    )
    if metadata_path == output_path:
        print("ERROR: --metadata-output must not be the export path", file=sys.stderr)
        return 2
    if metadata_path.exists():
        print(f"ERROR: refusing to overwrite export metadata: {metadata_path}", file=sys.stderr)
        return 2

    report = validate_manifest(
        args.manifest,
        args.data_root,
        require_complete_corpus=True,
        check_files=True,
        repository_root=ROOT,
    )
    if not report.ok:
        print("ERROR: release dataset gate blocked Core ML export", file=sys.stderr)
        for error in report.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    try:
        manifest_hash = manifest_digest(args.manifest)
        checkpoint_hash = artifact_digest(args.checkpoint)
        evaluation = _load_json(args.evaluation, "evaluation")
        _check_evaluation_gate(evaluation, manifest_hash, checkpoint_hash)
        torch, coremltools = _load_dependencies()
        checkpoint = _load_checkpoint(torch, args.checkpoint)
        _check_training_provenance(checkpoint)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    model = build_model(torch)
    try:
        model.load_state_dict(checkpoint["model_state_dict"])
    except (KeyError, RuntimeError) as error:
        print(f"ERROR: checkpoint model state is incompatible: {error}", file=sys.stderr)
        return 2
    model.eval()

    class CoreMLInputAdapter(torch.nn.Module):
        """Invert Core ML's white=1 image input to the training ink polarity."""

        def __init__(self, wrapped: Any) -> None:
            super().__init__()
            self.wrapped = wrapped

        def forward(self, image: Any) -> Any:
            return self.wrapped(1.0 - image)

    adapter = CoreMLInputAdapter(model)
    example = torch.zeros((1, 1, 28, 28), dtype=torch.float32)
    traced = torch.jit.trace(adapter, example, strict=True)
    try:
        image_type = coremltools.ImageType(
            name="image",
            shape=example.shape,
            scale=1.0 / 255.0,
            bias=0.0,
            color_layout=coremltools.colorlayout.GRAYSCALE,
        )
        converted = coremltools.convert(
            traced,
            convert_to="mlprogram",
            inputs=[image_type],
            classifier_config=coremltools.ClassifierConfig(list(CLASS_NAMES)),
            minimum_deployment_target=coremltools.target.iOS16,
        )
        output_path.parent.mkdir(parents=True, exist_ok=True)
        converted.save(str(output_path))
    except Exception as error:  # coremltools exposes version-specific exception types
        print(f"ERROR: Core ML conversion failed: {error}", file=sys.stderr)
        return 1

    size = _artifact_size(output_path)
    artifact_hash = artifact_digest(output_path)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata = {
        "format_version": 1,
        "model_version": MODEL_VERSION,
        "artifact": output_path.name,
        "artifact_sha256": artifact_hash,
        "artifact_bytes": size,
        "manifest_sha256": manifest_hash,
        "checkpoint_sha256": checkpoint_hash,
        "evaluation_sha256": artifact_digest(args.evaluation),
        "classes": list(CLASS_NAMES),
        "input": {
            "shape": [1, 1, 28, 28],
            "image_type": "grayscale",
            "scale": 1.0 / 255.0,
            "training_polarity": "black-ink-is-one",
        },
        "reproducibility": checkpoint.get("reproducibility", {}),
        "training_provenance": checkpoint["training_provenance"],
        "gate": {
            "evaluation_protocol": "writer-disjoint-validation",
            "wrong_accepted_examples": 0,
            "accepted_precision": 1.0,
            "valid_coverage": evaluation["metrics"]["valid_coverage"],
        },
        "note": "Candidate export only. App integration remains a separate release-review step.",
    }
    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Wrote Core ML candidate: {output_path}")
    print(f"Artifact SHA-256: {artifact_hash}")
    print(f"Artifact bytes: {size}")
    if size > MAX_ARTIFACT_BYTES:
        print(
            f"ERROR: artifact exceeds the {MAX_ARTIFACT_BYTES}-byte target; release remains blocked",
            file=sys.stderr,
        )
        return 1
    print(f"Wrote export metadata: {metadata_path}")
    print("No app resource was modified or integrated.")
    return 0


def main(argv: list[str] | None = None) -> int:
    return export(_build_parser().parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
