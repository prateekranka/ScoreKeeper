#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..");
const PROOFS = path.join(HERE, "proofs");
const OUT = path.join(HERE, "proof-pack-v3");
const V2 = path.resolve(ROOT, "../production-v6-rive-rig/proofs");
const SOURCE = path.resolve(ROOT, "../production-v5-vector-master/canonical-dimensional-pixel.svg");
const MAGICK = execFileSync("/usr/bin/which", ["magick"], { encoding: "utf8" }).trim();
const FFMPEG = execFileSync("/usr/bin/which", ["ffmpeg"], { encoding: "utf8" }).trim();
const FFPROBE = execFileSync("/usr/bin/which", ["ffprobe"], { encoding: "utf8" }).trim();
const SIPS = "/usr/bin/sips";
const report = JSON.parse(fs.readFileSync(path.join(PROOFS, "render-report.json"), "utf8"));
const live = JSON.parse(fs.readFileSync(path.join(HERE, "independent-live-query.json"), "utf8"));

const run = (command, args, options = {}) => execFileSync(command, args, { stdio: ["ignore", "pipe", "pipe"], ...options });
const sha = (file) => crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const rel = (file) => path.relative(HERE, file);
const frameFile = (slug, frame) => path.join(PROOFS, slug, "rgba-frames", `frame-${String(frame).padStart(4, "0")}.png`);
const ensure = (dir) => fs.mkdirSync(dir, { recursive: true });

fs.rmSync(OUT, { recursive: true, force: true });
ensure(OUT);
for (const dir of ["actual-size", "backgrounds", "stress", "loop-seams", "before-after", "mobile-mp4", "neutral-parity"]) ensure(path.join(OUT, dir));

function makeAggregateBackground(color, name) {
  const source = path.join(PROOFS, "five-animation-transparent-contact-sheet.png");
  const dest = path.join(OUT, "backgrounds", name);
  run(MAGICK, [source, "-background", color, "-alpha", "background", dest]);
  return dest;
}

const lightSheet = makeAggregateBackground("#F7F2E9", "five-animation-light-contact-sheet.png");
const darkSheet = makeAggregateBackground("#191A1F", "five-animation-dark-contact-sheet.png");

const actualRows = { transparent: [], light: [], dark: [] };
for (const animation of report.animations) {
  for (const [mode, background] of [["transparent", "none"], ["light", "#F7F2E9"], ["dark", "#191A1F"]]) {
    const cells = [];
    for (const frame of animation.contactFrames) {
      const cell = path.join(OUT, "actual-size", `${animation.slug}-${mode}-${String(frame).padStart(4, "0")}.png`);
      const args = [frameFile(animation.slug, frame), "-filter", "point", "-resize", "72x60!"];
      if (background !== "none") args.push("-background", background, "-alpha", "background");
      args.push(cell);
      run(MAGICK, args);
      cells.push(cell);
    }
    const row = path.join(OUT, "actual-size", `${animation.slug}-${mode}-72x60-strip.png`);
    run(MAGICK, [...cells, "+append", "-background", background, row]);
    actualRows[mode].push(row);
  }
}
const actualSheets = {};
for (const [mode, rows] of Object.entries(actualRows)) {
  const dest = path.join(OUT, "actual-size", `five-animation-${mode}-72x60-contact-sheet.png`);
  run(MAGICK, [...rows, "-background", mode === "light" ? "#F7F2E9" : mode === "dark" ? "#191A1F" : "none", "-gravity", "west", "-append", dest]);
  actualSheets[mode] = dest;
}

const apex = { idle_breathe_blink: 42, hair_bounce: 15, victory_pop: 24, curious_tilt: 28, celebrate_shimmy: 25 };
const stressFiles = [];
for (const animation of report.animations) {
  for (const scale of [1, 2, 4]) {
    const dest = path.join(OUT, "stress", `${animation.slug}-f${String(apex[animation.slug]).padStart(4, "0")}-${scale * 100}pct.png`);
    run(MAGICK, [frameFile(animation.slug, apex[animation.slug]), "-filter", "point", "-resize", `${scale * 100}%`, dest]);
    stressFiles.push(dest);
  }
}

const seamFiles = [];
for (const [slug, frames] of Object.entries({ idle_breathe_blink: [70, 71, 72, 0, 1, 2], celebrate_shimmy: [93, 94, 95, 96, 0, 1, 2, 3] })) {
  const dest = path.join(OUT, "loop-seams", `${slug}-terminal-to-zero.png`);
  run(MAGICK, [...frames.map((frame) => frameFile(slug, frame)), "-filter", "point", "-resize", "128x104!", "+append", "-background", "none", dest]);
  seamFiles.push(dest);
}

