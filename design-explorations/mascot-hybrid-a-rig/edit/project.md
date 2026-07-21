## Session 1 — 2026-07-15

**Strategy:** Convert the five approved mascot GIF previews into compact phone-friendly MP4 files without changing their motion or artwork.
**Decisions:** Encoded H.264 High Profile at 640x544 and 30 fps using yuv420p, repeated each animation twice, omitted audio, and moved the MP4 metadata before media data for progressive playback.
**Reasoning log:** Two passes make the short motions easier to inspect in a phone video player while keeping every file below 200 KB.
**Outstanding:** Curious Tilt and Victory Shimmy remain showcase-only concepts and have not been authored into the live Rive artboard.
