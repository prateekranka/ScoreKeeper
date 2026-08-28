from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any


TOOL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_DIR))

from validate_dataset import validate_manifest  # noqa: E402


class DatasetValidatorTests(unittest.TestCase):
    def _manifest(
        self,
        root: Path,
        *,
        writers: list[str] | None = None,
        samples: list[dict[str, Any]] | None = None,
    ) -> tuple[Path, Path, dict[str, Any]]:
        data_root = root / "private-corpus"
        data_root.mkdir(parents=True, exist_ok=True)
        writer_ids = writers or ["writer-001", "writer-002"]
        source_id = "approved-public-source"
        manifest: dict[str, Any] = {
            "schema_version": 1,
            "dataset": {
                "name": "PipCount score digit test fixture",
                "version": "test-1",
                "description": "Temporary validator fixture; not a recognition corpus.",
                "classes": [str(value) for value in range(10)] + ["reject"],
            },
            "provenance": {
                "collection_protocol": "test-protocol-v1",
                "raw_samples_policy": "outside-git",
                "privacy_review": "approved",
                "sources": [
                    {
                        "source_id": source_id,
                        "kind": "public",
                        "name": "Permissive test source",
                        "version": "1",
                        "license": "CC BY 4.0",
                        "license_url": "https://creativecommons.org/licenses/by/4.0/",
                        "rights_status": "approved",
                        "redistribution_allowed": True,
                        "derivative_model_use_allowed": True,
                        "attribution": "Test fixture only",
                    }
                ],
            },
            "split_policy": {
                "strategy": "writer-disjoint",
                "seed": 17,
                "validation_fraction": 0.2,
                "augmentation_after_split": True,
                "hash_algorithm": "sha256",
                "train_writer_ids": writer_ids[:1],
                "validation_writer_ids": writer_ids[1:],
            },
            "reproducibility": {
                "seed": 17,
                "python_version": "3.11",
                "preprocessing_version": "ink-canvas-28-v1",
                "augmentation_version": "pencilkit-small-affine-v1",
                "deterministic": True,
            },
            "quality_gates": {
                "minimum_writers": 12,
                "minimum_digit_examples_per_writer": 2,
                "minimum_double_scores_per_writer": 12,
                "required_double_scores": [
                    "11",
                    "12",
                    "20",
                    "25",
                    "37",
                    "50",
                    "69",
                    "72",
                    "90",
                    "99",
                ],
                "required_reject_reasons": [
                    "blank",
                    "scribble",
                    "partial_digit",
                    "touching_digits",
                    "unsupported_negative",
                ],
                "label_balance": {
                    "minimum_examples_per_digit_per_split": 2,
                    "maximum_digit_imbalance_ratio": 2,
                    "minimum_reject_examples_per_split": 1,
                },
            },
            "writers": [
                {
                    "writer_id": writer_id,
                    "source_id": source_id,
                    "consent_status": "approved",
                }
                for writer_id in writer_ids
            ],
            "samples": samples or [],
        }
        manifest_path = root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        return manifest_path, data_root, manifest

    def _sample(
        self,
        data_root: Path,
        *,
        sample_id: str,
        writer_id: str,
        split: str,
        kind: str = "digit",
        label: str | None = "0",
        reject_reason: str | None = None,
        content: bytes | None = None,
        parent_sample_id: str | None = None,
        augmented: bool = False,
    ) -> dict[str, Any]:
        relative_path = f"{sample_id}.png"
        payload = content if content is not None else sample_id.encode("utf-8")
        (data_root / relative_path).write_bytes(payload)
        sample: dict[str, Any] = {
            "sample_id": sample_id,
            "path": relative_path,
            "sha256": hashlib.sha256(payload).hexdigest(),
            "writer_id": writer_id,
            "split": split,
            "source_id": "approved-public-source",
            "kind": kind,
            "augmentation": {
                "is_augmented": augmented,
                "parent_sample_id": parent_sample_id,
                "operations": ["translation"] if augmented else [],
            },
        }
        if kind == "digit":
            sample["label"] = label
        elif kind == "reject":
            sample["label"] = "reject"
            sample["reject_reason"] = reject_reason or "blank"
        elif kind == "score":
            sample["score"] = "12"
        return sample

    def test_draft_manifest_passes_file_and_hash_checks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="train-digit-0",
                    writer_id="writer-001",
                    split="train",
                ),
                self._sample(
                    data_root,
                    sample_id="validation-blank",
                    writer_id="writer-002",
                    split="validation",
                    kind="reject",
                    reject_reason="blank",
                ),
            ]
            manifest_path, _, _ = self._manifest(root, samples=samples)
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertTrue(report.ok, report.errors)
            self.assertEqual(report.stats["sample_count"], 2)

    def test_writer_leakage_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="train-digit",
                    writer_id="writer-001",
                    split="train",
                ),
                self._sample(
                    data_root,
                    sample_id="validation-digit",
                    writer_id="writer-001",
                    split="validation",
                ),
            ]
            manifest_path, _, _ = self._manifest(root, writers=["writer-001"], samples=samples)
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("writer leakage" in error for error in report.errors))

    def test_duplicate_hash_across_splits_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            shared = b"same bytes are not two independent samples"
            samples = [
                self._sample(
                    data_root,
                    sample_id="train-digit",
                    writer_id="writer-001",
                    split="train",
                    content=shared,
                ),
                self._sample(
                    data_root,
                    sample_id="validation-digit",
                    writer_id="writer-002",
                    split="validation",
                    content=shared,
                ),
            ]
            manifest_path, _, _ = self._manifest(root, samples=samples)
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("duplicate hash across splits" in error for error in report.errors))

    def test_missing_writer_reference_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="unknown-writer",
                    writer_id="writer-999",
                    split="train",
                )
            ]
            manifest_path, _, _ = self._manifest(root, samples=samples)
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("unknown writer_id" in error for error in report.errors))

    def test_augmentation_cannot_cross_split(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            parent = self._sample(
                data_root,
                sample_id="validation-parent",
                writer_id="writer-002",
                split="validation",
            )
            child = self._sample(
                data_root,
                sample_id="train-child",
                writer_id="writer-002",
                split="train",
                augmented=True,
                parent_sample_id="validation-parent",
            )
            manifest_path, _, _ = self._manifest(root, samples=[parent, child])
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("must remain in the same split" in error for error in report.errors))

    def test_forbidden_license_is_rejected_even_in_draft_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="licensed-digit",
                    writer_id="writer-001",
                    split="train",
                )
            ]
            manifest_path, _, manifest = self._manifest(root, samples=samples)
            manifest["provenance"]["sources"][0]["license"] = "GPL-3.0-only"
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("prohibited" in error for error in report.errors))

    def test_release_profile_fails_closed_without_the_real_corpus(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="one-digit",
                    writer_id="writer-001",
                    split="train",
                )
            ]
            manifest_path, _, _ = self._manifest(root, samples=samples)
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=True,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertTrue(any("at least 12 writers" in error for error in report.errors))
            self.assertTrue(any("distinct double-score values" in error for error in report.errors))

    def test_cli_emits_json_for_a_draft_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            samples = [
                self._sample(
                    data_root,
                    sample_id="cli-digit",
                    writer_id="writer-001",
                    split="train",
                )
            ]
            manifest_path, _, _ = self._manifest(root, samples=samples)
            process = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_DIR / "validate_dataset.py"),
                    "--manifest",
                    str(manifest_path),
                    "--data-root",
                    str(data_root),
                    "--mode",
                    "draft",
                    "--json",
                    "--repository-root",
                    str(root / "not-a-repository"),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            report = json.loads(process.stdout)
            self.assertTrue(report["ok"])
            self.assertEqual(report["mode"], "draft")

    def test_schema_is_valid_json_with_release_contract(self) -> None:
        schema = json.loads((TOOL_DIR / "dataset_manifest.schema.json").read_text(encoding="utf-8"))
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(schema["$defs"]["qualityGates"]["properties"]["minimum_writers"]["const"], 12)
        self.assertIn("samples", schema["required"])

    def test_malformed_json_types_return_errors_instead_of_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data_root = root / "private-corpus"
            data_root.mkdir()
            sample = self._sample(
                data_root,
                sample_id="malformed",
                writer_id="writer-001",
                split="train",
            )
            manifest_path, _, manifest = self._manifest(root, samples=[sample])
            manifest["provenance"]["privacy_review"] = []
            manifest["samples"][0]["writer_id"] = []
            manifest["samples"][0]["kind"] = []
            manifest["samples"][0]["augmentation"]["operations"] = [[]]
            manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")
            report = validate_manifest(
                manifest_path,
                data_root,
                require_complete_corpus=False,
                repository_root=None,
            )
            self.assertFalse(report.ok)
            self.assertGreaterEqual(len(report.errors), 3)


if __name__ == "__main__":
    unittest.main()
