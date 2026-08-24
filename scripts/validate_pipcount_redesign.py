#!/usr/bin/env python3
"""Static integrity checks for the production PipCount redesign."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "ScoreKeeper" / "Assets.xcassets"
PROJECT_FILE = ROOT / "ScoreKeeper.xcodeproj" / "project.pbxproj"

EXPECTED_ASSETS = {
    "PipCountHeroArtwork.imageset": "pipcount-hero-tabletop.svg",
    "PipCountEmptyStateArtwork.imageset": "pipcount-empty-tabletop.svg",
    "PipCountScoreEmblem.imageset": "pipcount-score-bauhaus.svg",
    "PipCountCrewEmblem.imageset": "pipcount-crew-tabletop.svg",
    "PipCountUnlimitedEmblem.imageset": "pipcount-unlimited-tabletop.svg",
    "PipCountCelebrationEmblem.imageset": "pipcount-celebration-tabletop.svg",
}

FORBIDDEN_VISUAL_TERMS = (
    "person",
    "people",
    "face",
    "pawn",
    "dice",
    "trophy",
    "game piece",
)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_assets() -> None:
    for imageset_name, expected_filename in EXPECTED_ASSETS.items():
        imageset = ASSET_ROOT / imageset_name
        contents_path = imageset / "Contents.json"
        if not contents_path.exists():
            fail(f"Missing asset metadata: {contents_path.relative_to(ROOT)}")

        try:
            contents = json.loads(contents_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"Invalid JSON in {contents_path.relative_to(ROOT)}: {error}")

        referenced = {
            image.get("filename")
            for image in contents.get("images", [])
            if image.get("filename")
        }
        if expected_filename not in referenced:
            fail(
                f"{imageset_name} must reference {expected_filename}; "
                f"found {sorted(referenced)}"
            )

        asset_path = imageset / expected_filename
        if not asset_path.exists():
            fail(f"Missing referenced vector: {asset_path.relative_to(ROOT)}")

        svg = asset_path.read_text(encoding="utf-8")
        lowered = svg.lower()
        if "<svg" not in lowered or "viewbox=" not in lowered:
            fail(f"Malformed SVG: {asset_path.relative_to(ROOT)}")
        if "<image" in lowered or "data:image" in lowered:
            fail(f"Embedded raster found in {asset_path.relative_to(ROOT)}")

        for term in FORBIDDEN_VISUAL_TERMS:
            if re.search(rf"\b{re.escape(term)}\b", lowered):
                fail(
                    f"Rejected figurative motif '{term}' found in "
                    f"{asset_path.relative_to(ROOT)}"
                )


def validate_motion_engine() -> None:
    swift_files = list((ROOT / "ScoreKeeper").rglob("*.swift"))
    geometric_sources = [
        path
        for path in swift_files
        if "PipCountGeometricArtwork" in path.read_text(encoding="utf-8")
    ]
    if not geometric_sources:
        fail("PipCountGeometricArtwork is missing from the app target")

    combined = "\n".join(path.read_text(encoding="utf-8") for path in geometric_sources)
    if "accessibilityReduceMotion" not in combined:
        fail("Animated artwork must respect Accessibility Reduce Motion")
    if "AppMotion.artEntrance" not in combined:
        fail("Animated artwork is not using the shared entrance motion token")

    content_view = ROOT / "ScoreKeeper" / "ContentView.swift"
    if content_view.exists():
        source = content_view.read_text(encoding="utf-8")
        if "AppMotion.artExit" not in source and "pageExit" not in source:
            fail("Root navigation does not expose coordinated exit choreography")


def validate_universal_target() -> None:
    if not PROJECT_FILE.exists():
        fail("Missing Xcode project file")

    project = PROJECT_FILE.read_text(encoding="utf-8")
    if not re.search(r'TARGETED_DEVICE_FAMILY\s*=\s*"?1,2"?;', project):
        fail("ScoreKeeper target must support both iPhone and iPad (device family 1,2)")


def validate_no_direct_rejected_asset_usage() -> None:
    for path in (ROOT / "ScoreKeeper").rglob("*.swift"):
        source = path.read_text(encoding="utf-8")
        if re.search(r'Image\(\s*"[^\"]*(dice|pawn|trophy|person)', source, re.IGNORECASE):
            fail(f"Rejected literal illustration referenced by {path.relative_to(ROOT)}")


def main() -> None:
    validate_assets()
    validate_motion_engine()
    validate_universal_target()
    validate_no_direct_rejected_asset_usage()
    print("PipCount redesign integrity checks passed.")


if __name__ == "__main__":
    main()
