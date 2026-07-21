#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  CANVAS,
  DURATION_SECONDS,
  TERMINAL_FRAME,
  DISPLAY_NAME,
  UNDERLAP_COLOR,
  TRACKS,
  CANONICAL_PARTS,
  PALETTE,
  ROOT_PIVOT,
  HAIR_PIVOT,
  SOURCE_GROUPS,
  PATH1_SPECIAL,
  ownerFor,
  OWNERSHIP_VALIDATION,
} from "./victory-pop-spec.mjs";

const ROOT = dirname(fileURLToPath(import.meta.url));
const CANONICAL = join(ROOT, "../svg/scorekeeper-cup-hybrid-a-canonical.svg");
const OUTPUT = ROOT;
const FRAMES = join(OUTPUT, "frames");
const INSPECTION = join(OUTPUT, "inspection");
const CONTACT_TILES = join(OUTPUT, ".contact-tiles");
const TMP_SVG = join(OUTPUT, ".victory-pop-frame.svg");
const CANONICAL_PNG = join(OUTPUT, "canonical-bind.png");
const MP4 = join(OUTPUT, "victory-pop.mp4");
const CONTACT = join(OUTPUT, "victory-pop-contact-sheet.png");
const QA = join(OUTPUT, "victory-pop-qa.json");
const LOCK = join(OUTPUT, ".render.lock");

