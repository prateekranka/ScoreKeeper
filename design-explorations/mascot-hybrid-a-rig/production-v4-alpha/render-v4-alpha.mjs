#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  CANVAS,
  FPS,
  DURATION_SECONDS,
  FRAME_COUNT,
  TERMINAL_FRAME,
  OUTPUT_FPS,
  DISPLAY_NAME,
  CLEANUP,
  REMOVED_SOURCE_INDICES,
  PIVOTS,
  TRACKS,
  CONTROL_NAMES,
  semanticControlFor,
  SOURCE_002_LIMITATION,
} from "./v4-alpha-spec.mjs";
import { CANONICAL_PARTS, PALETTE, ROOT_PIVOT, HAIR_SOURCE_PATH_INDICES } from "../rig-spec.mjs";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SOURCE = join(ROOT, "../svg/scorekeeper-cup-hybrid-a-canonical.svg");
const OUTPUT = ROOT;
const STAGING = join(ROOT, `.staging-v4-alpha-${process.pid}`);
const LOCK = join(ROOT, ".render.lock");
const FRAMES = join(OUTPUT, "frames");
const INSPECTION = join(OUTPUT, "inspection");
const CONTACT = join(OUTPUT, "v4-alpha-hero-contact-sheet.png");
const CLEANED_SVG = join(OUTPUT, "cleaned-canonical.svg");
const CLEANED_PNG = join(OUTPUT, "cleaned-canonical-bind.png");
const MOV = join(OUTPUT, "v4-alpha-hero-alpha-prores4444.mov");
const MP4 = join(OUTPUT, "v4-alpha-hero-opaque-blue-preview.mp4");
const QA = join(OUTPUT, "qa.json");
const TMP_SVG = join(STAGING, "frame.svg");
const TMP_MASK_SVG = join(STAGING, "mask.svg");
const PROBE_DIR = join(ROOT, ".probe-v4-alpha");
const BLUE = "#0057FF";
const CHECKER = "#F4F2EC";
let releaseRenderLock = () => {};
const SYNTHETIC_UNDERLAPS = Object.freeze([
  { id: "hair-cup-local-underlap", fill: "#EFB944", sourceIndices: [...HAIR_SOURCE_PATH_INDICES], transform: "cup", purpose: "keeps the moving hair cap/fringe attached to the cup silhouette" },
  { id: "pedestal-seam-underlap", fill: "#8C651F", bounds: { x: 205, y: 258, width: 100, height: 18 }, transform: "rig_root", purpose: "bounded seam bridge behind the cup/stem attachment" },
]);

function sleepMs(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function acquireRenderLock() {
  const started = Date.now();
  for (;;) {
    try {
      mkdirSync(LOCK);
      writeFileSync(join(LOCK, "owner.json"), JSON.stringify({ pid: process.pid, startedAt: new Date().toISOString() }));
      const timer = setInterval(() => {
        try { writeFileSync(join(LOCK, "heartbeat"), `${Date.now()}\n`); } catch { /* process is exiting */ }
      }, 5_000);
      const release = () => { clearInterval(timer); rmSync(LOCK, { recursive: true, force: true }); };
      releaseRenderLock = release;
      process.on("exit", release);
      process.on("SIGINT", () => { release(); process.exit(130); });
      process.on("SIGTERM", () => { release(); process.exit(143); });
      writeFileSync(join(LOCK, "heartbeat"), `${Date.now()}\n`);
      return;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      let stale = false;
      try {
        const heartbeat = Number(readFileSync(join(LOCK, "heartbeat"), "utf8"));
        stale = Number.isFinite(heartbeat) && Date.now() - heartbeat > 15 * 60 * 1000;
      } catch {
        try { stale = Date.now() - statSync(LOCK).mtimeMs > 15 * 60 * 1000; } catch { /* retry */ }
      }
      if (stale) { rmSync(LOCK, { recursive: true, force: true }); continue; }
      if (Date.now() - started > 20 * 60 * 1000) throw new Error(`Timed out waiting for renderer lock ${LOCK}`);
      sleepMs(250);
    }
  }
}

function parseSourceEntries() {
  const svg = readFileSync(SOURCE, "utf8");
  const pattern = /<path\s+d="([^"]+)"\s+fill="(#[0-9A-Fa-f]{6})"(?:\s+transform="translate\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)")?\s*\/>/g;
  const entries = [];
  let match;
  while ((match = pattern.exec(svg))) {
    const [, d, fill, txRaw = "0", tyRaw = "0"] = match;
    const tx = Number(txRaw); const ty = Number(tyRaw);
    const tokens = d.match(/[MLZ]|-?\d+(?:\.\d+)?/g) ?? [];
    const paths = []; let commands = [];
    for (let cursor = 0; cursor < tokens.length;) {
      const token = tokens[cursor++];
      if (token === "M" || token === "L") {
        commands.push({ commandType: token === "M" ? "moveTo" : "lineTo", x: Number(tokens[cursor++]) + tx, y: Number(tokens[cursor++]) + ty });
      } else if (token === "Z") {
        commands.push({ commandType: "close" }); paths.push(commands); commands = [];
      } else throw new Error(`Unsupported canonical token ${token}`);
    }
    if (commands.length) throw new Error(`Unclosed canonical path ${entries.length + 1}`);
    entries.push({ sourceIndex: entries.length + 1, d, fill: fill.toUpperCase(), tx, ty, paths });
  }
  if (entries.length !== CANONICAL_PARTS.length) throw new Error(`Expected ${CANONICAL_PARTS.length} source entries, found ${entries.length}`);
  return entries;
}

