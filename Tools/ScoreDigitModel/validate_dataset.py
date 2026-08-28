#!/usr/bin/env python3
"""Validate a PipCount score-digit dataset manifest and its files.

The validator deliberately has no third-party dependencies.  A draft manifest
can be checked while a corpus is being collected, but the default release
profile is fail-closed and requires the complete writer-disjoint corpus from
the recognition plan.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from urllib.parse import urlparse
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = Path(__file__).with_name("dataset_manifest.schema.json")
CLASS_NAMES = tuple(str(value) for value in range(10)) + ("reject",)
DIGIT_NAMES = CLASS_NAMES[:10]
REQUIRED_DOUBLE_SCORES = frozenset(
    {"11", "12", "20", "25", "37", "50", "69", "72", "90", "99"}
)
REQUIRED_REJECT_REASONS = frozenset(
    {"blank", "scribble", "partial_digit", "touching_digits", "unsupported_negative"}
)
SPLITS = ("train", "validation")
SAMPLE_KINDS = frozenset({"digit", "score", "reject"})
REJECT_REASONS = REQUIRED_REJECT_REASONS
ALLOWED_AUGMENTATIONS = frozenset(
    {"translation", "rotation", "scale", "width", "antialiasing"}
)
FORBIDDEN_LICENSE = re.compile(
    r"(?:\bAGPL\b|\bGPL\b|\bLGPL\b|GNU\s+General\s+Public\s+License|Affero)",
    re.IGNORECASE,
)
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
DOUBLE_SCORE = re.compile(r"^[1-9][0-9]$")


class DuplicateKeyError(ValueError):
    """Raised when a JSON object contains the same key more than once."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


@dataclass
class ValidationReport:
    """Machine-readable and human-readable validation result."""

    mode: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    stats: dict[str, Any] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.errors

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "mode": self.mode,
            "errors": self.errors,
            "warnings": self.warnings,
            "stats": self.stats,
        }


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value: Any) -> bool:
    return (isinstance(value, int) and not isinstance(value, bool)) or isinstance(
        value, float
    )


def _require_keys(value: dict[str, Any], required: Iterable[str], context: str, report: ValidationReport) -> None:
    for key in required:
        if key not in value:
            report.error(f"{context} is missing required field '{key}'")


def _check_unknown_keys(
    value: dict[str, Any], allowed: Iterable[str], context: str, report: ValidationReport
) -> None:
    allowed_set = set(allowed)
    for key in sorted(set(value) - allowed_set):
        report.error(f"{context} contains unknown field '{key}'")


def _check_id(value: Any, context: str, report: ValidationReport) -> bool:
    if not isinstance(value, str) or not ID.fullmatch(value):
        report.error(f"{context} must be a non-empty identifier matching {ID.pattern!r}")
        return False
    return True


def _check_nonempty_string(value: Any, context: str, report: ValidationReport) -> bool:
    if not isinstance(value, str) or not value.strip():
        report.error(f"{context} must be a non-empty string")
        return False
    return True


def _is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_relative_path(raw_path: Any, context: str, report: ValidationReport) -> bool:
    if not isinstance(raw_path, str) or not raw_path:
        report.error(f"{context} must be a non-empty relative POSIX path")
        return False
    if raw_path.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:[\\/]", raw_path):
        report.error(f"{context} must not be absolute")
        return False
    if "\\" in raw_path:
        report.error(f"{context} must use '/' separators")
        return False

    parts = PurePosixPath(raw_path).parts
    if not parts or any(part in {"", ".", ".."} for part in parts):
        report.error(f"{context} must not contain '.', '..', or empty path components")
        return False
    return True


def _validate_dataset_metadata(data: dict[str, Any], report: ValidationReport) -> None:
    dataset = data.get("dataset")
    if not isinstance(dataset, dict):
        report.error("dataset must be an object")
        return
    _check_unknown_keys(dataset, {"name", "version", "description", "classes"}, "dataset", report)
    _require_keys(dataset, {"name", "version", "description", "classes"}, "dataset", report)
    for field_name in ("name", "description"):
        if field_name in dataset:
            _check_nonempty_string(dataset[field_name], f"dataset.{field_name}", report)
    if "version" in dataset:
        _check_id(dataset["version"], "dataset.version", report)
    if dataset.get("classes") != list(CLASS_NAMES):
        report.error(
            "dataset.classes must be exactly ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'reject']"
        )


