#!/usr/bin/env python3
"""Evaluate a trained checkpoint on the untouched writer-disjoint split."""

from __future__ import annotations

import argparse
import json
import platform
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

from model import (
    CLASS_NAMES,
    MODEL_VERSION,
    artifact_digest,
    build_model,
    classifier_samples,
    make_dataset,
    manifest_digest,
    seed_everything,
)
from validate_dataset import ROOT, validate_manifest


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Evaluate a PipCount checkpoint with confidence and margin gating."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="JSON result path")
    parser.add_argument(
        "--min-probability",
        type=float,
        default=0.90,
        help="minimum top-class probability for acceptance (default: 0.90)",
    )
    parser.add_argument(
        "--min-margin",
        type=float,
        default=0.20,
        help="minimum top-two probability margin for acceptance (default: 0.20)",
    )
    return parser


def _load_dependencies() -> tuple[Any, Any]:
    try:
        import torch
    except ImportError as error:
        raise RuntimeError(
            "PyTorch is required for evaluation. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock in an isolated environment."
        ) from error
    try:
        from PIL import Image
    except ImportError as error:
        raise RuntimeError(
            "Pillow is required for evaluation. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock in an isolated environment."
        ) from error
    return torch, Image


def _load_checkpoint(torch: Any, path: Path) -> dict[str, Any]:
    checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    if not isinstance(checkpoint, dict):
        raise RuntimeError("checkpoint must contain a metadata dictionary")
    return checkpoint


def _validate_threshold(value: float, name: str) -> None:
    if not 0 <= value <= 1:
        raise ValueError(f"{name} must be between 0 and 1")


