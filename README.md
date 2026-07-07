# ScoreKeeper

Native iOS scorekeeping app.

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
