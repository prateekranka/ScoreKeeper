# PipCount handwriting preview

This directory contains the current score-entry web prototype
It uses React, shadcn Base UI, Manrope, DialKit and Motion with a local Python recognition server
The SwiftUI app remains in the repository's ScoreKeeper directory

Start with [the review guide](REVIEW_GUIDE.md) when reviewing this version

## Run on a Mac

Requirements: Node.js 22.22.3 or later in the supported 22.x line, or Node.js 24.8 or later; Python 3.14; Swift command-line tools

```sh
cd previews/handwriting
npm ci
npm run setup:python
npm run build
npm start
```

Open http://127.0.0.1:4191/?state=write&preset=softer

The setup command creates an ignored Python environment, installs pinned packages, checks both bundled model hashes and compiles the local Core ML worker
The server binds only to loopback
Jev is optional and no API key is needed for local recognition

For a static design preview without recognition, use npm run dev
For DialKit controls, add tune=1 to the query

## Score entry

The dialog accepts real finger, pen and mouse strokes
After a pause, the Mac recognises a cropped PNG with two local digit models
The suggested score and proposed total remain inline
The blue tick saves once, advances to the next player and shows a total toast with Undo
Player drafts survive switching, reloads and layout changes
Saving an edited score replaces the current round entry

This prototype accepts whole round scores from 0 to 99
It uses two sample players and does not implement the native app's other game modes or SwiftData storage

## Recognition and privacy

The digits-6 implementation separates close or tilted digits, rejects detached marks, composites transparency correctly and rejects multi-frame PNGs
The existing model weights and confidence thresholds are retained
GET /api/recogniser reports the loaded source hash and both model hashes

Local recognition processes images in memory on the Mac
The separate handwriting collection stores explicitly saved samples in an ignored local SQLite database
Exported labels remain unreviewed until checked
API keys stay in macOS Keychain and are not written into game state or this repository

Optional Jev setup is at /setup/jev
Connecting makes a request to TypeSafe for engineering advice
Image evaluation sends selected drawings to TypeSafe only when deliberately run
Jev does not affect score acceptance until its independent validation gate passes
See [Jev details](server/JEV.md) and [collection details](server/HANDWRITING.md)

## Private phone access

Set PIPCOUNT_PUBLIC_ORIGIN to the exact HTTPS origin of your private reverse proxy before starting the server
The value must contain the scheme, host and optional port only
The configured host is added to the server's allowed hosts
Your phone must have access to that private network

The default configuration permits loopback access only
PIPCOUNT_HANDWRITING_DIR can select a separate collection directory
PIPCOUNT_JEV_ACCOUNT can select a Keychain account; its default is derived from this checkout's path

## Acceptance checks

```sh
npm run build
npm run test:e2e
```

TesterArmy starts one isolated server on a free local port and stops it after the run
These checks cover real drawing, save and advance, Undo, score replacement, drafts, keyboard correction, viewport changes, Reduce Motion, collection links and origin checks
No real Jev key is used

Additional suites under tests cover the recogniser API, collection concurrency, SDK contracts and dataset evaluation
Their fixture and opt-in environment variables are documented in [the stress guide](server/LOCAL_STRESS.md)
Private handwriting images, runtime databases, keys, logs and proof recordings are excluded from Git
The optional historical evaluation suites require externally supplied reviewed fixtures

## Measured limits

The 1757-case development stress set improved from 1502 to 1620 correct readings
Wrong accepted readings fell from 50 to 13 on that set
The full 10000-image MNIST regression still has 16 wrong accepted readings
The two stricter confidence experiments were rejected because they lost known valid readings
These are regression results and do not prove error-free recognition for future writers

See [the implementation guide](server/README.md) for model licensing and runtime details
Browser acceptance does not establish physical iPhone or native SwiftUI acceptance
