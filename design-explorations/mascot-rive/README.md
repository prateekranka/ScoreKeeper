# Pip — Bauhaus Scorekeeper Mascot (Rive)

Animated mascot for **PipCount / ScoreKeeper**, built from scratch as a Rive `.riv` —
no editor, no stock art. Created via `rive-mcp-server` (editor-less MCP) driven by
Hermes, with the official Rive runtime validating every build.

## Concept

**Pip** is a lacquered score-token mascot built from pure Bauhaus primitives, in the
app's own design language (see `ScoreKeeper/Theme/ClubhouseTheme.swift`):

| Element | Meaning |
|---|---|
| Blue token body + ink outline | The game token / pip — brand primary `#064BB8` |
| Cream face plate | Paper stock `#FFF7E5` |
| Yellow ear (left) / red ear (right) | Bauhaus asymmetry, primaries |
| Green felt pennant + brass ring mount | Scoreboard flag; felt + brass brand accents |
| Lacquer triangle nose, soft closed-smile line | Bauhaus geometry with Disney face craft |
| Chest pips (yellow/red/green) | Player-color trio |
| White catchlights, blush, bottom AO | Depth cues that keep flat art alive |
| Soft eyes (no ink ring, relaxed pupils) | Friendly gaze — the uncanny-valley fix |

## Assets

| File | What |
|---|---|
| `pip-mascot.riv` | **The deliverable** — artboard `PipMascot` 512×512, 2 animations, 1 state machine |
| `pip-hero-transparent.png` | Static hero frame (idle t=0), transparent bg |
| `pip-idle.gif` | Idle loop preview (cream bg) |
| `pip-celebrate.gif` | Celebrate one-shot preview |
| `pip-mascot.webm` | Full 3.5s idle loop video |
| `build-scene.mjs` | Full scene source — regenerate with `node build-scene.mjs && node rive-bridge.mjs riv_create "$(cat create-args.json)"` |
| `rive-bridge.mjs` | Minimal stdio MCP client for driving `rive-mcp` from the shell |
| `scene.json` | The generated scene spec (readable) |

## Animation & rigging

- **`idle`** — 3.5s loop @60fps: phase-offset breathing bob (y/rotation/scaleY peak at
  different frames), ear wiggle, pennant flutter, arm sway, smile breathing, eye blink
  (right eye lags 1 frame), occasional pupil glance, shadow counter-scale (grounded feel).
- **`celebrate`** — 1.5s one-shot: anticipation crouch → jump (arc) → hang → fall →
  landing squash → elastic settle. Arms up, ears trail, legs scissor-kick, happy squint,
  blush flare, 6-piece confetti burst (staggered, gravity-free hand-keyed).
- **State machine `PipSM`** — entry → idle (loop); input `score` (trigger) → celebrate →
  auto-return to idle after 1.5s (`exitTimeMs: 1500`).

All 12 Disney principles via concrete easing recipes: `ease-in-back` crouch,
`emphasized-accel` fall, `elastic-out` settle, squash & stretch pairs (scaleX/scaleY
inverse), follow-through lag (ears/pennant trail the body by 4–8 frames).

## iOS integration

Add the Rive package: `https://github.com/rive-app/rive-ios` (SPM, product `RiveRuntime`).

```swift
import RiveRuntime
import SwiftUI

struct PipMascotView: View {
    private let rive = RiveViewModel(
        fileName: "pip-mascot",          // drag pip-mascot.riv into the target
        stateMachineName: "PipSM"
    )

    var body: some View {
        rive.view()
            .frame(width: 180, height: 180)
            .onAppear { rive.play() }    // starts in idle
    }

    func celebrate() {
        rive.triggerInput("score")       // fire-and-forget; returns to idle automatically
    }
}
```

Notes:
- Artboard is 512×512 with ~90px padding — scale freely, it never crops.
- The trigger input is the only API you need; no manual state handling.
- Reduce-motion: skip `triggerInput` and show the static `pip-hero-transparent.png`.
- Rive supports SwiftUI `.view()` (UIKit `RiveView` also available).

## Rebuild / iterate

The `rive` MCP server is registered in Hermes (`hermes mcp list`). Tools appear in new
sessions as `mcp__rive__*`; `rive-bridge.mjs` drives the same server from the shell:

```bash
node rive-bridge.mjs riv_create "$(cat create-args.json)"     # build .riv
node rive-bridge.mjs riv_render_frame '{"path":"pip-mascot.riv","animation":"idle","time":0,"width":512,"height":512,"outPath":"f.png"}'
node rive-bridge.mjs riv_critique '{"path":"pip-mascot.riv","animation":"idle","frames":8,"width":256}'
```

## Pitfalls learned (cost real debugging time)

1. **Shape `x,y` is parent-relative.** Children of a group are offset from the group
   origin — design in local coords, or everything doubles up and falls off-canvas.
2. **`rect` x,y = CENTER** (like ellipse). `x=-20,y=0,w=40,h=80` spans `-40..0` ×
   `-40..40`. The spec comment says top-left for rects; the renderer disagrees.
3. **Gradient fills on small parented shapes render broken** (half-size / clipped /
   empty) in the server's Canvas2D preview — flat fills are reliable. This project's
   Bauhaus look is flat anyway; the big token body gradient is the only one that works.
4. **Polygon points are relative to `x,y`** (offset applies); `radius` per point gives
   rounded-corner straight-vertex polygons — no bezier math needed for rounded shapes.
5. If the primary vision service is unavailable, use another configured image-review
   tool. Keep credentials outside this repository.
6. `riv_lint`/`riv_critique` findings are heuristics — scaleY-only blink and scaleX-only
   shadow counter-motion are *correct* technique, not lints to "fix".
