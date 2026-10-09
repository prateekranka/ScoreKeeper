# PipCount

Native iPhone and iPad scorekeeping app. Home, Games, Players, and More use native tabs at every window width.

## UI Screen Network

The current screen and navigation route inventory for redesign prep lives in `docs/ui-screen-network.md`.

## Simulator Preview

This project includes `serve-sim` tooling so a booted iOS Simulator can be previewed and controlled from a browser.

```sh
npm install
npm run sim
```

`npm run sim` boots an iPhone simulator, builds and launches ScoreKeeper, then starts `serve-sim` at `http://localhost:3200`.

Useful variants:

```sh
SERVE_SIM_DEVICE="iPhone 16 Pro" npm run sim
npm run sim:serve
npm run sim:serve:detach
npm run sim:serve:kill
```

## Native build and app acceptance

```sh
xcodebuild -project ScoreKeeper.xcodeproj -scheme ScoreKeeper \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
npm ci
```

Use [TesterArmy e2e](tests/README.md) for app acceptance on a selected, already-booted simulator. The suites cover all native tabs, complete game flows, folding, and real system accessibility settings. Set `PIPCOUNT_APP` to the exact built bundle when it differs from `.build/DerivedData/Build/Products/Debug-iphonesimulator/ScoreKeeper.app`.