def _validate_provenance(data: dict[str, Any], report: ValidationReport) -> set[str]:
    provenance = data.get("provenance")
    source_ids: set[str] = set()
    if not isinstance(provenance, dict):
        report.error("provenance must be an object")
        return source_ids

    _check_unknown_keys(
        provenance,
        {"collection_protocol", "raw_samples_policy", "privacy_review", "sources"},
        "provenance",
        report,
    )
    _require_keys(
        provenance,
        {"collection_protocol", "raw_samples_policy", "privacy_review", "sources"},
        "provenance",
        report,
    )
    _check_nonempty_string(provenance.get("collection_protocol"), "provenance.collection_protocol", report)
    if provenance.get("raw_samples_policy") != "outside-git":
        report.error("provenance.raw_samples_policy must be 'outside-git'")
    if not isinstance(provenance.get("privacy_review"), str) or provenance.get(
        "privacy_review"
    ) not in {"pending", "approved", "rejected"}:
        report.error("provenance.privacy_review must be pending, approved, or rejected")

    sources = provenance.get("sources")
    if not isinstance(sources, list) or not sources:
        report.error("provenance.sources must be a non-empty array")
        return source_ids

    required_source_fields = {
        "source_id",
        "kind",
        "name",
        "version",
        "license",
        "license_url",
        "rights_status",
        "redistribution_allowed",
        "derivative_model_use_allowed",
        "attribution",
    }
    for index, source in enumerate(sources):
        context = f"provenance.sources[{index}]"
        if not isinstance(source, dict):
            report.error(f"{context} must be an object")
            continue
        _check_unknown_keys(source, required_source_fields, context, report)
        _require_keys(source, required_source_fields, context, report)
        source_id = source.get("source_id")
        if _check_id(source_id, f"{context}.source_id", report):
            if source_id in source_ids:
                report.error(f"duplicate source_id: {source_id}")
            source_ids.add(source_id)
        if not isinstance(source.get("kind"), str) or source.get("kind") not in {
            "first_party",
            "public",
        }:
            report.error(f"{context}.kind must be first_party or public")
        for field_name in ("name", "version", "license", "license_url", "attribution"):
            _check_nonempty_string(source.get(field_name), f"{context}.{field_name}", report)
        license_url = source.get("license_url")
        if isinstance(license_url, str):
            parsed_url = urlparse(license_url)
            if not parsed_url.scheme or not parsed_url.netloc:
                report.error(f"{context}.license_url must be an absolute URL")
        license_name = source.get("license")
        if isinstance(license_name, str) and FORBIDDEN_LICENSE.search(license_name):
            report.error(
                f"{context}.license is prohibited ({license_name!r}); do not use GPL/AGPL/LGPL data or weights"
            )
        if not isinstance(source.get("rights_status"), str) or source.get(
            "rights_status"
        ) not in {"pending", "approved", "rejected"}:
            report.error(f"{context}.rights_status must be pending, approved, or rejected")
        for field_name in ("redistribution_allowed", "derivative_model_use_allowed"):
            if not isinstance(source.get(field_name), bool):
                report.error(f"{context}.{field_name} must be a boolean")

    return source_ids


def _validate_writers(
    data: dict[str, Any], source_ids: set[str], report: ValidationReport
) -> tuple[set[str], dict[str, dict[str, Any]]]:
    writers = data.get("writers")
    writer_ids: set[str] = set()
    writer_by_id: dict[str, dict[str, Any]] = {}
    if not isinstance(writers, list):
        report.error("writers must be an array")
        return writer_ids, writer_by_id

    required_fields = {"writer_id", "source_id", "consent_status"}
    for index, writer in enumerate(writers):
        context = f"writers[{index}]"
        if not isinstance(writer, dict):
            report.error(f"{context} must be an object")
            continue
        _check_unknown_keys(writer, required_fields, context, report)
        _require_keys(writer, required_fields, context, report)
        writer_id = writer.get("writer_id")
        if _check_id(writer_id, f"{context}.writer_id", report):
            if writer_id in writer_ids:
                report.error(f"duplicate writer_id: {writer_id}")
            writer_ids.add(writer_id)
            writer_by_id[writer_id] = writer
        if not isinstance(writer.get("source_id"), str) or writer.get("source_id") not in source_ids:
            report.error(f"{context}.source_id references an unknown source")
        if not isinstance(writer.get("consent_status"), str) or writer.get(
            "consent_status"
        ) not in {"pending", "approved", "rejected"}:
            report.error(f"{context}.consent_status must be pending, approved, or rejected")

    return writer_ids, writer_by_id


