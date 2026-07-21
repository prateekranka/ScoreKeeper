# Timeline duration dependency check

The application source contains no references to `idle_breathe_blink`,
`hair_bounce`, `victory_pop`, `curious_tilt`, `celebrate_shimmy`, or the five
v2 animation IDs. Matches outside the v6/v7 rig folders occur only in older
design-exploration reports and specs. Runtime compatibility therefore depends
on stable timeline names and playback modes, not the prior frame counts.

Approved v3 duration decision: retain 72 frames for idle, 72 for victory,
84 for curious, and 96 for shimmy; shorten hair bounce from 60 to 48 frames so
it reads as a short one-shot. This changes no application code.
