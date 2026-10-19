# Private handwriting preview

The browser draws real pointer strokes and sends a cropped PNG to the loopback server, optionally through a configured private reverse proxy. The Mac runs two independent digit CNNs using ONNX Runtime and Apple Core ML on its CPU. Local recognition processes images in memory without saving them. The separate collection saves only explicitly submitted samples. Optional Jev evaluation can send selected drawings to TypeSafe as described in [Jev details](JEV.md).

The recogniser composites PNG transparency against white, rejects multi-frame input, crops visible ink and preserves every empty column gap. It can also separate two substantial connected components when tilt makes their vertical projections overlap. It preserves aspect ratio, normalizes stroke weight, and centers each 28 by 28 input by its ink mass. Three views vary stroke weight. If the original stroke weight is already at least one pixel at model scale, the original ink is also checked. An accepted digit must win every applicable view in both models and meet both probability and margin checks in each model. Disconnected small marks, detached horizontal marks and implausibly faint extra digit groups cause rejection without deleting any ink or changing a score. These values are model scores, not calibrated probabilities of correctness. They cannot guarantee that an unusual mark will be rejected.

The model and its source README, license and checksum are in `models`. Startup refuses a changed checksum for either model. The virtual environment is task-local in `.runtime/digits-env`; packages are pinned in `requirements.lock`.

```sh
npm ci
npm run setup:python
npm run build
npm start
```

`GET /api/recogniser` reports the loaded implementation version, source hash and both model checksums. `POST /api/recognise` accepts one PNG of at most 1 MiB and returns an inline result. The canvas and the one-tap save flow are unchanged. The former general-purpose Vision helper is retained as historical source and is no longer used by this server. See [local stress checks](LOCAL_STRESS.md) for the reproducible evaluation and its proof limits.

TesterArmy tests in `tests/digit-recognition.e2e.ts` check the user's real screenshot crops, real pointer drawing and saving, and invalid-input controls. Set `PIPCOUNT_DIGIT_EVIDENCE` to the external fixture directory. The optional `PIPCOUNT_BENCHMARK=1` checks the complete 10000-image MNIST test set against this same HTTP endpoint. The benchmark uses existing handwritten test images enlarged ten times, not human drawing on a phone, so its results do not establish phone handwriting accuracy.

This implementation is for the web design preview. It does not change the SwiftUI worktree or establish native app release readiness.


## Reliability limits

Handwriting recognition cannot guarantee the intended value for every mark. Both classifiers can agree on an incorrect value, even with a high model score. A finite regression suite cannot prove that future input is error free. More rejection can reduce wrong accepted readings, but it also requires more rewriting or typing.

The score stays visible before the existing tick action saves it. Uncertain input remains in the same dialog with the original drawing intact. The app retains the keyboard alternative and Undo. No second confirmation screen has been added.
