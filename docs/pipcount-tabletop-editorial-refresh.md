# PipCount tabletop-editorial refresh

## Product feeling

PipCount should feel like the nicest object on a game-night table: quick, friendly, tactile, and worth keeping open between rounds. It should not feel like a Bauhaus poster generator or a generic utility dashboard.

The refreshed system combines:

- warm printed-paper surfaces;
- rounded editorial typography;
- recognisable game-night objects rather than abstract geometry;
- softly imperfect arrangements, slight rotations, and overlapping layers;
- a restrained palette built around ink, cream, cobalt, tomato, mustard, sage, dusty pink, and lilac;
- Apple-native hierarchy, focus, motion, materials, and accessibility.

## Illustration language

Every illustration is assembled from the same object family:

- score slips and spiral pads;
- pencils and handwritten marks;
- playing cards and game boxes;
- dice, tokens, pawns, and poker chips;
- plates and choice cards for social games;
- trophies, ribbons, and confetti for completed games.

Objects use rounded dark-ink outlines, warm paper shadows, controlled overlap, and small asymmetries. Avoid standalone circles, squares, bars, targets, grids, or starbursts unless they are serving a recognisable object.

## Asset catalogue

The following vector image sets form the core family:

- `PipCountHeroArtwork` — score pad, card, pencil, die, and loose tokens;
- `PipCountEmptyStateArtwork` — an open game box with pieces ready to play;
- `PipCountScoreEmblem` — a focused score-pad composition;
- `PipCountCrewEmblem` — four friends around a shared table;
- `PipCountUnlimitedEmblem` — an overflowing stack of game boxes and cards;
- `PipCountCelebrationEmblem` — trophy, final score sheet, ribbon, and confetti.

All six are SVG assets with preserved vector representation. They should remain legible at compact sizes and crisp at large Dynamic Type or future iPad sizes.

## Screen mapping

- Home: hero artwork; open-box artwork for the empty state.
- Game picker: hero composition plus small game cards.
- Player setup and roster: crew artwork.
- Game settings, handwriting, and live scoring: score-pad artwork with scene-specific overlays.
- Game over and history onboarding: celebration artwork.
- Paywall: unlimited-game-box artwork.

The screen router intentionally keeps the existing `PipCountGeometricArtwork` API so feature screens do not need to know which asset is used. The legacy name can be renamed in a later cleanup once all branches have converged.

## Surfaces

Cards should read as thick paper, not bordered rectangles:

- continuous rounded corners;
- a low-opacity ink outline;
- a warm offset paper shadow plus a soft ambient shadow;
- a subtle inner highlight;
- stronger depth only for tappable cards.

Do not use double rectangular frames, hard black borders, or zero-blur drop shadows as the default treatment.

## Player identity

Player colours remain useful, but their markers now behave like game pieces:

- poker chip;
- rounded die tile;
- pawn;
- ticket token.

Large decorative geometry should never compete with names and scores. Colour is identity; shape is a secondary cue for accessibility.

## Motion rules

- Press interactions should settle quickly and preserve perceived weight.
- Scene art enters with a small scale, offset, and rotation correction rather than flying in.
- Numeric changes use `contentTransition(.numericText)`.
- Section entrances remain staggered but are capped so a screen never feels choreographed.
- Every custom motion path must respect Reduce Motion.
- Avoid looping decorative movement during score entry; the table should feel calm while users are concentrating.

## Review checklist

Before adding or approving a screen:

1. Can the hero be described as a game-night object, not a shape composition?
2. Does the primary action win immediately without relying on an oversized heading?
3. Are cards using the shared paper surface and depth model?
4. Are colours doing a semantic job rather than filling empty space?
5. Does the layout survive large Dynamic Type and compact-height iPhones?
6. Does the interaction still make sense with Reduce Motion enabled?
7. Is all essential information available without colour or shape alone?