def _validate_split_policy(
    data: dict[str, Any], writer_ids: set[str], report: ValidationReport
) -> tuple[set[str], set[str]]:
    policy = data.get("split_policy")
    if not isinstance(policy, dict):
        report.error("split_policy must be an object")
        return set(), set()

    required_fields = {
        "strategy",
        "seed",
        "validation_fraction",
        "augmentation_after_split",
        "hash_algorithm",
        "train_writer_ids",
        "validation_writer_ids",
    }
    _check_unknown_keys(policy, required_fields, "split_policy", report)
    _require_keys(policy, required_fields, "split_policy", report)
    if policy.get("strategy") != "writer-disjoint":
        report.error("split_policy.strategy must be 'writer-disjoint'")
    if not _is_int(policy.get("seed")) or policy.get("seed", -1) < 0:
        report.error("split_policy.seed must be a non-negative integer")
    fraction = policy.get("validation_fraction")
    if not _is_number(fraction) or not 0 < fraction < 1:
        report.error("split_policy.validation_fraction must be between 0 and 1")
    if policy.get("augmentation_after_split") is not True:
        report.error("split_policy.augmentation_after_split must be true")
    if policy.get("hash_algorithm") != "sha256":
        report.error("split_policy.hash_algorithm must be 'sha256'")

    parsed: list[set[str]] = []
    for field_name in ("train_writer_ids", "validation_writer_ids"):
        value = policy.get(field_name)
        if not isinstance(value, list):
            report.error(f"split_policy.{field_name} must be an array")
            parsed.append(set())
            continue
        ids: set[str] = set()
        for index, writer_id in enumerate(value):
            if _check_id(writer_id, f"split_policy.{field_name}[{index}]", report):
                if writer_id in ids:
                    report.error(f"duplicate writer_id in split_policy.{field_name}: {writer_id}")
                ids.add(writer_id)
                if writer_id not in writer_ids:
                    report.error(
                        f"split_policy.{field_name} references unknown writer_id: {writer_id}"
                    )
        parsed.append(ids)

    train_ids, validation_ids = parsed
    overlap = sorted(train_ids & validation_ids)
    if overlap:
        report.error(
            "split_policy assigns writers to both splits: " + ", ".join(overlap)
        )
    return train_ids, validation_ids


def _validate_reproducibility(data: dict[str, Any], report: ValidationReport) -> None:
    reproducibility = data.get("reproducibility")
    if not isinstance(reproducibility, dict):
        report.error("reproducibility must be an object")
        return
    required_fields = {
        "seed",
        "python_version",
        "preprocessing_version",
        "augmentation_version",
        "deterministic",
    }
    _check_unknown_keys(reproducibility, required_fields, "reproducibility", report)
    _require_keys(reproducibility, required_fields, "reproducibility", report)
    if not _is_int(reproducibility.get("seed")) or reproducibility.get("seed", -1) < 0:
        report.error("reproducibility.seed must be a non-negative integer")
    for field_name in ("python_version", "preprocessing_version", "augmentation_version"):
        _check_nonempty_string(reproducibility.get(field_name), f"reproducibility.{field_name}", report)
    if reproducibility.get("deterministic") is not True:
        report.error("reproducibility.deterministic must be true")

    policy = data.get("split_policy")
    if isinstance(policy, dict) and _is_int(policy.get("seed")) and _is_int(reproducibility.get("seed")):
        if policy["seed"] != reproducibility["seed"]:
            report.error("split_policy.seed and reproducibility.seed must match")


def _validate_quality_gates(data: dict[str, Any], report: ValidationReport) -> dict[str, Any]:
    gates = data.get("quality_gates")
    if not isinstance(gates, dict):
        report.error("quality_gates must be an object")
        return {}
    required_fields = {
        "minimum_writers",
        "minimum_digit_examples_per_writer",
        "minimum_double_scores_per_writer",
        "required_double_scores",
        "required_reject_reasons",
        "label_balance",
    }
    _check_unknown_keys(gates, required_fields, "quality_gates", report)
    _require_keys(gates, required_fields, "quality_gates", report)
    if not _is_int(gates.get("minimum_writers")) or gates.get("minimum_writers") != 12:
        report.error("quality_gates.minimum_writers must be 12")
    if not _is_int(gates.get("minimum_digit_examples_per_writer")) or gates.get(
        "minimum_digit_examples_per_writer", 0
    ) < 2:
        report.error("quality_gates.minimum_digit_examples_per_writer must be at least 2")
    if not _is_int(gates.get("minimum_double_scores_per_writer")) or gates.get(
        "minimum_double_scores_per_writer", 0
    ) < 12:
        report.error("quality_gates.minimum_double_scores_per_writer must be at least 12")

    configured_scores = gates.get("required_double_scores")
    if not isinstance(configured_scores, list):
        report.error("quality_gates.required_double_scores must be an array")
    else:
        configured_score_set: set[str] = set()
        for index, score in enumerate(configured_scores):
            if not isinstance(score, str) or not DOUBLE_SCORE.fullmatch(score):
                report.error(f"quality_gates.required_double_scores[{index}] is not a two-digit score")
            elif isinstance(score, str):
                configured_score_set.add(score)
        missing = sorted(REQUIRED_DOUBLE_SCORES - configured_score_set)
        if missing:
            report.error(
                "quality_gates.required_double_scores is missing: " + ", ".join(missing)
            )

    configured_reject_reasons = gates.get("required_reject_reasons")
    configured_reject_reason_set = (
        {reason for reason in configured_reject_reasons if isinstance(reason, str)}
        if isinstance(configured_reject_reasons, list)
        else set()
    )
    if configured_reject_reason_set != REQUIRED_REJECT_REASONS:
        report.error(
            "quality_gates.required_reject_reasons must include blank, scribble, partial_digit, "
            "touching_digits, and unsupported_negative"
        )

    balance = gates.get("label_balance")
    if not isinstance(balance, dict):
        report.error("quality_gates.label_balance must be an object")
        return gates
    balance_fields = {
        "minimum_examples_per_digit_per_split",
        "maximum_digit_imbalance_ratio",
        "minimum_reject_examples_per_split",
    }
    _check_unknown_keys(balance, balance_fields, "quality_gates.label_balance", report)
    _require_keys(balance, balance_fields, "quality_gates.label_balance", report)
    if not _is_int(balance.get("minimum_examples_per_digit_per_split")) or balance.get(
        "minimum_examples_per_digit_per_split", 0
    ) < 2:
        report.error(
            "quality_gates.label_balance.minimum_examples_per_digit_per_split must be at least 2"
        )
    ratio = balance.get("maximum_digit_imbalance_ratio")
    if not _is_number(ratio) or not 1 <= ratio <= 2:
        report.error(
            "quality_gates.label_balance.maximum_digit_imbalance_ratio must be between 1 and 2"
        )
    if not _is_int(balance.get("minimum_reject_examples_per_split")) or balance.get(
        "minimum_reject_examples_per_split", 0
    ) < 1:
        report.error(
            "quality_gates.label_balance.minimum_reject_examples_per_split must be at least 1"
        )
    return gates