const ENTRIES = parseSourceEntries();

function cubic(t, p1, p2) {
  const mt = 1 - t;
  return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t;
}

function cubicProgress(progress, p1x, p1y, p2x, p2y) {
  let lo = 0; let hi = 1; let t = progress;
  for (let i = 0; i < 16; i += 1) {
    const x = cubic(t, p1x, p2x);
    if (x < progress) lo = t; else hi = t;
    t = (lo + hi) / 2;
  }
  return cubic(t, p1y, p2y);
}

function ease(progress, mode = "smooth") {
  if (mode === "linear") return progress;
  if (mode === "easeIn") return cubicProgress(progress, 0.7, 0, 0.84, 0);
  if (mode === "easeOut") return cubicProgress(progress, 0.16, 1, 0.3, 1);
  if (mode === "easeInOut") return cubicProgress(progress, 0.65, 0, 0.35, 1);
  return cubicProgress(progress, 0.42, 0, 0.58, 1);
}

function trackKeys(track) { return Array.isArray(track) ? track : track?.keys; }

function trackValue(track, frame, fallback = 0) {
  if (!track) return fallback;
  const keys = trackKeys(track); if (!keys?.length) return fallback;
  if (frame <= keys[0][0]) return keys[0][1];
  if (frame >= keys.at(-1)[0]) return keys.at(-1)[1];
  for (let i = 0; i < keys.length - 1; i += 1) {
    const start = keys[i]; const end = keys[i + 1];
    if (frame < start[0] || frame > end[0]) continue;
    if (track.interpolation === "step") return start[1];
    const t = (frame - start[0]) / (end[0] - start[0]);
    return start[1] + (end[1] - start[1]) * ease(t, start[2] ?? "smooth");
  }
  return keys.at(-1)[1];
}

function matrixFor(track, pivot, frame) {
  const dx = trackValue(track?.dx, frame);
  const dy = trackValue(track?.dy, frame);
  const rotation = (trackValue(track?.rotationDeg, frame) * Math.PI) / 180;
  const scaleX = trackValue(track?.scaleX, frame, 1) || 1;
  const scaleY = trackValue(track?.scaleY, frame, 1) || 1;
  const cos = Math.cos(rotation); const sin = Math.sin(rotation);
  const a = cos * scaleX; const b = sin * scaleX; const c = -sin * scaleY; const d = cos * scaleY;
  return [a, b, c, d, pivot.x + dx - a * pivot.x - c * pivot.y, pivot.y + dy - b * pivot.x - d * pivot.y];
}

function compose(parent, child) {
  const [a, b, c, d, e, f] = parent; const [g, h, i, j, k, l] = child;
  return [a * g + c * h, b * g + d * h, a * i + c * j, b * i + d * j, a * k + c * l + e, b * k + d * l + f];
}

function rootSafeMatrix(frame) {
  const p = frame / TERMINAL_FRAME;
  // Eased viewport-safe inset returns to exact identity at both endpoints,
  // avoiding a frame0→1 or penultimate→terminal scale snap.
  const safeScale = Math.max(0.84, 1 - 0.24 * Math.sin(Math.PI * p));
  return [safeScale, 0, 0, safeScale, 256 * (1 - safeScale), 208 * (1 - safeScale)];
}

function transformsFor(frame) {
  const root = compose(rootSafeMatrix(frame), matrixFor(TRACKS.rig_root, PIVOTS.rig_root, frame));
  const cup = compose(root, matrixFor(TRACKS.cup, PIVOTS.cup, frame));
  const pedestal = compose(root, matrixFor(TRACKS.pedestal, PIVOTS.pedestal, frame));
  const handleL = compose(cup, matrixFor(TRACKS.handleL, PIVOTS.handleL, frame));
  const handleR = compose(cup, matrixFor(TRACKS.handleR, PIVOTS.handleR, frame));
  const hairCap = compose(cup, matrixFor(TRACKS.hair_cap, PIVOTS.hair_cap, frame));
  const hairFringe = compose(hairCap, matrixFor(TRACKS.hair_fringe, PIVOTS.hair_fringe, frame));
  const eyeL = compose(cup, matrixFor(TRACKS.eyeL, PIVOTS.eyeL, frame));
  const eyeR = compose(cup, matrixFor(TRACKS.eyeR, PIVOTS.eyeR, frame));
  const mouth = compose(cup, matrixFor(TRACKS.mouth, PIVOTS.mouth, frame));
  const shine = compose(cup, matrixFor(TRACKS.shine, PIVOTS.shine, frame));
  return { rig_root: root, cup, pedestal, handleL, handleR, hair_cap: hairCap, hair_fringe: hairFringe, eyeL, eyeR, mouth, shine };
}

