#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const root = path.dirname(new URL(import.meta.url).pathname);
const workspace = path.resolve(root, '../../../');
const authorityDir = path.join(workspace, 'design-explorations/mascot-hybrid-a-rig/production-v4-alpha');
const svgPath = path.join(root, 'canonical-dimensional-pixel.svg');
const fixturePath = path.join(root, 'preflight-msvg-fixture.svg');
const sourcePng = path.join(authorityDir, 'cleaned-canonical-bind.png');
const sourceSvg = path.join(authorityDir, 'cleaned-canonical.svg');

const expectedAuthority = {
  png: 'd93a520b5176a9e726e649edaa3b86ad8442d3469a2db807630925f7694bfefb',
  svg: '013647cfbe1669e880c24814ce6f42cb70a6fc4ca3284466d1ead02d793fe724',
};

const out = (name) => path.join(root, name);
const sha256File = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sha256Bytes = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const run = (args, options = {}) => execFileSync('magick', args, { encoding: 'buffer', stdio: ['ignore', 'pipe', 'pipe'], ...options });
const runSips = (args) => execFileSync('/usr/bin/sips', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
const identify = (file) => String(execFileSync('identify', ['-format', '%w %h %[channels]', file], { encoding: 'utf8' })).trim();
const rgba = (file) => run([file, '-depth', '8', 'rgba:-']);

function alphaMask(bytes, width, height) {
  const mask = new Uint8Array(width * height);
  // Native sips antialiases SVG boundaries; alpha >= 128 is the normalized
  // actual coverage used for silhouette and seam comparisons.
  for (let i = 0; i < mask.length; i += 1) mask[i] = bytes[i * 4 + 3] >= 128 ? 1 : 0;
  return mask;
}

function bbox(mask, width, height) {
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let y = 0; y < height; y += 1) for (let x = 0; x < width; x += 1) if (mask[y * width + x]) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return { minX, minY, maxX, maxY, width: maxX >= minX ? maxX - minX + 1 : 0, height: maxY >= minY ? maxY - minY + 1 : 0 };
}

function rowEdges(mask, width, height, y) {
  let min = width, max = -1;
  for (let x = 0; x < width; x += 1) if (mask[y * width + x]) { min = Math.min(min, x); max = Math.max(max, x); }
  return [min, max];
}

function erode3(mask, width, height) {
  const result = new Uint8Array(mask.length);
  for (let y = 1; y < height - 1; y += 1) for (let x = 1; x < width - 1; x += 1) {
    let ok = 1;
    for (let dy = -1; dy <= 1 && ok; dy += 1) for (let dx = -1; dx <= 1; dx += 1) if (!mask[(y + dy) * width + x + dx]) { ok = 0; break; }
    result[y * width + x] = ok;
  }
  return result;
}

function longestZeroRun(mask, width, y, start, end) {
  let longest = 0, run = 0;
  for (let x = start; x < end; x += 1) {
    if (mask[y * width + x]) run = 0;
    else { run += 1; longest = Math.max(longest, run); }
  }
  return longest;
}

function pixel(bytes, width, x, y) {
  const i = (y * width + x) * 4;
  return { r: bytes[i], g: bytes[i + 1], b: bytes[i + 2], a: bytes[i + 3] };
}

// Authority gate is intentionally before any authoring/rendering work.
const authority = { png: sha256File(sourcePng), svg: sha256File(sourceSvg) };
if (authority.png !== expectedAuthority.png || authority.svg !== expectedAuthority.svg) {
  throw new Error(`AUTHORITY_MISMATCH ${JSON.stringify({ expected: expectedAuthority, actual: authority })}`);
}

const msvgRenderer = String(execFileSync('magick', ['-version'], { encoding: 'utf8' })).split('\n')[0].trim();
const msvgRendererPinned = msvgRenderer.includes('ImageMagick 7.1.2-24');
if (!msvgRendererPinned) throw new Error(`MSVG_RENDERER_MISMATCH ${msvgRenderer}`);
const sipsVersion = String(execFileSync('/usr/bin/sips', ['--version'], { encoding: 'utf8' })).trim();
const systemIdentity = {
  uname: String(execFileSync('/usr/bin/uname', ['-a'], { encoding: 'utf8' })).trim(),
  macOS: String(execFileSync('/usr/bin/sw_vers', ['-productVersion'], { encoding: 'utf8' })).trim(),
};