def _validate_sample_shape(
    sample: Any,
    index: int,
    source_ids: set[str],
    writer_ids: set[str],
    report: ValidationReport,
) -> dict[str, Any] | None:
    context = f"samples[{index}]"
    if not isinstance(sample, dict):
        report.error(f"{context} must be an object")
        return None

    required_fields = {
        "sample_id",
        "path",
        "sha256",
        "writer_id",
        "split",
        "source_id",
        "kind",
        "label",
        "score",
        "reject_reason",
        "augmentation",
    }
    # label, score, and reject_reason are conditional fields; all other fields
    # are required for every sample.
    always_required = {
        "sample_id",
        "path",
        "sha256",
        "writer_id",
        "split",
        "source_id",
        "kind",
        "augmentation",
    }
    _check_unknown_keys(sample, required_fields, context, report)
    _require_keys(sample, always_required, context, report)

    sample_id = sample.get("sample_id")
    _check_id(sample_id, f"{context}.sample_id", report)
    _safe_relative_path(sample.get("path"), f"{context}.path", report)
    if not isinstance(sample.get("sha256"), str) or not SHA256.fullmatch(sample.get("sha256", "")):
        report.error(f"{context}.sha256 must be a 64-character SHA-256 hex digest")
    writer_id = sample.get("writer_id")
    if _check_id(writer_id, f"{context}.writer_id", report) and writer_id not in writer_ids:
        report.error(f"{context}.writer_id references an unknown writer_id: {writer_id}")
    if sample.get("split") not in SPLITS:
        report.error(f"{context}.split must be train or validation")
    source_id = sample.get("source_id")
    if (
        _check_id(source_id, f"{context}.source_id", report)
        and source_id not in source_ids
    ):
        report.error(f"{context}.source_id references an unknown source_id: {source_id}")

    kind = sample.get("kind")
    if not isinstance(kind, str) or kind not in SAMPLE_KINDS:
        report.error(f"{context}.kind must be digit, score, or reject")
    elif kind == "digit":
        label = sample.get("label")
        if label not in DIGIT_NAMES:
            report.error(f"{context}.label must be a digit for kind=digit")
        if "score" in sample or "reject_reason" in sample:
            report.error(f"{context} kind=digit must not contain score or reject_reason")
    elif kind == "score":
        score = sample.get("score")
        if not isinstance(score, str) or not DOUBLE_SCORE.fullmatch(score):
            report.error(f"{context}.score must be a two-digit score from 10 through 99")
        if "label" in sample or "reject_reason" in sample:
            report.error(f"{context} kind=score must not contain label or reject_reason")
    elif kind == "reject":
        if sample.get("label") != "reject":
            report.error(f"{context}.label must be 'reject' for kind=reject")
        if not isinstance(sample.get("reject_reason"), str) or sample.get(
            "reject_reason"
        ) not in REJECT_REASONS:
            report.error(f"{context}.reject_reason is not a supported rejection reason")
        if "score" in sample:
            report.error(f"{context} kind=reject must not contain score")

    augmentation = sample.get("augmentation")
    if not isinstance(augmentation, dict):
        report.error(f"{context}.augmentation must be an object")
    else:
        augmentation_fields = {"is_augmented", "parent_sample_id", "operations"}
        _check_unknown_keys(augmentation, augmentation_fields, f"{context}.augmentation", report)
        _require_keys(augmentation, augmentation_fields, f"{context}.augmentation", report)
        is_augmented = augmentation.get("is_augmented")
        if not isinstance(is_augmented, bool):
            report.error(f"{context}.augmentation.is_augmented must be a boolean")
        parent_id = augmentation.get("parent_sample_id")
        operations = augmentation.get("operations")
        if not isinstance(operations, list):
            report.error(f"{context}.augmentation.operations must be an array")
        else:
            for operation in operations:
                if not isinstance(operation, str) or operation not in ALLOWED_AUGMENTATIONS:
                    report.error(
                        f"{context}.augmentation.operations contains unsupported operation: {operation}"
                    )
        if is_augmented is True:
            if not isinstance(parent_id, str) or not parent_id:
                report.error(f"{context}.augmentation.parent_sample_id is required for augmented samples")
            if isinstance(operations, list) and not operations:
                report.error(f"{context}.augmentation.operations must not be empty for augmented samples")
        elif is_augmented is False:
            if parent_id is not None:
                report.error(f"{context}.augmentation.parent_sample_id must be null for raw samples")
            if isinstance(operations, list) and operations:
                report.error(f"{context}.augmentation.operations must be empty for raw samples")

    return sample


