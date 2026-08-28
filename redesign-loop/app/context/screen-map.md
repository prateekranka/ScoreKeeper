# Screen Map — ScoreKeeper (PipCount) Paper Bauhaus Redesign

iPhone 15-frame (393×852) HTML prototype. Every screen below must be fully
reachable through real navigation and fully wired — NO dead screens, NO
placeholder buttons, NO actions that do nothing.

## Core game loop (must work end-to-end with real in-memory state)
1. **Home (empty)** — first-launch home. Entry points: New Game, Tools (timer), tabs to Roster / History / Stats.
2. **Onboarding** (first launch) — shows the game loop concretely (setup → score → tools → history). Skippable.
3. **Choose Game** — game-format picker: Scoreboard (free counting), Ten Phases (target 10 rounds), What's for Dinner (decision game). Double-ruled GameCover tiles.
4. **Player Setup** — add 2–8 players; each gets a Bauhaus shape pip (circle/square/triangle/diamond…) + color; editable names.
5. **Game Settings** — target score / round count / turn order / confirm.
6. **Scoring** — the heart of the app. Ledger rows (pip + name + trailing tabular score), PipStepper +/- blocks, round counter, undo last action, live leader highlight. Works for every game mode.
7. **Tool: Timer sheet** — accessible mid-game and from home: countdown with start/pause/reset, end-of-timer stamp moment.
8. **End Game confirm** — "End Game?" dialog from scoring screen.
9. **Game Over** — winner flagged in Bauhaus yellow (StampBadge WINNER), final ledger, actions: Rematch (same players, fresh scores) / New Game / Done→Home.
10. **Home (with history)** — same home after a game exists: recent result card → Game Detail.

## Secondary surfaces (all reachable via tabs/rows, all populated with demo state once a game exists)
11. **Game History** — list of finished games, tap → Game Detail.
12. **Game Detail** — final ledger, rounds, winner stamp, rematch button.
13. **Roster** — all players ever added, tap → Player Stats. Empty-state variant before first game.
14. **Player Stats** — games played, wins, avg score, head-to-head mini table.
15. **Head-to-Head** — compare two players across history.
16. **Paywall** — shown only from a non-blocking entry (e.g. "Go Pro" row in settings/support); never before first game.
17. **Legal & Support** — about, credits, restore, contact rows that all do something (sheet/alert/nav).

## Rules
- Single-page app or tiny multi-file static site, zero build step, opens from file:// or a static server.
- State machine in plain JS: players → setup → active game (scoring, undo, rounds) → finished → history/stats update.
- Light AND dark theme (toggle in header); tokens from brand-spec.md only.
- Every navigation animates per the Emil Kowalski skills in context/emil/.