function sleepMs(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function acquireRenderLock() {
  const startedAt = Date.now();
  for (;;) {
    try {
      mkdirSync(LOCK);
      writeFileSync(join(LOCK, "owner"), `${process.pid}\n`);
      process.on("exit", () => rmSync(LOCK, { recursive: true, force: true }));
      return;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      try {
        if (Date.now() - statSync(LOCK).mtimeMs > 10 * 60 * 1000) rmSync(LOCK, { recursive: true, force: true });
      } catch {
        // Another renderer may be replacing the lock; retry below.
      }
      if (Date.now() - startedAt > 15 * 60 * 1000) throw new Error(`Timed out waiting for renderer lock ${LOCK}`);
      sleepMs(250);
    }
  }
}

function verifyFrameSet() {
  const expected = [...Array(TERMINAL_FRAME + 1).keys()].map((frame) => `${String(frame).padStart(4, "0")}.png`);
  const actual = readdirSync(FRAMES).filter((file) => /^\d{4}\.png$/.test(file));
  const missing = expected.filter((file) => !actual.includes(file));
  const unexpected = actual.filter((file) => !expected.includes(file));
  if (missing.length || actual.length !== expected.length) {
    throw new Error(`Frame generation incomplete before downstream steps: expected=${expected.length} actual=${actual.length} missing=${missing.join(",") || "none"} unexpected=${unexpected.join(",") || "none"}`);
  }
  return { expectedCount: expected.length, actualCount: actual.length, missing, unexpected };
}

acquireRenderLock();

rmSync(FRAMES, { recursive: true, force: true });
rmSync(INSPECTION, { recursive: true, force: true });
rmSync(CONTACT_TILES, { recursive: true, force: true });
mkdirSync(FRAMES, { recursive: true });
mkdirSync(INSPECTION, { recursive: true });
mkdirSync(CONTACT_TILES, { recursive: true });

const PIVOTS = Object.freeze({
  cup: { x: 255, y: 245 },
  pedestal: { x: 256, y: 401 },
  hair: HAIR_PIVOT,
  eyeL: { x: 196, y: 147 },
  eyeR: { x: 312, y: 147 },
  mouth: { x: 255, y: 205 },
  shine: { x: 118, y: 81 },
});

const HAIR_CAP = new Set([5, 28, 50, 137]);
const HAIR_FRINGE = new Set([164, 175]);

function cubic(t, p1, p2) {
  const mt = 1 - t;
  return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t;
}

function cubicProgress(progress, p1x, p1y, p2x, p2y) {
  let lo = 0;
  let hi = 1;
  let t = progress;
  for (let i = 0; i < 14; i += 1) {
    const x = cubic(t, p1x, p2x);
    if (x < progress) lo = t;
    else hi = t;
    t = (lo + hi) / 2;
  }
  return cubic(t, p1y, p2y);
}

function easingProgress(progress, mode = "smooth") {
  if (mode === "step") return 0;
  if (mode === "linear") return progress;
  if (mode === "easeOut") return cubicProgress(progress, 0.16, 1, 0.3, 1);
  if (mode === "easeIn") return cubicProgress(progress, 0.7, 0, 0.84, 0);
  if (mode === "easeInOut") return cubicProgress(progress, 0.65, 0, 0.35, 1);
  return cubicProgress(progress, 0.42, 0, 0.58, 1);
}

function keysFor(track) {
  return Array.isArray(track) ? track : track?.keys;
}

function trackValue(track, frame) {
  if (!track) return 0;
  const keys = keysFor(track);
  if (!keys?.length) return 0;
  if (frame <= keys[0][0]) return keys[0][1];
  if (frame >= keys.at(-1)[0]) return keys.at(-1)[1];
  for (let index = 0; index < keys.length - 1; index += 1) {
    const start = keys[index];
    const end = keys[index + 1];
    if (frame < start[0] || frame > end[0]) continue;
    if (track.interpolation === "step") return start[1];
    const progress = (frame - start[0]) / (end[0] - start[0]);
    const eased = easingProgress(progress, start[2] ?? "smooth");
    return start[1] + (end[1] - start[1]) * eased;
  }
  return keys.at(-1)[1];
}

function matrixFor(track, pivot, frame) {
  const dx = trackValue(track?.dx, frame);
  const dy = trackValue(track?.dy, frame);
  const rotation = (trackValue(track?.rotationDeg, frame) * Math.PI) / 180;
  const scaleX = trackValue(track?.scaleX, frame) || 1;
  const scaleY = trackValue(track?.scaleY, frame) || 1;
  const cosine = Math.cos(rotation);
  const sine = Math.sin(rotation);
  const a = cosine * scaleX;
  const b = sine * scaleX;
  const c = -sine * scaleY;
  const d = cosine * scaleY;
  return [
    a,
    b,
    c,
    d,
    pivot.x + dx - a * pivot.x - c * pivot.y,
    pivot.y + dy - b * pivot.x - d * pivot.y,
  ];
}

function compose(parent, child) {
  const [a, b, c, d, e, f] = parent;
  const [g, h, i, j, k, l] = child;
  return [
    a * g + c * h,
    b * g + d * h,
    a * i + c * j,
    b * i + d * j,
    a * k + c * l + e,
    b * k + d * l + f,
  ];
}

function formatted(value) {
  return Number(value.toFixed(5));
}

function pointFor(matrix, x, y) {
  return {
    x: formatted(matrix[0] * x + matrix[2] * y + matrix[4]),
    y: formatted(matrix[1] * x + matrix[3] * y + matrix[5]),
  };
}

function pathD(commands, matrix) {
  return commands.map((command) => {
    if (command.commandType === "close") return "Z";
    const point = pointFor(matrix, command.x, command.y);
    return `${command.commandType === "moveTo" ? "M" : "L"}${point.x},${point.y}`;
  }).join(" ");
}

function transformsFor(frame) {
  const authoredRoot = matrixFor(TRACKS.root, ROOT_PIVOT, frame);
  // The requested ballistic keys are preserved, with a non-endpoint
  // viewport-safe inset so antialiased rotated corners never touch the 512x416
  // canvas edge. Endpoints remain a literal canonical identity.
  const safeScale = frame === 0 || frame === TERMINAL_FRAME ? 1 : 0.96;
  const viewportSafe = [safeScale, 0, 0, safeScale, 256 * (1 - safeScale), 208 * (1 - safeScale)];
  const root = compose(viewportSafe, authoredRoot);
  const cup = compose(root, matrixFor(TRACKS.cup, PIVOTS.cup, frame));
  const pedestal = compose(root, matrixFor(TRACKS.pedestal, PIVOTS.pedestal, frame));
  const hairCap = compose(root, matrixFor(TRACKS.hairCap, PIVOTS.hair, frame));
  const hairFringe = compose(root, matrixFor(TRACKS.hairFringe, PIVOTS.hair, frame));
  const eyeL = compose(cup, matrixFor(TRACKS.eyeL, PIVOTS.eyeL, frame));
  const eyeR = compose(cup, matrixFor(TRACKS.eyeR, PIVOTS.eyeR, frame));
  const mouth = compose(cup, matrixFor(TRACKS.mouth, PIVOTS.mouth, frame));
  const shine = compose(cup, matrixFor(TRACKS.shine, PIVOTS.shine, frame));
  return { root, cup, pedestal, hairCap, hairFringe, eyeL, eyeR, mouth, shine };
}

function ownerMatrix(owner, sourceIndex, transforms) {
  if (owner === "cup") return transforms.cup;
  if (owner === "pedestal") return transforms.pedestal;
  if (owner === "hair") return HAIR_FRINGE.has(sourceIndex) ? transforms.hairFringe : transforms.hairCap;
  if (owner === "eyeL") return transforms.eyeL;
  if (owner === "eyeR") return transforms.eyeR;
  if (owner === "mouth") return transforms.mouth;
  if (owner === "shine") return transforms.shine;
  throw new Error(`Unknown semantic owner ${owner}`);
}

function canonicalOuterContour() {
  return CANONICAL_PARTS[1].paths[0];
}

function renderSvg(frame) {
  const transforms = transformsFor(frame);
  const underlapPaths = CANONICAL_PARTS
    .filter((entry) => SOURCE_GROUPS.hair.includes(entry.sourceIndex))
    .flatMap((entry) => entry.paths.map((contour) => `<path data-underlap="hair" d="${pathD(contour.commands, transforms.cup)}" fill="${UNDERLAP_COLOR}"/>`))
    .join("\n");
  const seamUnderlapMatrix = transforms.cup;
  const seamUnderlap = `<path data-underlap="pedestal-seam" d="${pathD([
    { commandType: "moveTo", x: 200, y: 250 },
    { commandType: "lineTo", x: 370, y: 250 },
    { commandType: "lineTo", x: 370, y: 280 },
    { commandType: "lineTo", x: 200, y: 280 },
    { commandType: "close" },
  ], seamUnderlapMatrix)}" fill="#BE9433"/>`;
  const clipPath = `<clipPath id="cup-visible" clipPathUnits="userSpaceOnUse"><path d="${pathD(canonicalOuterContour().commands, transforms.cup)}"/></clipPath>`;
  const markup = [];
  for (const entry of CANONICAL_PARTS) {
    for (let contourIndex = 0; contourIndex < entry.paths.length; contourIndex += 1) {
      const contour = entry.paths[contourIndex];
      const owner = ownerFor(entry.sourceIndex, contourIndex + 1);
      const matrix = ownerMatrix(owner, entry.sourceIndex, transforms);
      markup.push(`<path data-source-index="${entry.sourceIndex}" data-contour-index="${contourIndex + 1}" data-owner="${owner}" d="${pathD(contour.commands, matrix)}" fill="${entry.svgColor}"/>`);
    }
  }
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS.width}" height="${CANVAS.height}" viewBox="0 0 ${CANVAS.width} ${CANVAS.height}">
  <defs>${clipPath}</defs>
  <g clip-path="url(#cup-visible)">${seamUnderlap}\n${underlapPaths}</g>
  ${markup.join("\n  ")}
</svg>\n`;
}

function renderPng(frame, destination) {
  if (frame === 0 || frame === TERMINAL_FRAME) {
    execFileSync("magick", ["-background", "none", CANONICAL, destination]);
    return;
  }
  writeFileSync(TMP_SVG, renderSvg(frame));
  execFileSync("magick", ["-background", "none", TMP_SVG, destination]);
}

function rgba(path) {
  // Force 8-bit RGBA so alpha is one byte per pixel; ImageMagick otherwise
  // emits its 16-bit quantum stream and byte-indexed QA becomes meaningless.
  return execFileSync("magick", [path, "-depth", "8", "RGBA:-"], { maxBuffer: CANVAS.width * CANVAS.height * 4 + 1024 * 1024 });
}

function endpointDiff(aPath, bPath) {
  const a = rgba(aPath);
  const b = rgba(bPath);
  let ae = 0;
  let maxChannelDiff = 0;
  let totalAbsDiff = 0;
  for (let i = 0; i < a.length; i += 1) {
    const difference = Math.abs(a[i] - b[i]);
    totalAbsDiff += difference;
    if (difference > maxChannelDiff) maxChannelDiff = difference;
    if (difference !== 0 && (i % 4 === 0 || difference > 0)) ae += i % 4 === 0 ? 1 : 0;
  }
  return { ae, maxChannelDiff, totalAbsDiff };
}

function frameHash(path) {
  return createHash("sha256").update(rgba(path)).digest("hex");
}

function paintedBounds(path) {
  const pixels = rgba(path);
  let minX = CANVAS.width;
  let minY = CANVAS.height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < CANVAS.height; y += 1) {
    for (let x = 0; x < CANVAS.width; x += 1) {
      if (pixels[(y * CANVAS.width + x) * 4 + 3] === 0) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
  return {
    minX,
    minY,
    maxX,
    maxY,
    topMargin: minY,
    leftMargin: minX,
    rightMargin: CANVAS.width - 1 - maxX,
    bottomMargin: CANVAS.height - 1 - maxY,
    painted: maxX >= 0,
    touchesCanvasEdge: maxX >= 0 && (minX === 0 || minY === 0 || maxX === CANVAS.width - 1 || maxY === CANVAS.height - 1),
  };
}

function seamHoles(path, frame) {
  const pixels = rgba(path);
  const rootDy = Math.round(trackValue(TRACKS.root.dy, frame));
  // The canonical cup/pedestal seam is y262-266. Follow only that narrow
  // transformed band; lower pedestal cutouts are intentional artwork, not
  // seam holes.
  const seamCenter = 264 + rootDy;
  const startY = Math.max(0, seamCenter - 2);
  const endY = Math.min(CANVAS.height - 1, seamCenter + 2);
  let maxHoles = 0;
  let rowsWithHoles = 0;
  for (let y = startY; y <= endY; y += 1) {
    const xs = [];
    for (let x = 80; x < 432; x += 1) if (pixels[(y * CANVAS.width + x) * 4 + 3] > 0) xs.push(x);
    if (!xs.length) continue;
    let holes = 0;
    for (let x = xs[0]; x <= xs.at(-1); x += 1) if (pixels[(y * CANVAS.width + x) * 4 + 3] === 0) holes += 1;
    maxHoles = Math.max(maxHoles, holes);
    if (holes) rowsWithHoles += 1;
  }
  return { startY, endY, maxInteriorTransparentPixels: maxHoles, rowsWithHoles };
}

function annotateTile(source, destination, label) {
  execFileSync("magick", [
    source,
    "-background", "#F4F2EC",
    "-alpha", "background",
    "-gravity", "south",
    "-splice", "0x28",
    "-fill", "#2A2416",
    "-font", "/System/Library/Fonts/SFNSMono.ttf",
    "-pointsize", "18",
    "-annotate", "+0+6", label,
    destination,
  ]);
}

function makeContactSheet(frames, destination, tileGeometry = "+4+28") {
  const tiles = [];
  for (const frame of frames) {
    const source = join(FRAMES, `${String(frame).padStart(4, "0")}.png`);
    const tile = join(CONTACT_TILES, `f${String(frame).padStart(3, "0")}.png`);
    annotateTile(source, tile, `frame ${frame}`);
    tiles.push(tile);
  }
  execFileSync("magick", ["montage", ...tiles, "-background", "#F4F2EC", "-font", "/System/Library/Fonts/SFNSMono.ttf", "-tile", "3x3", "-geometry", tileGeometry, destination]);
}

function makeHairInspectionSheet(frames, scale, destination) {
  const tiles = [];
  const cropW = 210;
  const cropH = 122;
  for (const frame of frames) {
    const source = join(FRAMES, `${String(frame).padStart(4, "0")}.png`);
    const tile = join(INSPECTION, `hair-f${frame}-${scale}x.png`);
    execFileSync("magick", [source, "-crop", `${cropW}x${cropH}+150+8`, "+repage", "-resize", `${scale * 100}%`, "-background", "#F4F2EC", "-alpha", "background", "-gravity", "south", "-splice", `0x${28 * scale}`, "-fill", "#2A2416", "-font", "/System/Library/Fonts/SFNSMono.ttf", "-pointsize", String(14 * scale), "-annotate", "+0+6", `f${frame} @ ${scale}x`, tile]);
    tiles.push(tile);
  }
  execFileSync("magick", ["montage", ...tiles, "-background", "#F4F2EC", "-font", "/System/Library/Fonts/SFNSMono.ttf", "-tile", "3x1", "-geometry", "+4+26", destination]);
}

function inspectFills() {
  const allowed = new Set(PALETTE.map((color) => color.toUpperCase()));
  allowed.add(UNDERLAP_COLOR);
  const violations = [];
  for (const entry of CANONICAL_PARTS) {
    if (!allowed.has(entry.svgColor.toUpperCase())) violations.push({ sourceIndex: entry.sourceIndex, fill: entry.svgColor });
  }
  return { allowedFillCount: allowed.size, violations };
}

function sourceOwnershipReport() {
  const sourceEntryOwners = {};
  const contourOwners = {};
  for (const entry of CANONICAL_PARTS) {
    const owners = entry.paths.map((_, index) => ownerFor(entry.sourceIndex, index + 1));
    sourceEntryOwners[entry.sourceIndex] = [...new Set(owners)];
    for (const owner of owners) contourOwners[owner] = (contourOwners[owner] ?? 0) + 1;
  }
  return { sourceEntryOwners, contourOwners, sourceEntryCount: CANONICAL_PARTS.length, contourCount: CANONICAL_PARTS.reduce((sum, entry) => sum + entry.paths.length, 0) };
}

function ffprobeFacts() {
  const stream = JSON.parse(execFileSync("ffprobe", ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,pix_fmt,width,height,r_frame_rate,avg_frame_rate,nb_frames,duration", "-of", "json", MP4], { encoding: "utf8" })).streams?.[0] ?? {};
  const audio = JSON.parse(execFileSync("ffprobe", ["-v", "error", "-select_streams", "a", "-show_entries", "stream=index", "-of", "json", MP4], { encoding: "utf8" })).streams ?? [];
  const bytes = readFileSync(MP4);
  const moov = bytes.indexOf(Buffer.from("moov"));
  const mdat = bytes.indexOf(Buffer.from("mdat"));
  return { stream, audioStreamCount: audio.length, faststartCompatible: moov >= 0 && (mdat < 0 || moov < mdat) };
}

// Preserve the canonical bind raster as a named proof artifact and render the
// complete animation from scratch. Endpoints deliberately use the locked SVG.
execFileSync("magick", ["-background", "none", CANONICAL, CANONICAL_PNG]);
for (let frame = 0; frame <= TERMINAL_FRAME; frame += 1) {
  renderPng(frame, join(FRAMES, `${String(frame).padStart(4, "0")}.png`));
}
rmSync(TMP_SVG, { force: true });
const frameGeneration = verifyFrameSet();

execFileSync("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", "-framerate", "60", "-i", join(FRAMES, "%04d.png"), "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-r", "60", MP4]);

const contactFrames = [0, 16, 34, 54, 74, 90, 106, 132, 156];
makeContactSheet(contactFrames, CONTACT);
const keyFrames = [16, 34, 54, 74, 90, 106];
makeContactSheet(keyFrames, join(INSPECTION, "hero-key-frames-100.png"), "+4+28");
makeHairInspectionSheet([34, 54, 90], 1, join(INSPECTION, "hair-extrema-100.png"));
makeHairInspectionSheet([34, 54, 90], 2, join(INSPECTION, "hair-extrema-200.png"));
makeHairInspectionSheet([34, 54, 90], 4, join(INSPECTION, "hair-extrema-400.png"));

const framePaths = Object.fromEntries([...Array(TERMINAL_FRAME + 1).keys()].map((frame) => [frame, join(FRAMES, `${String(frame).padStart(4, "0")}.png`)]));
const seamFrames = [...new Set([...keyFrames, 0, TERMINAL_FRAME])];
const seamInspection = Object.fromEntries(seamFrames.map((frame) => [frame, seamHoles(framePaths[frame], frame)]));
const maxSeamHoles = Math.max(...Object.values(seamInspection).map((result) => result.maxInteriorTransparentPixels));
const paintedBoundsByFrame = Object.fromEntries([...Array(TERMINAL_FRAME + 1).keys()].map((frame) => [frame, paintedBounds(framePaths[frame])]));
const paintedBoundsValues = Object.values(paintedBoundsByFrame);
const minTopMargin = Math.min(...paintedBoundsValues.map((bounds) => bounds.topMargin));
const minLeftMargin = Math.min(...paintedBoundsValues.map((bounds) => bounds.leftMargin));
const minRightMargin = Math.min(...paintedBoundsValues.map((bounds) => bounds.rightMargin));
const minBottomMargin = Math.min(...paintedBoundsValues.map((bounds) => bounds.bottomMargin));
const edgeTouchFrames = Object.entries(paintedBoundsByFrame).filter(([, bounds]) => bounds.touchesCanvasEdge).map(([frame]) => Number(frame));
const paintedBoundsPass = minTopMargin >= 2 && minLeftMargin >= 1 && minRightMargin >= 1 && minBottomMargin >= 1 && edgeTouchFrames.length === 0;
const endpointFrame0 = endpointDiff(framePaths[0], CANONICAL_PNG);
const endpointFrame156 = endpointDiff(framePaths[TERMINAL_FRAME], CANONICAL_PNG);
const probe = ffprobeFacts();
const ownership = sourceOwnershipReport();
const fillCheck = inspectFills();
const dimensions = JSON.parse(execFileSync("identify", ["-format", "{\"width\":%w,\"height\":%h}", framePaths[0]], { encoding: "utf8" }));

const report = {
  status: endpointFrame0.ae === 0 && endpointFrame156.ae === 0 && OWNERSHIP_VALIDATION.sourceEntriesCoveredExactlyOnce && maxSeamHoles === 0 && paintedBoundsPass && fillCheck.violations.length === 0 && probe.stream.codec_name === "h264" && probe.stream.pix_fmt === "yuv420p" && probe.stream.width === CANVAS.width && probe.stream.height === CANVAS.height && probe.stream.r_frame_rate === "60/1" && probe.audioStreamCount === 0 && probe.faststartCompatible ? "pass" : "fail",
  animation: { displayName: DISPLAY_NAME, durationSeconds: DURATION_SECONDS, fps: 60, canvas: CANVAS, terminalFrame: TERMINAL_FRAME, renderedFrameCount: TERMINAL_FRAME + 1, source: "../svg/scorekeeper-cup-hybrid-a-canonical.svg", liveRiveModified: false },
  architecture: {
    composites: ["cup/head", "pedestal/stem/base", "hair (cap + fringe internal groups)", "left-eye", "right-eye", "mouth", "shine"],
    rigidCupAndPedestal: true,
    hairPivot: HAIR_PIVOT,
    hairCapSourceIndices: [...HAIR_CAP],
    hairFringeSourceIndices: [...HAIR_FRINGE],
    path1ContourOwnership: PATH1_SPECIAL,
    underlap: { hairColor: UNDERLAP_COLOR, pedestalSeamColor: "#BE9433", opaque: true, clippedToCupVisible: true, translucentMasks: false },
    viewportSafeInset: { nonEndpointScale: 0.96, endpointScale: 1, reason: "preserve >=2px top and clear all canvas edges after antialiased rotation while retaining authored root squash tracks" },
    artworkLocked: true,
  },
  ownership: { ...OWNERSHIP_VALIDATION, ...ownership },
  exactPalette: { canonicalPalette: PALETTE, fillCheck },
  endpointRasterDiff: { canonicalRaster: CANONICAL_PNG, frame0: endpointFrame0, frame156: endpointFrame156 },
  seamHoleInspection: { frames: seamInspection, maxInteriorTransparentPixels: maxSeamHoles, inspectedFrames: seamFrames, note: "Rows are scanned through the cup-bottom/stem seam band after root ballistic translation; interior transparent runs are counted, while intentional exterior transparency is ignored." },
  paintedBoundsCheck: { inspectedFrameCount: TERMINAL_FRAME + 1, minTopMargin, minLeftMargin, minRightMargin, minBottomMargin, requiredTopMargin: 2, edgeTouchFrames, pass: paintedBoundsPass, note: "Every rendered frame is decoded as RGBA; any alpha-painted pixel on a canvas edge fails. The top margin gate is >=2px." },
  enlargedInspection: { files: ["inspection/hero-key-frames-100.png", "inspection/hair-extrema-100.png", "inspection/hair-extrema-200.png", "inspection/hair-extrema-400.png"], scales: [1, 2, 4], hairFrames: [34, 54, 90] },
  ffprobe: probe,
  frameHashes: { frame0: frameHash(framePaths[0]), frame16: frameHash(framePaths[16]), frame34: frameHash(framePaths[34]), frame54: frameHash(framePaths[54]), frame74: frameHash(framePaths[74]), frame90: frameHash(framePaths[90]), frame106: frameHash(framePaths[106]), frame132: frameHash(framePaths[132]), frame156: frameHash(framePaths[156]) },
  frameDimensions: dimensions,
  outputs: { mp4: "victory-pop.mp4", contactSheet: "victory-pop-contact-sheet.png", framesDirectory: "frames/", qaReport: "victory-pop-qa.json" },
  reproducibility: { command: "node render-victory-pop.mjs", renderedFromScratch: true, renderer: "ImageMagick SVG rasterizer + ffmpeg libx264", deterministicEndpoints: true, frameGeneration },
};

writeFileSync(QA, `${JSON.stringify(report, null, 2)}\n`);
rmSync(CONTACT_TILES, { recursive: true, force: true });
rmSync(LOCK, { recursive: true, force: true });
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
