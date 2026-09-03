# Tile artwork pixel verification (Scoreboard / Ten Phases / What's for Dinner)

This harness proves that the three game tiles render their bundled reference artworks
**pixel to pixel** on the QA simulator. It documents the end-to-end flow for the next
runner: build, install, launch with frozen tile art, screenshot, then run
`scripts/compare_tile_art.py` once per tile.

- References (1448x1086 RGB, exactly 4:3):
  - Scoreboard: `ScoreKeeper/Assets.xcassets/ScoreboardTileArtwork.imageset/scoreboard-tile-art.png`
  - Ten Phases: `ScoreKeeper/Assets.xcassets/Phase10TileArtwork.imageset/phase10-tile-art.png`
  - What's for Dinner: `ScoreKeeper/Assets.xcassets/WhatsForDinnerTileArtwork.imageset/whats-for-dinner-tile-art.png`
- Tool: `scripts/compare_tile_art.py` (run with `/opt/homebrew/bin/python3`; PIL and
  numpy are installed there). Sanity-check the harness itself any time with:

  ```
  /opt/homebrew/bin/python3 scripts/compare_tile_art.py --self-test
  ```

  It builds a synthetic screenshot from the real Phase 10 reference at a known random
  offset/scale, locates and compares it, and must print `SELF-TEST PASS` (exit 0).

## Target simulator

| Property | Value |
| --- | --- |
| Name | PipCount Bauhaus QA |
| UDID | `C25CE303-0B95-4547-9CAA-3F9EA1AA4C94` |
| Device / OS | iPhone 17 Pro Max, iOS 26.5 |
| App bundle id | `com.icequeen.scorekeeper` |
| App display name | PipCount |

The compare script assumes a `--device-scale` of 3.0 (this device renders @3x), so a
screenshot of the full screen is expected to be **1320 x 2868 pixels** (verify with
`sips -g pixelWidth -g pixelHeight <screenshot>`).

## Step-by-step

Run everything from the worktree root
(`/Users/prateekranka/Cowork/ScoreKeeper-worktrees/mlkit-digital-ink`).

### 1. Build

```
xcodebuild -workspace ScoreKeeper.xcworkspace -scheme ScoreKeeper \
  -destination 'platform=iOS Simulator,id=C25CE303-0B95-4547-9CAA-3F9EA1AA4C94' \
  -derivedDataPath build/DerivedData-tile-verify build
```

### 2. Locate and install the .app

```
APP=$(find build/DerivedData-tile-verify/Build/Products/Debug-iphonesimulator \
     -maxdepth 1 -name '*.app' | head -n 1)
echo "$APP"          # e.g. .../Debug-iphonesimulator/PipCount.app
xcrun simctl bootstatus C25CE303-0B95-4547-9CAA-3F9EA1AA4C94 -b
xcrun simctl install C25CE303-0B95-4547-9CAA-3F9EA1AA4C94 "$APP"
```

### 3. Launch with frozen tile art

```
xcrun simctl terminate C25CE303-0B95-4547-9CAA-3F9EA1AA4C94 com.icequeen.scorekeeper 2>/dev/null || true
xcrun simctl launch C25CE303-0B95-4547-9CAA-3F9EA1AA4C94 com.icequeen.scorekeeper -tile-art-frozen
sleep 5
```

The `-tile-art-frozen` launch argument freezes the tile artwork in its rest state.
**Screenshots are only valid if the app was launched with this flag** — launch arguments
apply only on a fresh launch, hence the `terminate` first. Wait ~3-5 s so entrance
animations settle before capturing anything.

### 4. Navigate to the Games tab and screenshot

Open the Simulator window (or drive it with your usual UI-automation tool), tap the
**Games** tab, let transitions settle, then capture:

```
xcrun simctl io C25CE303-0B95-4547-9CAA-3F9EA1AA4C94 screenshot /tmp/tile-verify/games.png
```

### 5. Derive `--approx-box` (in screenshot pixels, not points)

Expected on-screen geometry (confirm by actually viewing the screenshot before running):

