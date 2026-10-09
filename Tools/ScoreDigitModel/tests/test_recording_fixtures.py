import hashlib
import json
import unittest
from pathlib import Path


class RecordingFixtureManifestTests(unittest.TestCase):
    def test_manifest_hashes_match_source_fixture_bytes(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        fixture_dir = repo_root / "ScoreKeeperTests" / "Fixtures" / "ScoreRecognition"
        manifest = json.loads((fixture_dir / "manifest.json").read_text())
        fixtures = manifest["fixtures"]

        manifest_files = {case["file"] for case in fixtures}
        source_files = {path.name for path in fixture_dir.glob("*.png")}
        self.assertEqual(manifest_files, source_files)

        for case in fixtures:
            path = fixture_dir / case["file"]
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(actual, case["sha256"], case["file"])


if __name__ == "__main__":
    unittest.main()