def evaluate(args: argparse.Namespace) -> int:
    try:
        _validate_threshold(args.min_probability, "--min-probability")
        _validate_threshold(args.min_margin, "--min-margin")
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    report = validate_manifest(
        args.manifest,
        args.data_root,
        require_complete_corpus=True,
        check_files=True,
        repository_root=ROOT,
    )
    if not report.ok:
        print("ERROR: release dataset gate blocked evaluation", file=sys.stderr)
        for error in report.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    try:
        torch, image_module = _load_dependencies()
        checkpoint = _load_checkpoint(torch, args.checkpoint)
    except (RuntimeError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    if checkpoint.get("model_version") != MODEL_VERSION:
        print(
            f"ERROR: checkpoint model_version must be {MODEL_VERSION!r}",
            file=sys.stderr,
        )
        return 2
    if checkpoint.get("classes") != list(CLASS_NAMES):
        print("ERROR: checkpoint classes do not match the manifest class contract", file=sys.stderr)
        return 2
    expected_manifest_hash = manifest_digest(args.manifest)
    checkpoint_dataset = checkpoint.get("dataset")
    if not isinstance(checkpoint_dataset, dict) or checkpoint_dataset.get(
        "manifest_sha256"
    ) != expected_manifest_hash:
        print(
            "ERROR: checkpoint was not trained from the exact manifest supplied to evaluation",
            file=sys.stderr,
        )
        return 2

    checkpoint_reproducibility = checkpoint.get("reproducibility")
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    manifest_seed = manifest["reproducibility"]["seed"]
    if not isinstance(checkpoint_reproducibility, dict) or checkpoint_reproducibility.get(
        "seed"
    ) != manifest_seed:
        print("ERROR: checkpoint seed does not match manifest reproducibility.seed", file=sys.stderr)
        return 2

    seed_everything(torch, manifest_seed)
    model = build_model(torch)
    try:
        model.load_state_dict(checkpoint["model_state_dict"])
    except (KeyError, RuntimeError) as error:
        print(f"ERROR: checkpoint model state is incompatible: {error}", file=sys.stderr)
        return 2
    model.eval()

    validation_samples = classifier_samples(manifest, "validation")
    if not validation_samples:
        print("ERROR: validation split has no classifier samples", file=sys.stderr)
        return 2
    dataset = make_dataset(
        torch,
        image_module,
        validation_samples,
        Path(args.data_root).resolve(),
        training=False,
        seed=manifest_seed,
    )
    loader = torch.utils.data.DataLoader(dataset, batch_size=64, shuffle=False, num_workers=0)

    case_results: list[dict[str, Any]] = []
    confusion: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    with torch.no_grad():
        for images, labels, sample_ids in loader:
            probabilities = torch.softmax(model(images), dim=1)
            top_probabilities, top_indices = torch.topk(probabilities, k=2, dim=1)
            for index, sample_id in enumerate(sample_ids):
                expected_index = int(labels[index])
                predicted_index = int(top_indices[index, 0])
                runner_up_index = int(top_indices[index, 1])
                top_probability = float(top_probabilities[index, 0])
                runner_up_probability = float(top_probabilities[index, 1])
                margin = top_probability - runner_up_probability
                accepted = (
                    predicted_index < len(CLASS_NAMES) - 1
                    and top_probability >= args.min_probability
                    and margin >= args.min_margin
                )
                expected_label = CLASS_NAMES[expected_index]
                predicted_label = CLASS_NAMES[predicted_index]
                confusion[expected_label][predicted_label] += 1
                case_results.append(
                    {
                        "sample_id": sample_id,
                        "expected": expected_label,
                        "top_class": predicted_label,
                        "runner_up_class": CLASS_NAMES[runner_up_index],
                        "top_probability": top_probability,
                        "runner_up_probability": runner_up_probability,
                        "margin": margin,
                        "accepted": accepted,
                        "accepted_value": predicted_label if accepted else None,
                    }
                )

    valid_cases = [case for case in case_results if case["expected"] != "reject"]
    reject_cases = [case for case in case_results if case["expected"] == "reject"]
    accepted_cases = [case for case in case_results if case["accepted"]]
    correctly_accepted = [
        case
        for case in accepted_cases
        if case["expected"] == case["accepted_value"]
    ]
    wrong_accepted = [
        case
        for case in accepted_cases
        if case["expected"] != case["accepted_value"]
    ]
    valid_correctly_accepted = [case for case in correctly_accepted if case["expected"] != "reject"]
    safe_rejects = [case for case in case_results if not case["accepted"]]
    safe_reject_controls = [case for case in reject_cases if not case["accepted"]]
    accepted_precision = (
        len(correctly_accepted) / len(accepted_cases) if accepted_cases else None
    )
    valid_coverage = (
        len(valid_correctly_accepted) / len(valid_cases) if valid_cases else None
    )
    gate_passed = (
        len(wrong_accepted) == 0
        and accepted_precision == 1.0
        and valid_coverage is not None
        and valid_coverage >= 0.95
    )

    result = {
        "format_version": 1,
        "evaluation_protocol": "writer-disjoint-validation",
        "model_version": checkpoint["model_version"],
        "dataset": {
            "name": manifest["dataset"]["name"],
            "version": manifest["dataset"]["version"],
            "manifest_sha256": expected_manifest_hash,
            "validation_writer_count": report.stats["writers_by_split"]["validation"],
        },
        "checkpoint_sha256": artifact_digest(args.checkpoint),
        "reproducibility": {
            "seed": manifest_seed,
            "python_version": platform.python_version(),
            "deterministic_algorithms": True,
        },
        "thresholds": {
            "min_probability": args.min_probability,
            "min_margin": args.min_margin,
        },
        "metrics": {
            "total_examples": len(case_results),
            "valid_examples": len(valid_cases),
            "reject_examples": len(reject_cases),
            "accepted_examples": len(accepted_cases),
            "correctly_accepted_examples": len(correctly_accepted),
            "wrong_accepted_examples": len(wrong_accepted),
            "wrong_accepted": wrong_accepted,
            "accepted_precision": accepted_precision,
            "valid_correctly_accepted_examples": len(valid_correctly_accepted),
            "valid_coverage": valid_coverage,
            "valid_safe_rejections": len(valid_cases) - len(valid_correctly_accepted),
            "safe_reject_examples": len(safe_rejects),
            "safe_reject_controls": len(safe_reject_controls),
            "reject_control_safe_rejection_rate": (
                len(safe_reject_controls) / len(reject_cases) if reject_cases else None
            ),
        },
        "gate_passed": gate_passed,
        "confusion_matrix": {
            expected: dict(sorted(predicted.items()))
            for expected, predicted in sorted(confusion.items())
        },
        "cases": case_results,
    }
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote evaluation: {output_path}")
    print(
        "Evaluation gate: "
        + ("PASS" if gate_passed else "BLOCKED")
        + f"; wrong accepted={len(wrong_accepted)}, valid coverage={valid_coverage}"
    )
    return 0 if gate_passed else 1


def main(argv: list[str] | None = None) -> int:
    return evaluate(_build_parser().parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