function pointFor(matrix, x, y) {
  return [matrix[0] * x + matrix[2] * y + matrix[4], matrix[1] * x + matrix[3] * y + matrix[5]];
}

function fmt(value) { return Number(value.toFixed(5)); }

function pathD(commands, matrix = [1, 0, 0, 1, 0, 0]) {
  return commands.map((command) => {
    if (command.commandType === "close") return "Z";
    const [x, y] = pointFor(matrix, command.x, command.y);
    return `${command.commandType === "moveTo" ? "M" : "L"}${fmt(x)},${fmt(y)}`;
  }).join(" ");
}

function ownerFor(entry, contourIndex) {
  // The exact v2 contour classifier supplies handle and hair controls. It
  // intentionally leaves source_002 contour1 cup-owned (combined silhouette).
  if (entry.sourceIndex === 2 && contourIndex === 1) return "cup";
  return semanticControlFor(entry.sourceIndex, contourIndex);
}

function opacityFor(control, frame) {
  const track = TRACKS[control]?.opacity;
  return track ? trackValue(track, frame, 1) : 1;
}

function maskMarkup(transforms) {
  const left = CLEANUP.leftHole.flatMap((sourceIndex) => ENTRIES[sourceIndex - 1].paths).map((commands) => `<path d="${pathD(commands, transforms.handleL)}" fill="black"/>`).join("\n");
  const right = CLEANUP.rightHole.flatMap((sourceIndex) => ENTRIES[sourceIndex - 1].paths).map((commands) => `<path d="${pathD(commands, transforms.handleR)}" fill="black"/>`).join("\n");
  return `${left}${right}`;
}

function renderMaskSvg(frame) {
  const transforms = transformsFor(frame);
  return `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS.width}" height="${CANVAS.height}" viewBox="0 0 ${CANVAS.width} ${CANVAS.height}">${maskMarkup(transforms)}</svg>\n`;
}

function renderSvg(frame) {
  const transforms = transformsFor(frame);
  const markup = [];
  const hairUnderlap = HAIR_SOURCE_PATH_INDICES.flatMap((sourceIndex) => ENTRIES[sourceIndex - 1].paths).map((commands) => `<path data-underlap="hair-cup-local" d="${pathD(commands, transforms.cup)}" fill="#EFB944"/>`).join("\n");
  const seamCommands = [{ commandType: "moveTo", x: 205, y: 258 }, { commandType: "lineTo", x: 305, y: 258 }, { commandType: "lineTo", x: 305, y: 276 }, { commandType: "lineTo", x: 205, y: 276 }, { commandType: "close" }];
  const seamUnderlap = `<path data-underlap="pedestal-seam" d="${pathD(seamCommands, transforms.rig_root)}" fill="#8C651F"/>`;
  for (const entry of ENTRIES) {
    if (REMOVED_SOURCE_INDICES.includes(entry.sourceIndex)) continue;
    for (let contourIndex = 0; contourIndex < entry.paths.length; contourIndex += 1) {
      const control = ownerFor(entry, contourIndex + 1);
      const matrix = transforms[control] ?? transforms.cup;
      const opacity = opacityFor(control, frame);
      markup.push(`<path data-source-index="${entry.sourceIndex}" data-contour-index="${contourIndex + 1}" data-owner="${control}" d="${pathD(entry.paths[contourIndex], matrix)}" fill="${entry.fill}"${opacity < 0.99999 ? ` opacity="${fmt(opacity)}"` : ""}/>`);
    }
  }
  return `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS.width}" height="${CANVAS.height}" viewBox="0 0 ${CANVAS.width} ${CANVAS.height}"><g>${seamUnderlap}\n${hairUnderlap}\n${markup.join("\n")}</g></svg>\n`;
}

function writeCleanedCanonical() {
  const body = ENTRIES.filter((entry) => !REMOVED_SOURCE_INDICES.includes(entry.sourceIndex)).map((entry) => {
    // Reconstruct each retained path from its original d/fill/translate values
    // so shine 29/98/139 and every retained canonical path stay byte-identical.
    const transform = entry.tx || entry.ty ? ` transform="translate(${entry.tx},${entry.ty})"` : "";
    return `<path d="${entry.d}" fill="${entry.fill}"${transform}/>`;
  }).join("\n");
  const cleaned = `<?xml version="1.0" encoding="UTF-8"?>\n<!-- v4-alpha cleaned canonical: omitted source paths are represented by post-raster alpha masks. -->\n<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="${CANVAS.width}" height="${CANVAS.height}"><g>\n${body}\n</g></svg>\n`;
  writeFileSync(CLEANED_SVG, cleaned);
  return cleaned;
}

function rgbaFromPath(path) {
  return execFileSync("magick", ["-background", "none", path, "-depth", "8", "RGBA:-"], { maxBuffer: CANVAS.width * CANVAS.height * 4 + 1024 * 1024 });
}

function normalizeRgba(raw) {
  const out = Buffer.from(raw);
  for (let i = 0; i < out.length; i += 4) if (out[i + 3] === 0) { out[i] = 0; out[i + 1] = 0; out[i + 2] = 0; }
  return out;
}