const comparisonRows = [];
for (const animation of report.animations) {
  const v2 = path.join(V2, animation.slug, `${animation.slug}-transparent-contact-sheet.png`);
  const v3 = path.join(PROOFS, animation.slug, `${animation.slug}-transparent-contact-sheet.png`);
  const dest = path.join(OUT, "before-after", `${animation.slug}-v2-before-v3-after.png`);
  run(MAGICK, [v2, v3, "-background", "none", "+append", dest]);
  comparisonRows.push(dest);
}
const comparison = path.join(OUT, "before-after", "five-animation-v2-before-v3-after.png");
run(MAGICK, [...comparisonRows, "-background", "none", "-gravity", "west", "-append", comparison]);

const mobile = [];
for (const animation of report.animations) {
  const isLoop = animation.slug === "idle_breathe_blink" || animation.slug === "celebrate_shimmy";
  const expectedFrames = animation.durationFrames + (isLoop ? 0 : 1);
  const dest = path.join(OUT, "mobile-mp4", `${animation.slug}-72x60-light-dark.mp4`);
  const filter = "[0:v]scale=72:60:flags=neighbor,format=rgba,split=2[fgl][fgd];color=c=0xF7F2E9:s=72x60:r=60[light];color=c=0x191A1F:s=72x60:r=60[dark];[light][fgl]overlay=shortest=1[l];[dark][fgd]overlay=shortest=1[d];[l][d]hstack=inputs=2,format=yuv420p[out]";
  run(FFMPEG, ["-y", "-framerate", "60", "-i", path.join(PROOFS, animation.slug, "rgba-frames", "frame-%04d.png"), "-filter_complex", filter, "-map", "[out]", "-frames:v", String(expectedFrames), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", dest]);
  const probe = JSON.parse(run(FFPROBE, ["-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=width,height,r_frame_rate,nb_read_frames,duration", "-of", "json", dest], { encoding: "utf8" }));
  const stream = probe.streams[0];
  mobile.push({ slug: animation.slug, path: rel(dest), expectedFrames, width: stream.width, height: stream.height, fps: stream.r_frame_rate, frameCount: Number(stream.nb_read_frames), duration: Number(stream.duration), passed: stream.width === 144 && stream.height === 60 && stream.r_frame_rate === "60/1" && Number(stream.nb_read_frames) === expectedFrames });
}

const neutralDir = path.join(OUT, "neutral-parity");
const canonical = path.join(neutralDir, "canonical-source.png");
const candidate = frameFile("idle_breathe_blink", 0);
run(SIPS, ["-s", "format", "png", SOURCE, "--out", canonical]);

function rgba(file) {
  return run(MAGICK, [file, "-depth", "8", "rgba:-"]);
}
const a = rgba(canonical);
const b = rgba(candidate);
if (a.length !== b.length) throw new Error(`neutral size mismatch ${a.length} != ${b.length}`);
let intersection = 0, union = 0, diffPixels = 0, maxChannelDelta = 0;
let ax = 0, ay = 0, ac = 0, bx = 0, by = 0, bc = 0;
const width = 512, height = 416;
const am = new Uint8Array(width * height), bm = new Uint8Array(width * height);
for (let p = 0; p < width * height; p += 1) {
  const i = p * 4, aa = a[i + 3] >= 128, ba = b[i + 3] >= 128;
  am[p] = aa ? 1 : 0; bm[p] = ba ? 1 : 0;
  if (aa && ba) intersection += 1;
  if (aa || ba) union += 1;
  if (a[i] !== b[i] || a[i + 1] !== b[i + 1] || a[i + 2] !== b[i + 2] || a[i + 3] !== b[i + 3]) diffPixels += 1;
  maxChannelDelta = Math.max(maxChannelDelta, Math.abs(a[i] - b[i]), Math.abs(a[i + 1] - b[i + 1]), Math.abs(a[i + 2] - b[i + 2]), Math.abs(a[i + 3] - b[i + 3]));
  const x = p % width, y = Math.floor(p / width);
  if (aa) { ax += x; ay += y; ac += 1; }
  if (ba) { bx += x; by += y; bc += 1; }
}
const isBoundary = (mask, p) => {
  if (!mask[p]) return false;
  const x = p % width, y = Math.floor(p / width);
  return x === 0 || y === 0 || x === width - 1 || y === height - 1 || !mask[p - 1] || !mask[p + 1] || !mask[p - width] || !mask[p + width];
};
const boundaryB = new Set();
for (let p = 0; p < bm.length; p += 1) if (isBoundary(bm, p)) boundaryB.add(p);
const distances = [];
for (let p = 0; p < am.length; p += 1) {
  if (!isBoundary(am, p)) continue;
  if (boundaryB.has(p)) { distances.push(0); continue; }
  const x = p % width, y = Math.floor(p / width);
  let found = 33;
  for (let r = 1; r <= 32 && found === 33; r += 1) {
    for (let dy = -r; dy <= r && found === 33; dy += 1) for (let dx = -r; dx <= r; dx += 1) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
      const xx = x + dx, yy = y + dy;
      if (xx >= 0 && yy >= 0 && xx < width && yy < height && boundaryB.has(yy * width + xx)) { found = Math.hypot(dx, dy); break; }
    }
  }
  distances.push(found);
}
distances.sort((x, y) => x - y);
const contourP95 = distances[Math.min(distances.length - 1, Math.floor(distances.length * 0.95))];
const centroidDrift = Math.hypot(ax / ac - bx / bc, ay / ac - by / bc);
const parity = { method: "canonical SVG raster versus fresh-live-query semantic neutral frame after owned metadata cleanup", source: rel(canonical), candidate: rel(candidate), alphaMaskIoU: intersection / union, centroidDriftPx: centroidDrift, contourP95Px: contourP95, differingPixels: diffPixels, maxChannelDelta, thresholds: { alphaMaskIoUMin: 0.985, centroidDriftPxMax: 0.5, contourP95PxMax: 1 }, passed: intersection / union >= 0.985 && centroidDrift <= 0.5 && contourP95 <= 1 };
fs.writeFileSync(path.join(neutralDir, "neutral-parity-report.json"), `${JSON.stringify(parity, null, 2)}\n`);
run(MAGICK, [canonical, candidate, "-compose", "difference", "-composite", "-auto-level", path.join(neutralDir, "neutral-difference-amplified.png")]);
run(MAGICK, [canonical, "-channel", "A", "-evaluate", "multiply", "0.45", "+channel", candidate, "-channel", "A", "-evaluate", "multiply", "0.55", "+channel", "-compose", "over", "-composite", path.join(neutralDir, "neutral-overlay.png")]);
for (const scale of [1, 2, 4]) run(MAGICK, [candidate, "-filter", "point", "-resize", `${scale * 100}%`, path.join(neutralDir, `candidate-neutral-${scale * 100}pct.png`)]);

const alphaSummary = report.animations.flatMap((animation) => animation.frameReports.map((frame) => frame.alphaQa));
const pack = {
  status: "proof_pack_from_fresh_live_query_semantic_reconstruction",
  caveat: "The proof renderer uses the canonical SVG plus transforms independently queried from live Rive; it is not an offline substitute for the live structural export and is not a native Rive runtime capture.",
  targetFileId: live.targetFileId,
  artboardId: live.artboardId,
  stateMachineId: live.stateMachineId,
  liveExportSha256: live.liveExportSha256,
  sourceSha256: sha(SOURCE),
  transparentContactSheet: rel(path.join(PROOFS, "five-animation-transparent-contact-sheet.png")),
  lightContactSheet: rel(lightSheet),
  darkContactSheet: rel(darkSheet),
  actualSizeSheets: Object.fromEntries(Object.entries(actualSheets).map(([key, value]) => [key, rel(value)])),
  stressFrames: stressFiles.map(rel),
  loopSeams: seamFiles.map(rel),
  beforeAfter: rel(comparison),
  mobile,
  neutralParity: parity,
  alphaQa: { framesChecked: alphaSummary.length, maxTransparentRgb: Math.max(...alphaSummary.map((x) => x.transparentRgbMax)), allHandleHolesTransparent: alphaSummary.every((x) => x.handleHoles), allPassed: alphaSummary.every((x) => x.passed) },
  gates: { liveQuery: live.passed, sourceHash: sha(SOURCE) === "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75", mobile: mobile.every((x) => x.passed), neutralParity: parity.passed, alpha: alphaSummary.every((x) => x.passed) },
};
pack.passed = Object.values(pack.gates).every(Boolean);
fs.writeFileSync(path.join(OUT, "proof-report-v3.json"), `${JSON.stringify(pack, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ passed: pack.passed, gates: pack.gates, neutralParity: parity, mobile: mobile.map(({ slug, frameCount, expectedFrames, passed }) => ({ slug, frameCount, expectedFrames, passed })) }, null, 2)}\n`);
