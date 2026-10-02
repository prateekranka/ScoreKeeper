# PipCount feature prototypes

Four interactive browser previews of proposed PipCount features. These are design studies, not SwiftUI changes or an iOS release.

## Open the previews

The local preview server uses port 8147 and binds only to `127.0.0.1`.

From this checkout, run:

```sh
npm --prefix design-explorations/pipcount-feature-prototypes start
```

No package install is required. The server uses Node.js built-in modules.

- [Compare all four](http://127.0.0.1:8147/?view=compare)
- [A — Night hub](http://127.0.0.1:8147/?variant=A): The current Home layout, with round totals and a shortcut to the next game.
- [B — Crew first](http://127.0.0.1:8147/?variant=B): Saved people and house rules, ready for another game.
- [C — Score first](http://127.0.0.1:8147/?variant=C): An editable round ledger and direct typed entry.
- [D — Night story](http://127.0.0.1:8147/?variant=D): Game wins, personal records, and a return to the current game.

The existing private phone preview is [PipCount over Tailscale](https://macbook.taile5de76.ts.net/pipcount/?view=compare). The phone must be on the same tailnet. The route proxies this loopback server; it is not public Funnel access. This revision does not change the route or expose another service.

Use the fixed prototype switcher to change direction. Left and Right arrow keys also work when focus is outside the phone. Inputs and app controls keep their keyboard behavior. Each direction has independent in-memory state. The URL retains the selected direction on reload.

## Preview the added features

- [Typed score entry](http://127.0.0.1:8147/?view=compare&feature=scores)
- [Saved crews and game presets](http://127.0.0.1:8147/?view=compare&feature=crews)
- [Game Night recap and personal records](http://127.0.0.1:8147/?view=compare&feature=recap)
- [Read-only table display](http://127.0.0.1:8147/?view=compare&feature=table)

All four previews support these flows:

1. Type signed, whole-number round scores, including 150 and −5.
2. Switch between Type and Draw without losing the score draft.
3. Correct any earlier round and update the totals.
4. Save a crew and a named rule preset.
5. Finish a game and start another game with the same crew.
6. End the night and view results across its games.
7. See a game-specific personal record from sample history.
8. Copy recap text or open a read-only viewer snapshot.

## Design and motion

The four primary layouts are independent `VariantA`, `VariantB`, `VariantC`, and `VariantD` render functions. They share score-entry and feature-detail controls. Each layout retains the current native design:

- Paper `#F6F2E8`, card `#FFFDF7`, black `#0B0B0B`, blue `#0D47D9`, and the native red, yellow, and green accents.
- Black-weight system type, 34 px brand text, 28 px card corners, and 56 px blue action buttons.
- The floating Home / Games / Players / More dock.
- Editable SVG geometry ported from `KineticBauhausComposition`, `hub`, `score`, and `celebration` in `ClubhouseComponents.swift`.

The SVG uses the current black-disc composition. It does not use the older tower artwork in the static image assets. Coordinates and colors come from the native source. The browser does not reproduce SwiftUI materials, spring physics, or the exact system font rasterization.

Emil Kowalski’s design-engineering guidance shaped the interactions:

- Score typing and repeated score actions update immediately.
- Press feedback uses a small scale change with a 120 ms transition.
- Drawers open with a 240 ms ease-out curve. Switching drawer controls does not replay the opening animation.
- Motion uses only opacity and transforms.
- Reduced Motion removes positional animation and press scaling.
- The drawing pad uses pointer capture and ignores secondary pointers.
- Hover behavior applies only to devices with a precise pointer.

## Prototype limits

All names, game results, previous records, and dates are sample data. Changes reset on reload. There is no account, backend, local database, purchase, or OpenAI API connection.

Handwriting recognition is a marked simulation that returns **24**. The canvas accepts drawing, but it does not classify handwriting.

Viewer links contain a score snapshot in their URL. They are read-only, not live sync. A link generated from the Tailscale preview works only on a device with tailnet access.

Created crews support 2–4 players. The production app supports larger groups; these previews do not validate that layout. Presets express house rules, not official game rules. A different crew starts a fresh sample night and replaces the current in-memory night.

The `mode=production` query hides the prototype controls. It does not turn this study into a production build.

## Source boundary

Prototype branch: `codex/pipcount-feature-prototypes`.

Base commit: `f63520536a325e9451e4791456d9146a52de5349` from `cicd/validate-b16`. Its app code matches `app-dev/pipcount-b16-copy` at `fc77d61bbe0c7d11619ef361c189348207b3c0c9`.

Only this prototype directory is part of the change. The native app, Xcode project, workflows, and original dirty checkout are unchanged.

## Focused verification

TesterArmy e2e is configured for deterministic browser tests. No AI provider is configured, and the tests make no OpenAI API calls. The test dependencies are not needed to serve the previews.

With the preview server running:

```sh
npm ci
E2E_TELEMETRY_DISABLED=1 npm run test:e2e -- tests/bauhaus.e2e.ts --workers 1 --retries 0 --trace off
```

The focused checks cover the shared native design tokens, primary-action placement, signed typed scores, an earlier-round correction, phone-width overflow, and crew/recap access through the dock. Screenshots are captured through e2e. These checks do not prove the native iOS app or behavior on a physical phone.