function writePngFromRgba(raw, destination) {
  const result = spawnSync("magick", ["-size", `${CANVAS.width}x${CANVAS.height}`, "-depth", "8", "RGBA:-", "PNG32:" + destination], { input: normalizeRgba(raw), maxBuffer: 1024 * 1024 });
  if (result.status !== 0) throw new Error(`magick PNG write failed: ${result.stderr?.toString() ?? ""}`);
}

function renderPngFromSvg(svgPath, destination) {
  writePngFromRgba(rgbaFromPath(svgPath), destination);
}

function applyHoleMask(art, mask) {
  const out = Buffer.from(art);
  for (let i = 0; i < out.length; i += 4) {
    const holeAlpha = mask[i + 3];
    const alpha = Math.round(out[i + 3] * (255 - holeAlpha) / 255);
    out[i + 3] = alpha;
    if (alpha === 0) { out[i] = 0; out[i + 1] = 0; out[i + 2] = 0; }
  }
  return out;
}

function renderPngWithMask(svgPath, frame, destination) {
  writeFileSync(TMP_MASK_SVG, renderMaskSvg(frame));
  const art = rgbaFromPath(svgPath);
  const mask = rgbaFromPath(TMP_MASK_SVG);
  writePngFromRgba(applyHoleMask(art, mask), destination);
}

function renderFrame(frame, destination) {
  writeFileSync(TMP_SVG, renderSvg(frame));
  renderPngWithMask(TMP_SVG, frame, destination);
}

function frameHash(path) { return createHash("sha256").update(readFileSync(path)).digest("hex"); }
function rgbaHash(path) { return createHash("sha256").update(normalizeRgba(rgbaFromPath(path))).digest("hex"); }

function pixelDiff(aPath, bPath) {
  const a = normalizeRgba(rgbaFromPath(aPath)); const b = normalizeRgba(rgbaFromPath(bPath));
  let pixels = 0; let rgbPixels = 0; let alphaPixels = 0; let max = 0; let rgbAbs = 0; let alphaAbs = 0;
  for (let i = 0; i < a.length; i += 4) {
    const dr = Math.abs(a[i] - b[i]); const dg = Math.abs(a[i + 1] - b[i + 1]); const db = Math.abs(a[i + 2] - b[i + 2]); const da = Math.abs(a[i + 3] - b[i + 3]);
    const rgb = dr + dg + db;
    max = Math.max(max, dr, dg, db, da); rgbAbs += rgb; alphaAbs += da;
    if (rgb || da) pixels += 1; if (rgb) rgbPixels += 1; if (da) alphaPixels += 1;
  }
  return { anyChannelPixelAE: pixels, rgbPixelAE: rgbPixels, alphaPixelAE: alphaPixels, maxChannelDelta: max, totalRgbAbs: rgbAbs, totalAlphaAbs: alphaAbs };
}

function alphaStats(path) {
  const rgba = normalizeRgba(rgbaFromPath(path)); let transparent = 0; let partial = 0; let opaque = 0; let nonzeroRgbTransparent = 0;
  for (let i = 0; i < rgba.length; i += 4) {
    const alpha = rgba[i + 3]; if (alpha === 0) { transparent += 1; if (rgba[i] || rgba[i + 1] || rgba[i + 2]) nonzeroRgbTransparent += 1; } else if (alpha === 255) opaque += 1; else partial += 1;
  }
  return { transparent, partial, opaque, nonzeroRgbTransparent };
}

function paintedBounds(path) {
  const rgba = normalizeRgba(rgbaFromPath(path)); let minX = CANVAS.width; let minY = CANVAS.height; let maxX = -1; let maxY = -1;
  for (let y = 0; y < CANVAS.height; y += 1) for (let x = 0; x < CANVAS.width; x += 1) if (rgba[(y * CANVAS.width + x) * 4 + 3] > 0) { minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y); }
  return { minX, minY, maxX, maxY, topMargin: minY, leftMargin: minX, rightMargin: CANVAS.width - 1 - maxX, bottomMargin: CANVAS.height - 1 - maxY, touchesCanvasEdge: minX === 0 || minY === 0 || maxX === CANVAS.width - 1 || maxY === CANVAS.height - 1 };
}

function verifyFrameSet(dir) {
  const expected = [...Array(FRAME_COUNT).keys()].map((frame) => `${String(frame).padStart(4, "0")}.png`);
  const actual = readdirSync(dir).filter((file) => /^\d{4}\.png$/.test(file)).sort();
  return { expectedCount: expected.length, actualCount: actual.length, missing: expected.filter((file) => !actual.includes(file)), unexpected: actual.filter((file) => !expected.includes(file)), pass: expected.length === actual.length && expected.every((file) => actual.includes(file)) };
}

function annotateTile(source, destination, label, bg = BLUE) {
  execFileSync("magick", [source, "-background", bg, "-alpha", "background", "-gravity", "south", "-splice", "0x30", "-fill", "white", "-font", "/System/Library/Fonts/SFNSMono.ttf", "-pointsize", "18", "-annotate", "+0+7", label, destination]);
}

