#!/usr/bin/env python3
"""Train the small PipCount digit classifier from an approved corpus.

This command intentionally refuses draft manifests.  It creates a PyTorch
checkpoint outside the app target; Core ML export is a separate, gated step.
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path
from typing import Any

from model import (
    AUGMENTATION_VERSION,
    CLASS_NAMES,
    MODEL_ARCHITECTURE,
    MODEL_VERSION,
    PREPROCESSING_VERSION,
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
        description="Train the from-scratch PipCount 0-9 plus reject classifier."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        required=True,
        help="external directory containing the manifest's raw image paths",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="directory for a checkpoint and training metadata",
    )
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--learning-rate", type=float, default=0.001)
    parser.add_argument(
        "--seed",
        type=int,
        help="optional override; must equal reproducibility.seed in the manifest",
    )
    parser.add_argument(
        "--device",
        choices=("cpu", "cuda"),
        default="cpu",
        help="training device; CPU is the reproducible default",
    )
    return parser


def _load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def _load_dependencies() -> tuple[Any, Any]:
    try:
        import torch
    except ImportError as error:
        raise RuntimeError(
            "PyTorch is required for training. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock in an isolated environment."
        ) from error
    try:
        from PIL import Image
    except ImportError as error:
        raise RuntimeError(
            "Pillow is required for training. Install the pinned dependencies from "
            "Tools/ScoreDigitModel/requirements.lock in an isolated environment."
        ) from error
    return torch, Image


def train(args: argparse.Namespace) -> int:
    report = validate_manifest(
        args.manifest,
        args.data_root,
        require_complete_corpus=True,
        check_files=True,
        repository_root=ROOT,
    )
    if not report.ok:
        print("ERROR: release dataset gate blocked training", file=sys.stderr)
        for error in report.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    if args.epochs < 1 or args.batch_size < 1 or args.learning_rate <= 0:
        print("ERROR: epochs, batch-size, and learning-rate must be positive", file=sys.stderr)
        return 2
    manifest = _load_manifest(args.manifest)
    manifest_seed = manifest["reproducibility"]["seed"]
    if args.seed is not None and args.seed != manifest_seed:
        print(
            f"ERROR: --seed {args.seed} does not match manifest reproducibility.seed {manifest_seed}",
            file=sys.stderr,
        )
        return 2
    seed = manifest_seed

    try:
        torch, image_module = _load_dependencies()
    except RuntimeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    if args.device == "cuda" and not torch.cuda.is_available():
        print("ERROR: --device cuda was requested but CUDA is unavailable", file=sys.stderr)
        return 2

    seed_everything(torch, seed)
    device = torch.device(args.device)
    train_samples = classifier_samples(manifest, "train")
    if not train_samples:
        print("ERROR: release manifest has no classifier samples in the train split", file=sys.stderr)
        return 2

    dataset = make_dataset(
        torch,
        image_module,
        train_samples,
        Path(args.data_root).resolve(),
        training=True,
        seed=seed,
    )
    generator = torch.Generator()
    generator.manual_seed(seed)
    loader = torch.utils.data.DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=True,
        generator=generator,
        num_workers=0,
    )

    model = build_model(torch).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)
    loss_function = torch.nn.CrossEntropyLoss()
    history: list[dict[str, float | int]] = []
    for epoch in range(1, args.epochs + 1):
        model.train()
        total_loss = 0.0
        total_examples = 0
        for images, labels, _sample_ids in loader:
            images = images.to(device)
            labels = labels.to(device)
            optimizer.zero_grad(set_to_none=True)
            logits = model(images)
            loss = loss_function(logits, labels)
            loss.backward()
            optimizer.step()
            batch_size = labels.shape[0]
            total_loss += float(loss.detach().cpu()) * batch_size
            total_examples += batch_size
        history.append(
            {
                "epoch": epoch,
                "training_loss": total_loss / total_examples,
                "examples": total_examples,
            }
        )

    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint_path = output_dir / "pipcount_digit_classifier.pt"
    source_map = {
        source["source_id"]: source
        for source in manifest["provenance"]["sources"]
    }
    source_ids = sorted({sample["source_id"] for sample in train_samples})
    checkpoint = {
        "format_version": 1,
        "model_version": MODEL_VERSION,
        "classes": list(CLASS_NAMES),
        "architecture": MODEL_ARCHITECTURE,
        "preprocessing": {
            "version": PREPROCESSING_VERSION,
            "input_shape": [1, 28, 28],
            "polarity": "black-ink-is-one",
        },
        "augmentation": {
            "version": AUGMENTATION_VERSION,
            "operations": ["translation", "rotation", "scale", "width", "antialiasing"],
            "applied_only_to": "train_split_after_writer_split",
        },
        "dataset": {
            "name": manifest["dataset"]["name"],
            "version": manifest["dataset"]["version"],
            "manifest_sha256": manifest_digest(args.manifest),
        },
        "reproducibility": {
            "seed": seed,
            "python_version": platform.python_version(),
            "torch_version": torch.__version__,
            "device": args.device,
            "deterministic_algorithms": True,
        },
        "training_provenance": {
            "method": "from-scratch",
            "comparison_weights_used": False,
            "raw_samples_embedded": False,
            "source_ids": source_ids,
            "source_licenses": {
                source_id: source_map[source_id]["license"] for source_id in source_ids
            },
        },
        "training_config": {
            "epochs": args.epochs,
            "batch_size": args.batch_size,
            "learning_rate": args.learning_rate,
            "train_sample_count": len(train_samples),
        },
        "history": history,
        "model_state_dict": model.to("cpu").state_dict(),
    }
    torch.save(checkpoint, checkpoint_path)
    checkpoint_hash = artifact_digest(checkpoint_path)
    metadata = {
        "checkpoint": checkpoint_path.name,
        "checkpoint_sha256": checkpoint_hash,
        "model_version": MODEL_VERSION,
        "dataset_manifest_sha256": checkpoint["dataset"]["manifest_sha256"],
        "dataset_version": manifest["dataset"]["version"],
        "seed": seed,
        "from_scratch": True,
        "comparison_weights_used": False,
        "note": "Training loss is recorded from this run; no validation or production-readiness claim is made here.",
    }
    (output_dir / "training_metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Wrote checkpoint: {checkpoint_path}")
    print(f"Checkpoint SHA-256: {checkpoint_hash}")
    print("Validation was intentionally not used during training; run evaluate.py on the untouched split.")
    return 0


def main(argv: list[str] | None = None) -> int:
    return train(_build_parser().parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
