# PipCount break-ui audit

The fixture selector is compiled only for DEBUG. Launch with both `-in-memory-store` and `-break-ui-data` to show **Demo data / Worst case** at the top right. The selector replaces the in-memory model container and returns to Home. It does not read or change the user's stored games.

States:

- Demo: Maya and Leo, one saved round.
- Worst case: 15 players, multilingual and compound names, 50 rounds, scores from 0 through 4,950, and one schema-backed empty saved name.
- Empty: no players or games.
- One: one saved player and one completed game.
- Huge: 1,284 saved players and 1,284 completed games.

The fixtures enter through SwiftData models. Player names are lowercased, as in the existing product. Cached player statistics retain their model defaults. They are not a correctness oracle for historical statistics.

Use native Xcode to build the app. Run from this worktree with the beta Xcode developer directory, a specific already-booted simulator, and a unique session. The installed TesterArmy version uses `e2e run`.

```sh
set -Eeuo pipefail
export DEVELOPER_DIR=/Applications/Xcode-27.1-beta.app/Contents/Developer
export PIPCOUNT_DEVICE=7AEFF457-CBA5-4485-A13D-896E75169E07
export PIPCOUNT_SESSION=pipcount-break-review
export PIPCOUNT_APP="$PWD/.build/break-ui16/Build/Products/Debug-iphonesimulator/ScoreKeeper.app"
export PIPCOUNT_JOURNEY_MANIFEST="$PWD/.e2e-break-review/manifest.jsonl"
npx e2e run tests/native-glass-break-ui.e2e.ts --grep 'empty one|invalid manual' --output .e2e-break-review
```

Focused options:

| Check | Selection and options |
| --- | --- |
| Collection and recovery boundaries | `--grep 'empty one\|invalid manual'` |
| Largest-text light scorecard and New Round reachability | `--grep multilingual`, `PIPCOUNT_BREAK_SCORE_ONLY=1`, `PIPCOUNT_BREAK_APPEARANCE=light` |
| Dark roster with largest text and real Reduce Transparency | `--grep multilingual`, `PIPCOUNT_BREAK_ROSTER_ONLY=1`, `PIPCOUNT_BREAK_APPEARANCE=dark`, `PIPCOUNT_BREAK_TRANSPARENCY=1` |
| Wide Home and Players containers | `--grep 'wide Duo'`, `PIPCOUNT_BREAK_WIDE=1`, exact Duo device `E00E0899-9FCB-49BE-9D05-E469A89371EA` |

The multilingual test restores the original system text size. The transparency option uses the real iOS Settings switch and restores its original state. The wide test restores the folded device state.

The 50-round New Round assertion currently fails its 30-second scroll budget. This is retained as a regression target. It does not prove the action is impossible to reach. The final audit separates this risk from earlier harness failures. The wide test checks Home and Players; wide scoring with this worst-case fixture is not verified.

Original screenshots, reports, build identity, findings, and coverage limits are in the task's `outputs/break-ui` directory. The prior implementation build 15 has a separate report. Stress build 16 adds only the DEBUG fixture seam to that implementation.