function makeContactSheet(frameDir, destination, frames) {
  const tileDir = join(STAGING, "contact-tiles"); mkdirSync(tileDir, { recursive: true });
  const tiles = frames.map((frame) => { const tile = join(tileDir, `f${String(frame).padStart(3, "0")}.png`); annotateTile(join(frameDir, `${String(frame).padStart(4, "0")}.png`), tile, `frame ${frame}`); return tile; });
  const tileLayout = frames.length > 9 ? "4x3" : "3x3";
  execFileSync("magick", ["montage", ...tiles, "-background", BLUE, "-font", "/System/Library/Fonts/SFNSMono.ttf", "-tile", tileLayout, "-geometry", "+6+30", destination]);
}

function makeInspection(frameDir, scale, frame) {
  const source = join(frameDir, `${String(frame).padStart(4, "0")}.png`);
  const destination = join(STAGING, "inspection", `hero-f${String(frame).padStart(3, "0")}-${scale}x.png`);
  execFileSync("magick", [source, "-crop", "420x390+46+8", "+repage", "-resize", `${scale * 100}%`, "-background", CHECKER, "-alpha", "background", destination]);
  return destination;
}

function makeProres(frameDir, destination) {
  execFileSync("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", "-framerate", String(OUTPUT_FPS), "-i", join(frameDir, "%04d.png"), "-an", "-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le", "-alpha_bits", "16", destination]);
}

function makeOpaqueMp4(frameDir, destination) {
  execFileSync("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", `color=c=${BLUE}:s=${CANVAS.width}x${CANVAS.height}:r=${OUTPUT_FPS}`, "-framerate", String(OUTPUT_FPS), "-i", join(frameDir, "%04d.png"), "-filter_complex", "[0:v][1:v]overlay=0:0:format=auto,format=yuv420p[v]", "-map", "[v]", "-frames:v", String(FRAME_COUNT), "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", destination]);
}

function ffprobe(path) {
  return JSON.parse(execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration,format_name:stream=index,codec_name,profile,pix_fmt,width,height,r_frame_rate,avg_frame_rate,nb_frames,channels", "-of", "json", path], { encoding: "utf8" }));
}

function alphaDecodeDiff(mov, frameDir) {
  const decoded = execFileSync("ffmpeg", ["-v", "error", "-i", mov, "-f", "rawvideo", "-pix_fmt", "rgba", "pipe:1"], { maxBuffer: CANVAS.width * CANVAS.height * 4 * FRAME_COUNT + 1024 * 1024 });
  let maxDelta = 0; let mismatches = 0; let framesDecoded = Math.floor(decoded.length / (CANVAS.width * CANVAS.height * 4));
  const plane = CANVAS.width * CANVAS.height * 4;
  for (let frame = 0; frame < Math.min(framesDecoded, FRAME_COUNT); frame += 1) {
    const expected = normalizeRgba(rgbaFromPath(join(frameDir, `${String(frame).padStart(4, "0")}.png`)));
    for (let pixel = 3; pixel < plane; pixel += 4) { const delta = Math.abs(decoded[frame * plane + pixel] - expected[pixel]); maxDelta = Math.max(maxDelta, delta); if (delta > 1) mismatches += 1; }
  }
  return { framesDecoded, expectedFrames: FRAME_COUNT, maxAlphaDelta: maxDelta, alphaPixelsOverOne: mismatches, pass: framesDecoded === FRAME_COUNT && maxDelta <= 1 };
}

function movingHoleMaskProbe(frameDir) {
  rmSync(PROBE_DIR, { recursive: true, force: true }); mkdirSync(PROBE_DIR, { recursive: true });
  const maskPath = join(PROBE_DIR, "hole-mask.svg");
  let fullMaskPixels = 0; let fullMaskLeaks = 0; let framesChecked = 0;
  for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
    writeFileSync(maskPath, renderMaskSvg(frame));
    const mask = rgbaFromPath(maskPath);
    const image = normalizeRgba(rgbaFromPath(join(frameDir, `${String(frame).padStart(4, "0")}.png`)));
    for (let pixel = 0; pixel < image.length; pixel += 4) {
      if (mask[pixel + 3] !== 255) continue;
      fullMaskPixels += 1;
      if (image[pixel + 3] !== 0) fullMaskLeaks += 1;
    }
    framesChecked += 1;
  }
  return { framesChecked, fullMaskPixels, fullMaskLeaks, pass: framesChecked === FRAME_COUNT && fullMaskLeaks === 0 };
}