// Keep the historical ImageMagick internal-MS​​VG result as evidence, but use
// native sips for the primary gradient-capable render.
const fixturePng = out('preflight-msvg-fixture.png');
run(['-background', 'none', `msvg:${fixturePath}`, '-define', 'png:color-type=6', '-depth', '8', fixturePng]);
const fixtureInfo = identify(fixturePng);
const fixtureBytes = rgba(fixturePng);
const fixtureGradientTop = pixel(fixtureBytes, 12, 1, 1);
const fixtureGradientBottom = pixel(fixtureBytes, 12, 1, 10);
const fixtureGap = pixel(fixtureBytes, 12, 6, 6);
const msvgGradientPass = fixtureGradientTop.r !== fixtureGradientBottom.r && fixtureGap.a === 0;

const sipsFixturePng = out('preflight-sips-fixture.png');
runSips(['-s', 'format', 'png', fixturePath, '--out', sipsFixturePng]);
const sipsFixtureInfo = identify(sipsFixturePng);
const sipsFixtureBytes = rgba(sipsFixturePng);
const sipsFixtureTop = pixel(sipsFixtureBytes, 12, 1, 1);
const sipsFixtureMid = pixel(sipsFixtureBytes, 12, 1, 6);
const sipsFixtureBottom = pixel(sipsFixtureBytes, 12, 1, 10);
const sipsFixtureGap = pixel(sipsFixtureBytes, 12, 6, 6);
const sipsGradientPass = sipsFixtureTop.a > 0 && sipsFixtureMid.a > 0 && sipsFixtureBottom.a > 0 && sipsFixtureGap.a === 0
  && new Set([sipsFixtureTop.r, sipsFixtureMid.r, sipsFixtureBottom.r]).size === 3;
if (!sipsGradientPass) throw new Error('SIPS_PREFLIGHT_FAILED');

const png = out('transparent-512x416.png');
runSips(['-s', 'format', 'png', svgPath, '--out', png]);
const [width, height] = identify(png).split(' ').map(Number);
if (width !== 512 || height !== 416) throw new Error(`DIMENSION_FAILED ${width}x${height}`);

const light = out('light-composite.png');
const dark = out('dark-composite.png');
const comparison = out('source-vs-redraw-comparison.png');
const proofFit = out('proof-aspect-fit-72x59.png');
const proof = out('72x60-proof.png');
const board = out('approval-board.png');
run(['-size', '512x416', 'xc:#F7F2E9', png, '-compose', 'over', '-composite', light]);
run(['-size', '512x416', 'xc:#191A1F', png, '-compose', 'over', '-composite', dark]);
run([sourcePng, png, '-background', '#F7F2E9', '+append', comparison]);
run([png, '-background', 'none', '-resize', '72x60', proofFit]);
run([proofFit, '-background', 'none', '-gravity', 'center', '-extent', '72x60', proof]);
run([light, dark, '-append', board]);

const bytes = rgba(png);
const sourceBytes = rgba(sourcePng);
const mask = alphaMask(bytes, width, height);
const sourceMask = alphaMask(sourceBytes, width, height);
const candidateBbox = bbox(mask, width, height);
const sourceBbox = bbox(sourceMask, width, height);

let intersection = 0, union = 0, dominantRows = 0, comparedRows = 0;
for (let i = 0; i < mask.length; i += 1) { if (mask[i] && sourceMask[i]) intersection += 1; if (mask[i] || sourceMask[i]) union += 1; }
for (let y = 0; y < height; y += 1) {
  const a = rowEdges(mask, width, height, y); const b = rowEdges(sourceMask, width, height, y);
  if (a[1] < 0 && b[1] < 0) continue;
  comparedRows += 1;
  if (a[1] >= 0 && b[1] >= 0 && Math.abs(a[0] - b[0]) <= 1 && Math.abs(a[1] - b[1]) <= 1) dominantRows += 1;
}