def _validate_sample_files(
    samples: list[dict[str, Any]],
    data_root: Path,
    check_files: bool,
    report: ValidationReport,
) -> None:
    seen_hashes: dict[str, tuple[str, str]] = {}
    seen_paths: dict[str, str] = {}
    for sample in samples:
        sample_id = sample.get("sample_id", "<unknown>")
        raw_path = sample.get("path")
        if not isinstance(raw_path, str) or not _safe_relative_path(
            raw_path, f"samples[{sample_id}].path", report
        ):
            continue
        declared_hash = sample.get("sha256")
        split = sample.get("split", "<unknown>")
        previous_path_sample = seen_paths.get(raw_path)
        if previous_path_sample:
            report.error(
                f"duplicate sample path {raw_path!r} is used by {previous_path_sample} and {sample_id}"
            )
        seen_paths[raw_path] = sample_id
        if isinstance(declared_hash, str) and SHA256.fullmatch(declared_hash):
            previous = seen_hashes.get(declared_hash.lower())
            if previous:
                previous_id, previous_split = previous
                if previous_split != split:
                    report.error(
                        f"duplicate hash across splits: {previous_id} ({previous_split}) and "
                        f"{sample_id} ({split}) share {declared_hash}"
                    )
                else:
                    report.error(
                        f"duplicate sample hash within {split}: {previous_id} and {sample_id} share {declared_hash}"
                    )
            else:
                seen_hashes[declared_hash.lower()] = (sample_id, split)

        if not check_files:
            continue
        if not isinstance(raw_path, str):
            continue
        candidate = (data_root / PurePosixPath(raw_path)).resolve(strict=False)
        if not _is_within(candidate, data_root):
            report.error(f"sample {sample_id} resolves outside data root: {raw_path}")
            continue
        if not candidate.is_file():
            report.error(f"sample file is missing or not a regular file: {raw_path}")
            continue
        if isinstance(declared_hash, str) and SHA256.fullmatch(declared_hash):
            actual_hash = _sha256_file(candidate)
            if actual_hash.lower() != declared_hash.lower():
                report.error(
                    f"SHA-256 mismatch for {sample_id}: manifest={declared_hash}, actual={actual_hash}"
                )


def _validate_lineage(samples: list[dict[str, Any]], report: ValidationReport) -> None:
    by_id = {
        sample.get("sample_id"): sample
        for sample in samples
        if isinstance(sample.get("sample_id"), str) and sample.get("sample_id")
    }
    for sample in samples:
        sample_id = sample.get("sample_id", "<unknown>")
        augmentation = sample.get("augmentation")
        if not isinstance(augmentation, dict) or augmentation.get("is_augmented") is not True:
            continue
        parent_id = augmentation.get("parent_sample_id")
        if not isinstance(parent_id, str):
            continue
        parent = by_id.get(parent_id)
        if parent is None:
            report.error(f"sample {sample_id} references missing augmentation parent: {parent_id}")
            continue
        if parent.get("writer_id") != sample.get("writer_id"):
            report.error(f"augmented sample {sample_id} changes writer from its parent {parent_id}")
        if parent.get("split") != sample.get("split"):
            report.error(
                f"augmented sample {sample_id} and parent {parent_id} must remain in the same split"
            )

        seen: set[str] = set()
        current = sample
        while isinstance(current, dict):
            current_id = current.get("sample_id")
            if not isinstance(current_id, str):
                break
            if current_id in seen:
                report.error(f"augmentation lineage cycle includes sample {current_id}")
                break
            seen.add(current_id)
            current_augmentation = current.get("augmentation")
            if not isinstance(current_augmentation, dict) or current_augmentation.get(
                "is_augmented"
            ) is not True:
                break
            next_id = current_augmentation.get("parent_sample_id")
            if not isinstance(next_id, str):
                break
            current = by_id.get(next_id)
            if current is None:
                break


