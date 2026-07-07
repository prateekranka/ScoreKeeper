# ScoreKeeper Learnings

Shared memory for the ScoreKeeper Codex team. Keep this concise, factual, and durable.

## Operating Model

- Chief of Staff / Orchestrator owns task intake, thread coordination, quality bars, PR naming, and review pressure.
- QA Tester is used for PR-ready work only. Testing should be targeted, adversarial, and based on real UI interaction, not broad full regressions by default.
- Bugs should get regression tests when the codebase has a fitting test surface.
- If the same error appears twice, stop retrying blindly. Research 3-5 plausible fixes, choose the most efficient one, and implement it.
- Any change to OpenAI API interaction must be escalated with before-and-after behavior and must not ship without explicit user review.

## Project Context

- ScoreKeeper is a native iOS scorekeeping app built with SwiftUI and SwiftData.
- Supported game types currently include Scoreboard, What's for Dinner, and Phase 10.
- Navigation is centralized through `NavigationRouter` and `AppDestination` in `ScoreKeeper/App/ContentView.swift`.
- The UI screen network artifact for redesign prep lives at `docs/ui-screen-network.md`, with a generated route-strip PNG at `docs/ui-screen-network-route-strips.png`.
- Persistent gameplay state centers on `GameSession`, `Player`, `Round`, and `ScoreEntry` models under `ScoreKeeper/Models`.
- Scoring behavior is split through engines under `ScoreKeeper/Engines`.
- UI test coverage exists in `ScoreKeeperUITests/ScoreKeeperUITests.swift` and uses `-in-memory-store`.
- Simulator preview/control tooling is available through `npm run sim`, which launches ScoreKeeper and serves the simulator at `http://localhost:3200`.

## Current Worktree Snapshot

- Current branch: `claude/show-claude-md-0Z8wn`.
- Last observed commit: `0690018 Add complete AppIcon set with all required iOS sizes`.
- Uncommitted changes are present in:
  - `ScoreKeeper/Views/Components/ScoringComponents.swift`
  - `ScoreKeeper/Views/Scoring/GenericScoringView.swift`
- The current WIP appears to replace the generic scoring screen rows with a focused score table and disables the shared scoreboard header for that screen.

## Task And PR Flow

- Convert loose notes, voice notes, or walking thoughts into structured tasks before implementation.
- Name work and PRs as `PR# + human title` once a PR number exists.
- Route every new PR through the Chief of Staff thread for review.
- QA Tester should run only after implementation is PR-ready and should focus on the changed workflow plus likely adjacent breakpoints.