let transparentRgbMax = 0;
for (let i = 0; i < mask.length; i += 1) if (!mask[i]) transparentRgbMax = Math.max(transparentRgbMax, bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2]);
const holeSamples = { left: pixel(bytes, width, 60, 149), right: pixel(bytes, width, 453, 149) };
const intendedHoleRects = { left: { x: 49, y: 129, width: 23, height: 40 }, right: { x: 441, y: 129, width: 24, height: 40 } };
const transparentHoleGeometry = Object.fromEntries(Object.entries(intendedHoleRects).map(([name, rect]) => {
  let covered = 0;
  for (let y = rect.y; y < rect.y + rect.height; y += 1) for (let x = rect.x; x < rect.x + rect.width; x += 1) if (mask[y * width + x]) covered += 1;
  return [name, { ...rect, coveredPixels: covered, pass: covered === 0 }];
}));
const cornerSamples = [[0, 0], [511, 0], [0, 415], [511, 415]].map(([x, y]) => pixel(bytes, width, x, y));
const landmarkPoints = {
  accent: [256, 40], leftEye: [195, 148], rightEye: [311, 148], mouth: [255, 214],
  stem: [255, 275], pedestal: [255, 294], base: [255, 344], lowerBase: [255, 382],
  leftHandle: [20, 100], rightHandle: [492, 100],
};
const landmarks = Object.fromEntries(Object.entries(landmarkPoints).map(([name, [x, y]]) => [name, pixel(bytes, width, x, y).a > 0]));
const gradientSamples = [[100, 94], [100, 180], [100, 222]].map(([x, y]) => pixel(bytes, width, x, y));
const luma = (p) => 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
const gradientLuma = gradientSamples.map(luma);
// Regression gate for the horizontal banding defect: every visually segmented
// cup surface must sample the same canvas-space gradient on both sides of its
// old construction boundary.
const continuitySpecs = [
  { name: 'upperCup', x: 100, yA: 127, yB: 128 },
  { name: 'middleCup', x: 100, yA: 169, yB: 170 },
  { name: 'lowerCup', x: 100, yA: 219, yB: 220 },
  { name: 'leftHandle', x: 30, yA: 168, yB: 169 },
  { name: 'rightHandle', x: 470, yA: 168, yB: 169 },
];
const cupGradientContinuity = continuitySpecs.map(({ name, x, yA, yB }) => {
  const a = pixel(bytes, width, x, yA);
  const b = pixel(bytes, width, x, yB);
  const maxChannelDelta = Math.max(Math.abs(a.r - b.r), Math.abs(a.g - b.g), Math.abs(a.b - b.b));
  return { name, x, yA, yB, a, b, maxChannelDelta, pass: a.a === 255 && b.a === 255 && maxChannelDelta <= 4 };
});
const eroded = erode3(mask, width, height);
const seamSpans = [[224, 69, 441], [243, 88, 420], [262, 88, 420], [283, 215, 292], [303, 196, 311], [323, 158, 349], [362, 138, 370], [400, 118, 390]];
const seamScan = seamSpans.map(([y, start, end]) => ({ y, start, end, longestTransparentRunAfterErode: longestZeroRun(eroded, width, y, start, end) }));

// Render a second time with native sips and compare normalized raw RGBA payloads,
// not PNG metadata or ancillary chunks.
const repeatPng = out('.repeat-check.png');
runSips(['-s', 'format', 'png', svgPath, '--out', repeatPng]);
const repeatBytes = rgba(repeatPng);
const rawHash = sha256Bytes(bytes);
const repeatRawHash = sha256Bytes(repeatBytes);
fs.rmSync(repeatPng, { force: true });