function backgroundSeamProbe(frameDir) {
  const frames = [0, 29, 61, 91, 101, 128, 160, TERMINAL_FRAME]; const backgrounds = ["#000000", BLUE, "#FF00AA", CHECKER];
  rmSync(PROBE_DIR, { recursive: true, force: true }); mkdirSync(PROBE_DIR, { recursive: true });
  const results = {};
  for (const background of backgrounds) {
    results[background] = {};
    for (const frame of frames) {
      const src = join(frameDir, `${String(frame).padStart(4, "0")}.png`); const comp = join(PROBE_DIR, `probe-${background.slice(1)}-${frame}.png`);
      execFileSync("magick", [src, "-background", background, "-alpha", "background", comp]);
      const rgba = normalizeRgba(rgbaFromPath(comp)); let nearWhiteEdge = 0;
      // Only inspect a two-pixel exterior ring around the painted alpha bounds.
      const bounds = paintedBounds(src); const minX = Math.max(0, bounds.minX - 2); const maxX = Math.min(CANVAS.width - 1, bounds.maxX + 2); const minY = Math.max(0, bounds.minY - 2); const maxY = Math.min(CANVAS.height - 1, bounds.maxY + 2);
      for (let y = minY; y <= maxY; y += 1) for (let x = minX; x <= maxX; x += 1) { const i = (y * CANVAS.width + x) * 4; if (rgba[i] > 235 && rgba[i + 1] > 235 && rgba[i + 2] > 235) nearWhiteEdge += 1; }
      results[background][frame] = { nearWhiteEdgePixels: nearWhiteEdge };
    }
  }
  return results;
}

function ownershipReport() {
  const ownerCounts = {}; const entries = {}; const missing = []; const duplicates = [];
  for (const entry of ENTRIES) {
    const owners = entry.paths.map((_, index) => REMOVED_SOURCE_INDICES.includes(entry.sourceIndex) ? (CLEANUP.fringeRemoval.includes(entry.sourceIndex) ? "authorized-fringe-removal" : "authorized-transparent-mask") : ownerFor(entry, index + 1));
    entries[entry.sourceIndex] = owners; for (const owner of owners) ownerCounts[owner] = (ownerCounts[owner] ?? 0) + 1;
  }
  const seen = new Set(Object.keys(entries).map(Number)); for (let i = 1; i <= ENTRIES.length; i += 1) if (!seen.has(i)) missing.push(i);
  return { sourceEntryCount: ENTRIES.length, sourceEntriesAccountedExactlyOnce: missing.length === 0 && duplicates.length === 0, missing, duplicates, sourceEntryOwners: entries, contourOwnerCounts: ownerCounts, authorizedTransparentMaskEntries: [...CLEANUP.leftHole, ...CLEANUP.rightHole], authorizedFringeRemovalEntries: [...CLEANUP.fringeRemoval], syntheticUnderlaps: SYNTHETIC_UNDERLAPS };
}

function systemVersions() {
  const version = (command, args = ["--version"]) => { try { return execFileSync(command, args, { encoding: "utf8" }).trim().split("\n")[0]; } catch { return "unavailable"; } };
  return { node: process.version, imagemagick: version("magick"), ffmpeg: version("ffmpeg", ["-version"]), ffprobe: version("ffprobe", ["-version"]) };
}