- iPhone 17 Pro Max logical width ~440 pt; the Games tab is a single-column card list.
- Each card has 20 pt internal padding; the artwork is full card width at 4:3 aspect,
  so the artwork is approximately 440 - 2*16 - 2*20 = **368 pt wide x 276 pt tall**,
  i.e. **1104 x 828 px** at @3x.
- Horizontal position: outer margin 16 pt + card padding 20 pt = 36 pt -> **x = 108 px**
  on a 1320 px wide screenshot.
- Vertical order below the "Choose a Game" hero: **Scoreboard, Ten Phases,
  What's for Dinner** (top to bottom). The Y offset depends on the hero height — read
  the top of each artwork off the screenshot and use that as the box Y.

The box must *generously contain* the artwork (a bit of surrounding card is fine — the
script pads it by ~12% and its locate step tolerates coarse boxes), but it must contain
the whole artwork.

### 6. Run the three comparisons

```
/opt/homebrew/bin/python3 scripts/compare_tile_art.py \
  --reference 'ScoreKeeper/Assets.xcassets/ScoreboardTileArtwork.imageset/scoreboard-tile-art.png' \
  --screenshot /tmp/tile-verify/games.png \
  --approx-box 108,<SCOREBOARD_TOP_Y>,1104,828 --device-scale 3

/opt/homebrew/bin/python3 scripts/compare_tile_art.py \
  --reference 'ScoreKeeper/Assets.xcassets/Phase10TileArtwork.imageset/phase10-tile-art.png' \
  --screenshot /tmp/tile-verify/games.png \
  --approx-box 108,<TEN_PHASES_TOP_Y>,1104,828 --device-scale 3

/opt/homebrew/bin/python3 scripts/compare_tile_art.py \
  --reference 'ScoreKeeper/Assets.xcassets/WhatsForDinnerTileArtwork.imageset/whats-for-dinner-tile-art.png' \
  --screenshot /tmp/tile-verify/games.png \
  --approx-box 108,<DINNER_TOP_Y>,1104,828 --device-scale 3
```

Replace the `<..._TOP_Y>` placeholders with the measured values from step 5. Each run
prints the located rect, the diff metrics and a `VERDICT:` line, and writes a diff
heatmap (`*.tile-diff-heatmap.png`) plus the aligned crop (`*.tile-aligned-crop.png`)
next to the screenshot (or into `--out-dir`). Don't commit screenshots or artifacts.

## Verdicts and exit codes

| Exit | Meaning |
| --- | --- |
| 0 | `VERDICT: PASS` |
| 1 | `VERDICT: FAIL` — compared fine but metrics miss the thresholds (failed criteria are listed) |
| 2 | `VERDICT: NO CONFIDENT ALIGNMENT` — locate could not confidently find the reference (or bad input paths/box) |

PASS criteria (also printed with every report):

- overall mean abs diff <= 6/255,
- >= 97% of pixels within a max-channel delta of 16,
- located scale within 3% of the expected uniform scale
  (expected = 368 pt x device scale 3 / 1448 px reference width = 0.7624; override with
  `--expected-scale` if the layout changed).

If the located NCC is below 0.60 the script refuses to judge and exits 2.

## On failure

- **Exit 2 / low NCC**: view the screenshot and re-check the approx box (it must fully
  contain the artwork); confirm you are comparing against the right tile's reference.
  Re-check the **crop mode**: the script assumes the tile renders the *full* 4:3
  reference at uniform scale — if the tile crops (`aspect fill`), letterboxes, or
  stretches the art, locate will fail or the scale check will trip; fix the rendering
  or pass `--expected-scale` deliberately.
- **Good NCC but FAIL on diffs**: check the **color profile** (simulator screenshots vs
  sRGB/P3 asset encoding), any overlay/rounded-corner/shadow drawn on top of the art,
  and whether the screenshot was taken mid-animation. The heatmap shows *where* the
  pixels disagree (bright = large max-channel delta).
- **Scale deviation > 3%**: wrong `--device-scale`, or the artwork no longer renders at
  368 pt (layout changed) — re-measure the on-screen artwork width in the screenshot
  and pass `--expected-scale` (located/reference width) accordingly.
- **Anything odd**: re-run the self-test first (`--self-test` must print
  `SELF-TEST PASS`); if it fails, the harness is broken, not the app.