def _release_gate(
    data: dict[str, Any],
    samples: list[dict[str, Any]],
    writer_ids: set[str],
    writer_by_id: dict[str, dict[str, Any]],
    source_by_id: dict[str, dict[str, Any]],
    train_writer_ids: set[str],
    validation_writer_ids: set[str],
    data_root: Path,
    repository_root: Path | None,
    report: ValidationReport,
) -> None:
    """Apply the non-negotiable corpus and release checks."""

    used_writer_ids = {
        sample.get("writer_id")
        for sample in samples
        if isinstance(sample.get("writer_id"), str) and sample.get("writer_id")
    }
    if len(used_writer_ids) < 12:
        report.error(
            f"release corpus gate: requires at least 12 writers, found {len(used_writer_ids)}"
        )
    if not train_writer_ids:
        report.error("release split gate: train_writer_ids must not be empty")
    if not validation_writer_ids:
        report.error("release split gate: validation_writer_ids must not be empty")
    if used_writer_ids != writer_ids:
        unused = sorted(writer_ids - used_writer_ids)
        unregistered = sorted(used_writer_ids - writer_ids)
        if unused:
            report.error("release corpus gate: writers without samples: " + ", ".join(unused))
        if unregistered:
            report.error(
                "release corpus gate: samples use unregistered writers: " + ", ".join(unregistered)
            )

    provenance = data.get("provenance")
    if isinstance(provenance, dict) and provenance.get("privacy_review") != "approved":
        report.error("release provenance gate: provenance.privacy_review must be approved")
    if isinstance(provenance, dict) and provenance.get("raw_samples_policy") != "outside-git":
        report.error("release privacy gate: raw samples must be stored outside Git")
    if repository_root is not None and _is_within(data_root, repository_root.resolve()):
        report.error(
            f"release privacy gate: data root {data_root} is inside repository {repository_root.resolve()}"
        )

    for source_id, source in source_by_id.items():
        if source.get("rights_status") != "approved":
            report.error(f"release provenance gate: source {source_id} rights_status is not approved")
        if source.get("derivative_model_use_allowed") is not True:
            report.error(
                f"release licensing gate: source {source_id} does not allow derivative model use"
            )
    for writer_id, writer in writer_by_id.items():
        if writer.get("consent_status") != "approved":
            report.error(f"release privacy gate: writer {writer_id} consent_status is not approved")

    gates = data.get("quality_gates")
    if not isinstance(gates, dict):
        return
    configured_min_digits = gates.get("minimum_digit_examples_per_writer")
    min_digits = configured_min_digits if _is_int(configured_min_digits) else 2
    configured_min_scores = gates.get("minimum_double_scores_per_writer")
    min_scores = configured_min_scores if _is_int(configured_min_scores) else 12
    raw_required_scores = gates.get("required_double_scores")
    required_scores = {
        score
        for score in (raw_required_scores if isinstance(raw_required_scores, list) else ())
        if isinstance(score, str)
    }
    balance = gates.get("label_balance")
    min_per_split = 2
    max_ratio = 2.0
    min_reject_per_split = 1
    if isinstance(balance, dict):
        configured_min_per_split = balance.get("minimum_examples_per_digit_per_split")
        if _is_int(configured_min_per_split):
            min_per_split = configured_min_per_split
        configured_max_ratio = balance.get("maximum_digit_imbalance_ratio")
        if _is_number(configured_max_ratio):
            max_ratio = configured_max_ratio
        configured_min_reject = balance.get("minimum_reject_examples_per_split")
        if _is_int(configured_min_reject):
            min_reject_per_split = configured_min_reject

    digit_counts_by_writer: dict[str, Counter[str]] = defaultdict(Counter)
    score_values_by_writer: dict[str, set[str]] = defaultdict(set)
    reject_reasons = set()
    split_label_counts: dict[str, Counter[str]] = {split: Counter() for split in SPLITS}
    split_writer_ids: dict[str, set[str]] = {split: set() for split in SPLITS}
    for sample in samples:
        writer_id = sample.get("writer_id")
        split = sample.get("split")
        kind = sample.get("kind")
        if isinstance(split, str) and split in split_writer_ids and isinstance(writer_id, str) and writer_id:
            split_writer_ids[split].add(writer_id)
        if (
            kind == "digit"
            and isinstance(writer_id, str)
            and sample.get("label") in DIGIT_NAMES
        ):
            digit_counts_by_writer[writer_id][sample["label"]] += 1
            if isinstance(split, str) and split in split_label_counts:
                split_label_counts[split][sample["label"]] += 1
        elif (
            kind == "score"
            and isinstance(writer_id, str)
            and isinstance(sample.get("score"), str)
        ):
            score_values_by_writer[writer_id].add(sample["score"])
        elif kind == "reject" and isinstance(sample.get("reject_reason"), str):
            reject_reasons.add(sample["reject_reason"])
            if isinstance(split, str) and split in split_label_counts:
                split_label_counts[split]["reject"] += 1

    for writer_id in sorted(used_writer_ids):
        digit_counts = digit_counts_by_writer[writer_id]
        missing_digits = [
            digit for digit in DIGIT_NAMES if digit_counts.get(digit, 0) < min_digits
        ]
        if missing_digits:
            report.error(
                f"release label gate: writer {writer_id} has fewer than {min_digits} examples "
                f"for digit(s): {', '.join(missing_digits)}"
            )
        if len(score_values_by_writer[writer_id]) < min_scores:
            report.error(
                f"release composition gate: writer {writer_id} has "
                f"{len(score_values_by_writer[writer_id])} distinct double-score values; "
                f"requires at least {min_scores}"
            )
        missing_scores = sorted(required_scores - score_values_by_writer[writer_id])
        if missing_scores:
            report.error(
                f"release composition gate: writer {writer_id} is missing double score(s): "
                + ", ".join(missing_scores)
            )

    missing_reject_reasons = sorted(REQUIRED_REJECT_REASONS - reject_reasons)
    if missing_reject_reasons:
        report.error(
            "release rejection gate: missing reject reason(s): " + ", ".join(missing_reject_reasons)
        )

    for split in SPLITS:
        counts = split_label_counts[split]
        missing_digits = [
            digit for digit in DIGIT_NAMES if counts.get(digit, 0) < min_per_split
        ]
        if missing_digits:
            report.error(
                f"release balance gate: {split} has fewer than {min_per_split} examples for digit(s): "
                + ", ".join(missing_digits)
            )
        digit_values = [counts.get(digit, 0) for digit in DIGIT_NAMES]
        if all(digit_values):
            ratio = max(digit_values) / min(digit_values)
            if ratio > max_ratio:
                report.error(
                    f"release balance gate: {split} digit imbalance ratio {ratio:.3f} exceeds {max_ratio:.3f}"
                )
        if counts.get("reject", 0) < min_reject_per_split:
            report.error(
                f"release rejection gate: {split} has {counts.get('reject', 0)} reject examples; "
                f"requires at least {min_reject_per_split}"
            )

    if train_writer_ids and validation_writer_ids:
        actual_train = split_writer_ids["train"]
        actual_validation = split_writer_ids["validation"]
        if actual_train != train_writer_ids:
            report.error(
                "release split gate: train writer list does not match sample assignments"
            )
        if actual_validation != validation_writer_ids:
            report.error(
                "release split gate: validation writer list does not match sample assignments"
            )