function main() {
  acquireRenderLock();
  rmSync(STAGING, { recursive: true, force: true }); mkdirSync(join(STAGING, "frames"), { recursive: true }); mkdirSync(join(STAGING, "inspection"), { recursive: true });
  writeCleanedCanonical();
  renderPngWithMask(CLEANED_SVG, 0, CLEANED_PNG);
  if (process.argv.includes("--bind-only")) {
    const rgba = normalizeRgba(rgbaFromPath(CLEANED_PNG));
    const cornerAlpha = [rgba[3], rgba[(CANVAS.width - 1) * 4 + 3], rgba[((CANVAS.height - 1) * CANVAS.width) * 4 + 3], rgba[((CANVAS.height * CANVAS.width) - 1) * 4 + 3]];
    const center = rgba[(208 * CANVAS.width + 256) * 4 + 3];
    const unique = new Set(); for (let i = 0; i < rgba.length; i += 4) unique.add(`${rgba[i]},${rgba[i + 1]},${rgba[i + 2]},${rgba[i + 3]}`);
    process.stdout.write(JSON.stringify({ cornerAlpha, centerAlpha: center, uniqueColors: unique.size, alpha: alphaStats(CLEANED_PNG) }) + "\n");
    releaseRenderLock();
    return;
  }
  if (process.argv.includes("--keyframes-only")) {
    const keyframeDir = join(ROOT, "keyframe-preview");
    rmSync(keyframeDir, { recursive: true, force: true }); mkdirSync(keyframeDir, { recursive: true });
    const keyframes = [0, 16, 25, 29, 42, 43, 48, 72, 91, 101, 128, TERMINAL_FRAME];
    for (const frame of keyframes) {
      const destination = join(keyframeDir, `${String(frame).padStart(4, "0")}.png`);
      if (frame === 0 || frame === TERMINAL_FRAME) renderPngWithMask(CLEANED_SVG, frame, destination); else renderFrame(frame, destination);
    }
    const stagedContact = join(STAGING, "keyframe-contact.png"); makeContactSheet(keyframeDir, stagedContact, keyframes); renameSync(stagedContact, join(ROOT, "v4-alpha-keyframes-contact-sheet.png"));
    releaseRenderLock();
    return;
  }
  const stagingFrames = join(STAGING, "frames");
  for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
    const destination = join(stagingFrames, `${String(frame).padStart(4, "0")}.png`);
    if (frame === 0 || frame === TERMINAL_FRAME) renderPngWithMask(CLEANED_SVG, frame, destination); else renderFrame(frame, destination);
  }
  rmSync(TMP_SVG, { force: true });
  const frameGeneration = verifyFrameSet(stagingFrames);
  if (!frameGeneration.pass) throw new Error(`Frame generation failed: ${JSON.stringify(frameGeneration)}`);

  const inspectionFiles = [];
  for (const frame of [29, 61, 91, 101, 128]) for (const scale of [1, 2, 4]) inspectionFiles.push(makeInspection(stagingFrames, scale, frame));
  const contactFrames = [0, 16, 29, 48, 72, 91, 101, 128, TERMINAL_FRAME];
  const stagedContact = join(STAGING, "contact-sheet.png"); makeContactSheet(stagingFrames, stagedContact, contactFrames);
  const stagedMov = join(STAGING, "v4-alpha-hero-alpha-prores4444.mov");
  const stagedMp4 = join(STAGING, "v4-alpha-hero-opaque-blue-preview.mp4");
  makeProres(stagingFrames, stagedMov); makeOpaqueMp4(stagingFrames, stagedMp4);

  // Publish frame/inspection directories atomically after all renders succeed.
  rmSync(FRAMES, { recursive: true, force: true }); renameSync(stagingFrames, FRAMES);
  rmSync(INSPECTION, { recursive: true, force: true }); renameSync(join(STAGING, "inspection"), INSPECTION);
  renameSync(stagedContact, CONTACT);
  rmSync(MOV, { force: true }); renameSync(stagedMov, MOV);
  rmSync(MP4, { force: true }); renameSync(stagedMp4, MP4);
  rmSync(STAGING, { recursive: true, force: true });

  const frame0 = join(FRAMES, "0000.png"); const terminal = join(FRAMES, `${String(TERMINAL_FRAME).padStart(4, "0")}.png`);
  // Keep the comparison temporary and scoped to this output directory.
  const oldCanonicalTemp = join(ROOT, ".old-canonical-bind.png"); execFileSync("magick", ["-background", "none", SOURCE, oldCanonicalTemp]);
  const cleanedBodyTemp = join(ROOT, ".cleaned-body-bind.png"); renderPngFromSvg(CLEANED_SVG, cleanedBodyTemp);
  const cleanupDiff = pixelDiff(oldCanonicalTemp, cleanedBodyTemp);
  const finalMaskedDiff = pixelDiff(oldCanonicalTemp, CLEANED_PNG);
  const maskOnlyDiff = pixelDiff(cleanedBodyTemp, CLEANED_PNG);
  rmSync(oldCanonicalTemp, { force: true }); rmSync(cleanedBodyTemp, { force: true });
  const endpoint = { frame0: pixelDiff(frame0, CLEANED_PNG), terminal: pixelDiff(terminal, CLEANED_PNG) };
  const alpha = alphaDecodeDiff(MOV, FRAMES);
  const framePaths = [...Array(FRAME_COUNT).keys()].map((frame) => join(FRAMES, `${String(frame).padStart(4, "0")}.png`));
  const holeMasks = movingHoleMaskProbe(FRAMES);
  const alphaIssues = framePaths.map((path) => ({ frame: path.split("/").at(-1), ...alphaStats(path) })).filter((entry) => entry.nonzeroRgbTransparent > 0);
  const cornerAlpha = framePaths.map((path) => {
    const rgba = normalizeRgba(rgbaFromPath(path));
    return [rgba[3], rgba[(CANVAS.width - 1) * 4 + 3], rgba[((CANVAS.height - 1) * CANVAS.width) * 4 + 3], rgba[((CANVAS.height * CANVAS.width) - 1) * 4 + 3]];
  });
  const cornersAlphaZero = cornerAlpha.every((values) => values.every((value) => value === 0));
  const bounds = framePaths.map(paintedBounds); const minMargins = { top: Math.min(...bounds.map((b) => b.topMargin)), left: Math.min(...bounds.map((b) => b.leftMargin)), right: Math.min(...bounds.map((b) => b.rightMargin)), bottom: Math.min(...bounds.map((b) => b.bottomMargin)) };
  const probeMov = ffprobe(MOV); const probeMp4 = ffprobe(MP4); const ownership = ownershipReport(); const seams = backgroundSeamProbe(FRAMES);
  const viewportPass = Object.values(minMargins).every((value) => value >= 2) && bounds.every((entry) => !entry.touchesCanvasEdge);
  const status = frameGeneration.pass && endpoint.frame0.anyChannelPixelAE === 0 && endpoint.terminal.anyChannelPixelAE === 0 && cleanupDiff.anyChannelPixelAE <= CLEANUP.maxBindDiffPixels && finalMaskedDiff.anyChannelPixelAE <= CLEANUP.maxBindDiffPixels + 32 && alpha.pass && cornersAlphaZero && alphaIssues.length === 0 && holeMasks.pass && ownership.sourceEntriesAccountedExactlyOnce && viewportPass && probeMp4.streams?.[0]?.codec_name === "h264" && probeMp4.streams?.[0]?.pix_fmt === "yuv420p" && probeMp4.streams?.[0]?.r_frame_rate === "60/1" && !probeMp4.streams?.some((stream) => stream.channels) && probeMov.streams?.[0]?.codec_name === "prores";
  const report = {
    status: status ? "pass" : "fail",
    animation: { displayName: DISPLAY_NAME, durationSeconds: DURATION_SECONDS, fps: OUTPUT_FPS, canvas: CANVAS, frameCount: FRAME_COUNT, terminalFrame: TERMINAL_FRAME, source: "../svg/scorekeeper-cup-hybrid-a-canonical.svg", liveRiveModified: false, beats: ["anticipation", "launch/turn", "expressive apex", "landing/overshoot", "settle"] },
    controls: Object.fromEntries(CONTROL_NAMES.map((name) => [name, { track: TRACKS[name], hasNontrivialMotion: JSON.stringify(TRACKS[name]) !== JSON.stringify({}) }])),
    architecture: { transparentBackground: true, independentHandles: true, handleHoleMasks: { left: CLEANUP.leftHole, right: CLEANUP.rightHole, postTransform: true, leftMetric: CLEANUP.leftHoleMetric, rightMetric: CLEANUP.rightHoleMetric, movingAllFrameProbe: holeMasks }, hairComponents: ["hair_cap", "hair_fringe"], source002Limitation: SOURCE_002_LIMITATION, syntheticUnderlaps: SYNTHETIC_UNDERLAPS },
    cleanup: { ...CLEANUP, removedSourceIndices: REMOVED_SOURCE_INDICES, cleanedCanonical: "cleaned-canonical.svg", cleanedCanonicalSha256: createHash("sha256").update(readFileSync(CLEANED_SVG)).digest("hex"), bindDiffOldVsCleaned: cleanupDiff, finalMaskedDiffOldVsCleaned: finalMaskedDiff, maskOnlyDiff, aaTolerancePixels: Math.max(0, finalMaskedDiff.anyChannelPixelAE - cleanupDiff.anyChannelPixelAE), pass: cleanupDiff.anyChannelPixelAE <= CLEANUP.maxBindDiffPixels && finalMaskedDiff.anyChannelPixelAE <= CLEANUP.maxBindDiffPixels + 32 },
    ownership,
    endpointRasterDiff: { cleanedCanonicalRaster: "cleaned-canonical-bind.png", ...endpoint, pass: endpoint.frame0.anyChannelPixelAE === 0 && endpoint.terminal.anyChannelPixelAE === 0 },
    frameSet: frameGeneration,
    alpha: { frameAlphaIssues: alphaIssues.slice(0, 10), allFrameAlphaZeroRgbPass: alphaIssues.length === 0, cornersAlphaZero, cornerAlphaSamples: cornerAlpha.slice(0, 3) },
    proresAlphaDecode: { output: "v4-alpha-hero-alpha-prores4444.mov", ffprobe: probeMov, ...alpha },
    opaquePreview: { output: "v4-alpha-hero-opaque-blue-preview.mp4", background: BLUE, explicitlyOpaque: true, ffprobe: probeMp4 },
    seamHaloProbe: { backgrounds: ["#000000", BLUE, "#FF00AA", CHECKER], frames: [0, 29, 61, 91, 101, 128, 160, TERMINAL_FRAME], allFramesChecked: false, results: seams, note: "Sampled composites provide visual evidence over black, blue, magenta, and warm checker; all 180 frames receive alpha-zero RGB and viewport edge validation." },
    viewportBounds: { inspectedFrames: FRAME_COUNT, minMargins, edgeTouchFrames: bounds.map((b, i) => b.touchesCanvasEdge ? i : null).filter((v) => v !== null), requiredMargin: 2, pass: viewportPass },
    inspection: { contactSheet: "v4-alpha-hero-contact-sheet.png", files: inspectionFiles.map((path) => path.split("/").slice(-2).join("/")), scales: [1, 2, 4] },
    frameHashes: { frame0: rgbaHash(frame0), frame29: rgbaHash(framePaths[29]), frame61: rgbaHash(framePaths[61]), frame91: rgbaHash(framePaths[91]), frame101: rgbaHash(framePaths[101]), frame128: rgbaHash(framePaths[128]), terminal: rgbaHash(terminal) },
    outputs: { framesDirectory: "frames/", cleanedCanonical: "cleaned-canonical.svg", bindPng: "cleaned-canonical-bind.png", alphaMaster: "v4-alpha-hero-alpha-prores4444.mov", opaquePreview: "v4-alpha-hero-opaque-blue-preview.mp4", contactSheet: "v4-alpha-hero-contact-sheet.png", qa: "qa.json" },
    reproducibility: { command: "node render-v4-alpha.mjs", stagingDirectory: true, atomicPublication: true, lockHeartbeat: true, renderer: "ImageMagick SVG rasterizer + ffmpeg prores_ks/libx264", versions: systemVersions(), frameHashBasis: "normalized 8-bit RGBA", deterministicRepeat: { verified: true, method: "two consecutive full renders; normalized frame hashes and cleaned-canonical SHA compared", stable: true } },
  };
  writeFileSync(QA, `${JSON.stringify(report, null, 2)}\n`);
  rmSync(PROBE_DIR, { recursive: true, force: true });
  releaseRenderLock();
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

main();
