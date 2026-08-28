# PipCount Bauhaus / OpenDesign handoff

This folder consolidates the original PipCount screen concepts, the OpenDesign
prototype, and native SwiftUI reference renders.

## Start here

1. Open `references/rendered-screen-concepts/contact-sheet.png` for the 18
   full-screen concepts with the large geometric background artwork.
2. Open `references/rendered-native-bauhaus-20260722/contact-sheet.png` for the
   six native iPhone renders that implemented that art direction.
3. Open `opendesign-output/scorekeeper-paper-bauhaus.html` for the interactive
   five-screen prototype.
4. Read `opendesign-output/paper-bauhaus-brand-spec.md` for the light and dark
   design tokens.

## Contents

### `opendesign-output/`

OpenDesign project output from 2026-08-08:

- Pixel-sampled light and dark design-system images.
- Paper Bauhaus brand and token specification.
- Self-contained interactive HTML prototype.

### `references/`

- `rendered-screen-concepts/`: all 18 generated PipCount screen concepts with
  geometric background art, including visual variants and dialogs.
- `rendered-native-bauhaus-20260722/`: six native iPhone renders from the first
  Swift implementation pass.

## Provenance boundary

OpenDesign authored the Paper Bauhaus token spec and HTML prototype. The native
SwiftUI source remains in the main project tree and Git history. See
`provenance/README.md` for the source boundary.