def _source_map(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    provenance = data.get("provenance")
    if not isinstance(provenance, dict) or not isinstance(provenance.get("sources"), list):
        return {}
    return {
        source.get("source_id"): source
        for source in provenance["sources"]
        if isinstance(source, dict)
        and isinstance(source.get("source_id"), str)
        and source.get("source_id")
    }


def validate_manifest(
    manifest_path: Path,
    data_root: Path | None = None,
    *,
    require_complete_corpus: bool = True,
    check_files: bool = True,
    repository_root: Path | None = ROOT,
) -> ValidationReport:
    """Validate a manifest.

    ``require_complete_corpus=False`` is intended only for draft collection
    and unit tests.  It still checks schema shape, references, hashes, and
    writer-disjointness; it simply does not require the 12-writer release gate.
    """

    mode = "release" if require_complete_corpus else "draft"
    report = ValidationReport(mode=mode)
    manifest_path = Path(manifest_path).expanduser().resolve()
    data_root = (Path(data_root).expanduser() if data_root else manifest_path.parent).resolve()

    try:
        with manifest_path.open("r", encoding="utf-8") as stream:
            data = json.load(stream, object_pairs_hook=_reject_duplicate_keys)
    except FileNotFoundError:
        report.error(f"manifest file does not exist: {manifest_path}")
        return report
    except (OSError, json.JSONDecodeError, DuplicateKeyError) as error:
        report.error(f"could not parse manifest {manifest_path}: {error}")
        return report

    if not isinstance(data, dict):
        report.error("manifest root must be an object")
        return report

    root_fields = {
        "schema_version",
        "dataset",
        "provenance",
        "split_policy",
        "reproducibility",
        "quality_gates",
        "writers",
        "samples",
    }
    _check_unknown_keys(data, root_fields, "manifest", report)
    _require_keys(data, root_fields, "manifest", report)
    if not _is_int(data.get("schema_version")) or data.get("schema_version") != 1:
        report.error("schema_version must be 1")

    _validate_dataset_metadata(data, report)
    source_ids = _validate_provenance(data, report)
    writer_ids, writer_by_id = _validate_writers(data, source_ids, report)
    train_writer_ids, validation_writer_ids = _validate_split_policy(data, writer_ids, report)
    _validate_reproducibility(data, report)
    _validate_quality_gates(data, report)

    raw_samples = data.get("samples")
    samples: list[dict[str, Any]] = []
    if not isinstance(raw_samples, list):
        report.error("samples must be an array")
    else:
        seen_ids: set[str] = set()
        for index, sample in enumerate(raw_samples):
            parsed = _validate_sample_shape(sample, index, source_ids, writer_ids, report)
            if parsed is None:
                continue
            sample_id = parsed.get("sample_id")
            if isinstance(sample_id, str):
                if sample_id in seen_ids:
                    report.error(f"duplicate sample_id: {sample_id}")
                seen_ids.add(sample_id)
            samples.append(parsed)

    _validate_sample_files(samples, data_root, check_files, report)
    _validate_lineage(samples, report)

    used_writer_splits: dict[str, set[str]] = defaultdict(set)
    for sample in samples:
        writer_id = sample.get("writer_id")
        split = sample.get("split")
        if isinstance(writer_id, str) and writer_id and split in SPLITS:
            used_writer_splits[writer_id].add(split)
    for writer_id, splits in sorted(used_writer_splits.items()):
        if len(splits) > 1:
            report.error(
                f"writer leakage: writer {writer_id} appears in both train and validation"
            )
        if writer_id not in train_writer_ids | validation_writer_ids:
            report.error(
                f"split policy omission: writer {writer_id} is not assigned to train or validation"
            )
        if writer_id in train_writer_ids and "validation" in splits:
            report.error(f"split policy leakage: train writer {writer_id} has validation samples")
        if writer_id in validation_writer_ids and "train" in splits:
            report.error(f"split policy leakage: validation writer {writer_id} has train samples")

    if require_complete_corpus:
        _release_gate(
            data,
            samples,
            writer_ids,
            writer_by_id,
            _source_map(data),
            train_writer_ids,
            validation_writer_ids,
            data_root,
            repository_root,
            report,
        )
    else:
        provenance = data.get("provenance")
        if isinstance(provenance, dict) and provenance.get("privacy_review") != "approved":
            report.warning("draft manifest has not completed privacy review")
        for source_id, source in _source_map(data).items():
            if source.get("rights_status") != "approved":
                report.warning(f"draft source {source_id} rights_status is not approved")

    label_counts = {split: Counter() for split in SPLITS}
    kind_counts = {split: Counter() for split in SPLITS}
    for sample in samples:
        split = sample.get("split")
        kind = sample.get("kind")
        if isinstance(split, str) and split in SPLITS and isinstance(kind, str):
            kind_counts[split][kind] += 1
            if kind == "digit" and sample.get("label") in DIGIT_NAMES:
                label_counts[split][sample["label"]] += 1
            elif kind == "reject":
                label_counts[split]["reject"] += 1
    report.stats = {
        "sample_count": len(samples),
        "writer_count": len(
            {
                sample.get("writer_id")
                for sample in samples
                if isinstance(sample.get("writer_id"), str) and sample.get("writer_id")
            }
        ),
        "registered_writer_count": len(writer_ids),
        "writers_by_split": {
            "train": len(
                {
                    sample.get("writer_id")
                    for sample in samples
                    if isinstance(sample.get("writer_id"), str)
                    and sample.get("writer_id")
                    and sample.get("split") == "train"
                }
            ),
            "validation": len(
                {
                    sample.get("writer_id")
                    for sample in samples
                    if isinstance(sample.get("writer_id"), str)
                    and sample.get("writer_id")
                    and sample.get("split") == "validation"
                }
            ),
        },
        "kind_counts": {split: dict(counts) for split, counts in kind_counts.items()},
        "classifier_label_counts": {
            split: dict(counts) for split, counts in label_counts.items()
        },
        "data_root": str(data_root),
        "files_checked": check_files,
    }
    return report


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate a PipCount writer-disjoint score digit manifest."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        required=True,
        help="JSON manifest to validate",
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        help="directory containing paths in the manifest (default: manifest directory)",
    )
    parser.add_argument(
        "--mode",
        choices=("draft", "release"),
        default="release",
        help="draft checks structure and leakage; release also enforces the 12-writer gate",
    )
    parser.add_argument(
        "--skip-file-checks",
        action="store_true",
        help="do not read sample files or verify their SHA-256 hashes",
    )
    parser.add_argument(
        "--repository-root",
        type=Path,
        default=ROOT,
        help="repository root used to reject in-repository raw data in release mode",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="as_json",
        help="emit a machine-readable report",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    report = validate_manifest(
        args.manifest,
        args.data_root,
        require_complete_corpus=args.mode == "release",
        check_files=not args.skip_file_checks,
        repository_root=args.repository_root,
    )
    if args.as_json:
        print(json.dumps(report.as_dict(), indent=2, sort_keys=True))
    else:
        status = "PASS" if report.ok else "BLOCKED"
        print(f"{status}: {args.mode} dataset validation")
        for error in report.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        for warning in report.warnings:
            print(f"WARNING: {warning}", file=sys.stderr)
        if report.stats:
            print(
                "Samples: {sample_count}; writers: {writer_count}; train/validation writers: "
                "{train}/{validation}".format(
                    sample_count=report.stats["sample_count"],
                    writer_count=report.stats["writer_count"],
                    train=report.stats["writers_by_split"]["train"],
                    validation=report.stats["writers_by_split"]["validation"],
                )
            )
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
