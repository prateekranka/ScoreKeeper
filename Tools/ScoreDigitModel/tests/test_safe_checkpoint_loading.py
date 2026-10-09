from __future__ import annotations

import sys
import unittest
from pathlib import Path
from typing import Any

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import evaluate  # noqa: E402
import export_coreml  # noqa: E402


class FakeTorch:
    def __init__(self, result: Any) -> None:
        self.result = result
        self.calls: list[tuple[Path, dict[str, Any]]] = []

    def load(self, path: Path, **kwargs: Any) -> Any:
        self.calls.append((path, kwargs))
        return self.result


class SafeCheckpointLoadingTests(unittest.TestCase):
    def test_evaluator_uses_restricted_checkpoint_loading(self) -> None:
        self._assert_restricted_load(evaluate._load_checkpoint)

    def test_exporter_uses_restricted_checkpoint_loading(self) -> None:
        self._assert_restricted_load(export_coreml._load_checkpoint)

    def _assert_restricted_load(self, loader: Any) -> None:
        checkpoint = {"state_dict": {}}
        torch = FakeTorch(checkpoint)
        path = Path("checkpoint.pt")

        self.assertIs(loader(torch, path), checkpoint)
        self.assertEqual(
            torch.calls,
            [(path, {"map_location": "cpu", "weights_only": True})],
        )


if __name__ == "__main__":
    unittest.main()
