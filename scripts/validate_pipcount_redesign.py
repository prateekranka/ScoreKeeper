#!/usr/bin/env python3
"""Static integrity checks for the production PipCount redesign."""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "ScoreKeeper"
ASSET_ROOT = APP_ROOT / "Assets.xcassets"
PROJECT_FILE = ROOT / "ScoreKeeper.xcodeproj" / "project.pbxproj"

PRODUCTION_SCENES = {
    "home",
    "homeEmpty",
    "gamePicker",
    "playerSetup",
    "gameSettings",
    "handwriting",
    "scoring",
    "gameOver",
    "paywall",
    "onboardingScore",
    "onboardingSetup",
    "onboardingHistory",
    "roster",
}

KEY_SCREEN_SCENES = {
    "Views/Home/HomeView.swift": {"home", "homeEmpty", "roster"},
    "Views/Setup/GamePickerView.swift": {"gamePicker"},
    "Views/Setup/PlayerSetupView.swift": {"playerSetup"},
    "Views/Setup/GameConfigView.swift": {"gameSettings"},
    "Views/Scoring/RoundEntryDeckView.swift": {"handwriting"},
    "Views/Components/ScoringComponents.swift": {"scoring"},
    "Views/Summary/GameOverView.swift": {"gameOver"},
    "Views/Paywall/PaywallView.swift": {"paywall"},
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


def validate_asset_catalog() -> None:
    """Ensure every catalog entry is valid and every referenced file exists.

    PipCount's production illustrations are native SwiftUI geometry. The legacy
    image sets remain for compatibility and App Store material, but no specific
    raster or vector filename is required by the runtime design system.
    """

    for contents_path in ASSET_ROOT.rglob("Contents.json"):
        try:
            contents = json.loads(contents_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"Invalid JSON in {contents_path.relative_to(ROOT)}: {error}")

        for image in contents.get("images", []):
            filename = image.get("filename")
            if not filename:
                continue

            asset_path = contents_path.parent / filename
            if not asset_path.exists():
                fail(
                    f"Missing asset referenced by {contents_path.relative_to(ROOT)}: "
                    f"{filename}"
                )

            if asset_path.suffix.lower() != ".svg":
                continue

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
    artwork_path = APP_ROOT / "Views" / "Components" / "ClubhouseComponents.swift"
    if not artwork_path.exists():
        fail("ClubhouseComponents.swift is missing")

    source = artwork_path.read_text(encoding="utf-8")
    if "struct PipCountGeometricArtwork" not in source:
        fail("PipCountGeometricArtwork is missing from the app target")
    if "accessibilityReduceMotion" not in source:
        fail("Animated artwork must respect Accessibility Reduce Motion")
    if "AppMotion.artEntrance" not in source:
        fail("Animated artwork is not using the shared entrance motion token")
    if "pipCountPageIsExiting" not in source:
        fail("Animated artwork is not connected to coordinated page exits")
    if "TimelineView" not in source:
        fail("Animated artwork is missing its restrained ambient timeline")

    declared_scenes = set(
        re.findall(r"^\s*case\s+([A-Za-z][A-Za-z0-9_]*)\s*$", source, re.MULTILINE)
    )
    missing_scenes = sorted(PRODUCTION_SCENES - declared_scenes)
    if missing_scenes:
        fail(f"Missing production artwork scenes: {', '.join(missing_scenes)}")

    content_view = APP_ROOT / "App" / "ContentView.swift"
    root_source = content_view.read_text(encoding="utf-8")
    if "isPageExiting" not in root_source or "pipCountPageIsExiting" not in root_source:
        fail("Root navigation does not coordinate page exit choreography")


def validate_key_screen_routing() -> None:
    for relative_path, scenes in KEY_SCREEN_SCENES.items():
        path = APP_ROOT / relative_path
        if not path.exists():
            fail(f"Missing production screen: {path.relative_to(ROOT)}")

        source = path.read_text(encoding="utf-8")
        for scene in scenes:
            if f"scene: .{scene}" not in source:
                fail(
                    f"{path.relative_to(ROOT)} is not routed to the .{scene} "
                    "Bauhaus composition"
                )


def validate_universal_target() -> None:
    if not PROJECT_FILE.exists():
        fail("Missing Xcode project file")

    project = PROJECT_FILE.read_text(encoding="utf-8")
    if not re.search(r'TARGETED_DEVICE_FAMILY\s*=\s*"?1,2"?;', project):
        fail("ScoreKeeper target must support both iPhone and iPad (device family 1,2)")


def validate_no_direct_rejected_asset_usage() -> None:
    for path in APP_ROOT.rglob("*.swift"):
        source = path.read_text(encoding="utf-8")
        if re.search(
            r'Image\(\s*"[^\"]*(dice|pawn|trophy|person)',
            source,
            re.IGNORECASE,
        ):
            fail(f"Rejected literal illustration referenced by {path.relative_to(ROOT)}")


def validate_unique_public_view_types() -> None:
    """Catch accidentally duplicated app screens in synchronized Xcode groups."""

    declarations: dict[str, list[Path]] = defaultdict(list)
    pattern = re.compile(
        r"^(?!\s*(?:private|fileprivate)\s+)\s*(?:final\s+)?(?:struct|class|enum)\s+"
        r"([A-Za-z][A-Za-z0-9_]*)",
        re.MULTILINE,
    )

    for path in (APP_ROOT / "Views").rglob("*.swift"):
        source = path.read_text(encoding="utf-8")
        for name in pattern.findall(source):
            declarations[name].append(path)

    duplicates = {
        name: paths
        for name, paths in declarations.items()
        if len(paths) > 1
    }
    if duplicates:
        details = "; ".join(
            f"{name}: {', '.join(str(path.relative_to(ROOT)) for path in paths)}"
            for name, paths in sorted(duplicates.items())
        )
        fail(f"Duplicate public view types found: {details}")


def main() -> None:
    validate_asset_catalog()
    validate_motion_engine()
    validate_key_screen_routing()
    validate_universal_target()
    validate_no_direct_rejected_asset_usage()
    validate_unique_public_view_types()
    print("PipCount redesign integrity checks passed.")


if __name__ == "__main__":
    main()