const sourceAlphaCount = sourceMask.reduce((a, b) => a + b, 0);
const candidateAlphaCount = mask.reduce((a, b) => a + b, 0);
const svgText = fs.readFileSync(svgPath, 'utf8');
const rectCount = (svgText.match(/<rect\b/g) || []).length;
const pathCount = (svgText.match(/<path\b/g) || []).length;
const gradientCount = (svgText.match(/<linearGradient\b/g) || []).length;
const appliedGradientFills = (svgText.match(/fill="url\(#/g) || []).length;
const qa = {
  status: 'measured_with_native_sips_gradients',
  authority,
  renderer: { primary: '/usr/bin/sips', sipsVersion, systemIdentity, msvgHistory: { pinned: msvgRendererPinned, version: msvgRenderer } },
  fixture: { source: path.basename(fixturePath), msvg: { input: `msvg:${path.basename(fixturePath)}`, identify: fixtureInfo, gradientTop: fixtureGradientTop, gradientBottom: fixtureGradientBottom, transparentCenter: fixtureGap, directGradientPass: msvgGradientPass }, sips: { input: path.basename(fixturePath), identify: sipsFixtureInfo, gradientTop: sipsFixtureTop, gradientMid: sipsFixtureMid, gradientBottom: sipsFixtureBottom, transparentCenter: sipsFixtureGap, directGradientPass: sipsGradientPass } },
  outputs: { transparent: identify(png), light: identify(light), dark: identify(dark), comparison: identify(comparison), proofFit: identify(proofFit), proof: identify(proof), board: identify(board) },
  geometry: { canvas: [512, 416], sourceBbox, redrawBbox: candidateBbox, sourceAlphaCount, candidateAlphaCount },
  checks: {
    dimensions: width === 512 && height === 416,
    alphaZeroCorners: cornerSamples.every((p) => p.a === 0),
    alphaZeroHandleCenters: holeSamples.left.a === 0 && holeSamples.right.a === 0,
    transparentHoleGeometry: { intended: intendedHoleRects, measured: transparentHoleGeometry, pass: Object.values(transparentHoleGeometry).every((v) => v.pass) },
    noWhiteMatteOrFringe: transparentRgbMax <= 4,
    compactElements: { rectCount, pathCount, paintedElements: rectCount + pathCount, pass: rectCount + pathCount <= 80 },
    gradients: { gradientDefinitions: gradientCount, appliedGradientFills, directSipsGradientPass: sipsGradientPass, samples: gradientSamples, orderedLuma: gradientLuma, pass: appliedGradientFills >= 6 && sipsGradientPass && gradientLuma[0] > gradientLuma[1] && gradientLuma[1] > gradientLuma[2] },
    cupGradientContinuity: { samples: cupGradientContinuity, pass: cupGradientContinuity.every((sample) => sample.pass) },
    silhouetteDominantStepAgreementOutsideOnePxBand: { comparedRows, matchingRows: dominantRows, ratio: comparedRows ? dominantRows / comparedRows : 0, pass: comparedRows ? dominantRows / comparedRows >= 0.65 : false, iou: union ? intersection / union : 0 },
    seamScanOnErodedActualAlphaCoverage: { seams: seamScan, pass: seamScan.every((s) => s.longestTransparentRunAfterErode <= 3) },
    landmarkPresence: { points: landmarkPoints, pass: Object.values(landmarks).every(Boolean), values: landmarks },
    deterministicRepeatRawRgba: { rawHash, repeatRawHash, pass: rawHash === repeatRawHash },
  },
  notes: [
    'Pinned ImageMagick MSVG remains recorded as history; its explicit gradient fixture fails, while native macOS sips passes the same gradient-plus-gap capability gate.',
    'Silhouette agreement is measured against the locked cleaned-canonical-bind alpha mask; the vector is intentionally simplified to compact orthogonal pieces.',
    'Source and redraw are compared as alpha silhouettes; all segmented cup surfaces share one canvas-space gradient and explicit horizontal highlight bands are removed.',
  ],
};
fs.writeFileSync(out('qa.json'), `${JSON.stringify(qa, null, 2)}\n`);
if (!qa.checks.dimensions || !qa.checks.alphaZeroCorners || !qa.checks.alphaZeroHandleCenters || !qa.checks.transparentHoleGeometry.pass || !qa.checks.noWhiteMatteOrFringe || !qa.checks.compactElements.pass || !qa.checks.gradients.pass || !qa.checks.cupGradientContinuity.pass || !qa.checks.seamScanOnErodedActualAlphaCoverage.pass || !qa.checks.landmarkPresence.pass || !qa.checks.deterministicRepeatRawRgba.pass) {
  process.exitCode = 2;
}
console.log(JSON.stringify({ status: qa.status, renderer: qa.renderer, outputs: qa.outputs, checks: qa.checks }, null, 2));
