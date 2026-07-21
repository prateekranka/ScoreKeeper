#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { frameState, readAndValidate } from "../../production-v6-rive-rig/lib/live-keyframes.mjs";
import { BRIDGES, BRIDGE_PREFIX } from "./underlap-spec-v3.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PROOFS = path.join(HERE, "proofs");
const MODEL_PATH = path.join(HERE, "proof-model-v3.json");
const REPORT_PATH = path.join(PROOFS, "render-report.json");
const MAGICK = execFileSync("/usr/bin/which", ["magick"], { encoding: "utf8" }).trim();
const FFMPEG = execFileSync("/usr/bin/which", ["ffmpeg"], { encoding: "utf8" }).trim();
const rawModel = JSON.parse(fs.readFileSync(MODEL_PATH, "utf8"));
const model = readAndValidate(MODEL_PATH);
const report = JSON.parse(fs.readFileSync(REPORT_PATH, "utf8"));
const liveUnderlaps = JSON.parse(fs.readFileSync(path.join(HERE, "live-underlaps-v3.json"), "utf8"));
if (liveUnderlaps.underlapCount !== BRIDGES.length) throw new Error("live bridge count mismatch");

const run = (command, args, options = {}) => execFileSync(command, args, { stdio: ["ignore", "pipe", "pipe"], ...options });
const frameName = (frame) => `frame-${String(frame).padStart(4, "0")}`;

function bridgeOpacity(slug, name, frame) {
  const keys = rawModel.animations[slug]?.bridgeOpacityTracks?.[name] ?? [];
  let value = 0;
  for (const key of keys) if (key.frame <= frame) value = key.value;
  return value;
}
for (const slug of ["victory_pop", "curious_tilt", "celebrate_shimmy"]) for (const item of BRIDGES) {
  const keys = rawModel.animations[slug]?.bridgeOpacityTracks?.[item.name] ?? [];
  if (keys.length !== 4 || bridgeOpacity(slug, item.name, 1) !== 1 || bridgeOpacity(slug, item.name, rawModel.animations[slug].durationFrames) !== 0) {
    throw new Error(`${slug}/${item.name}: invalid queried bridge opacity track`);
  }
}
function inject(svg, slug, frame, filter = () => true) {
  if (svg.includes(BRIDGE_PREFIX)) return svg;
  const additionsBySource = new Map();
  for (const item of BRIDGES.filter(filter)) {
    const id = `asset_${item.semantic}__source_${String(item.sourceIndex).padStart(3, "0")}`;
    const match = svg.match(new RegExp(`<g id="${id}" transform="([^"]+)"`));
    if (!match) continue;
    additionsBySource.set(id, `<g id="${item.name}" transform="${match[1]}" opacity="${bridgeOpacity(slug, item.name, frame)}"><rect x="${item.x}" y="${item.y}" width="${item.width}" height="${item.height}" fill="${item.color}"/></g>`);
  }
  for (const [id, addition] of additionsBySource) svg = svg.replace(`<g id="${id}"`, `${addition}\n  <g id="${id}"`);
  return svg;
}

function readRgba(file, width, height) {
  const bytes = run(MAGICK, [file, "-depth", "8", "rgba:-"]);
  if (bytes.length !== width * height * 4) throw new Error(`RGBA length mismatch ${file}`);
  return bytes;
}
function alphaMask(bytes) {
  const result = new Uint8Array(bytes.length / 4);
  for (let index = 0; index < result.length; index += 1) result[index] = bytes[index * 4 + 3] >= 128 ? 1 : 0;
  return result;
}
function transformPoint(matrix, x, y) { return { x: matrix[0] * x + matrix[2] * y + matrix[4], y: matrix[1] * x + matrix[3] * y + matrix[5] }; }
function coverage(mask, width, height, rect, matrix) {
  let sampledPixels = 0, coveredPixels = 0;
  for (let y = rect.y + 2; y < rect.y + rect.height - 2; y += 1) for (let x = rect.x + 2; x < rect.x + rect.width - 2; x += 1) {
    const point = transformPoint(matrix, x, y), xx = Math.round(point.x), yy = Math.round(point.y);
    if (xx < 0 || yy < 0 || xx >= width || yy >= height) continue;
    sampledPixels += 1;
    if (mask[yy * width + xx]) coveredPixels += 1;
  }
  return { sampledPixels, coveredPixels };
}
function alphaQa(framePath, handlePaths, matrices) {
  const bytes = readRgba(framePath, model.canvas.width, model.canvas.height);
  let transparentRgbMax = 0;
  for (let index = 0; index < bytes.length; index += 4) if (bytes[index + 3] === 0) transparentRgbMax = Math.max(transparentRgbMax, bytes[index], bytes[index + 1], bytes[index + 2]);
  const rects = { left: { x: 49, y: 129, width: 23, height: 40 }, right: { x: 441, y: 129, width: 24, height: 40 } };
  const holes = {};
  for (const side of ["left", "right"]) {
    const result = coverage(alphaMask(readRgba(handlePaths[side], model.canvas.width, model.canvas.height)), model.canvas.width, model.canvas.height, rects[side], matrices[side]);
    holes[side] = { ...rects[side], ...result, pass: result.sampledPixels > 0 && result.coveredPixels === 0 };
  }
  const noWhiteFringe = transparentRgbMax <= 4, handleHoles = Object.values(holes).every((item) => item.pass);
  return { noWhiteFringe, transparentRgbMax, handleHoles, holes, passed: noWhiteFringe && handleHoles };
}
function makeComposite(framePath, outputPath) {
  const checker = `${outputPath}.checker.png`, light = `${outputPath}.light.png`, dark = `${outputPath}.dark.png`;
  run(MAGICK, ["-size", "512x416", "pattern:checkerboard", framePath, "-compose", "over", "-composite", "-filter", "point", "-resize", "360x292!", checker]);
  run(MAGICK, [framePath, "-background", "#F7F2E9", "-alpha", "background", "-filter", "point", "-resize", "360x292!", light]);
  run(MAGICK, [framePath, "-background", "#191A1F", "-alpha", "background", "-filter", "point", "-resize", "360x292!", dark]);
  run(MAGICK, [checker, light, dark, "-append", "-define", "png:color-type=2", outputPath]);
  for (const file of [checker, light, dark]) fs.rmSync(file, { force: true });
}

for (const animationReport of report.animations) {
  const animation = model.animations[animationReport.slug];
  for (let sequence = 0; sequence < animationReport.renderedFrames.length; sequence += 1) {
    const frame = animationReport.renderedFrames[sequence], name = frameName(frame);
    const svgPath = path.join(PROOFS, animationReport.slug, "svg", `${name}.svg`);
    const pngPath = path.join(PROOFS, animationReport.slug, "rgba-frames", `${name}.png`);
    fs.writeFileSync(svgPath, inject(fs.readFileSync(svgPath, "utf8"), animationReport.slug, frame));
    run("/usr/bin/sips", ["-s", "format", "png", svgPath, "--out", pngPath]);
    const state = frameState(model, animation, frame);
    const handlePaths = {}, matrices = {};
    for (const [side, semantic] of [["left", "handle_l"], ["right", "handle_r"]]) {
      const handleSvg = path.join(PROOFS, animationReport.slug, "semantic-alpha-qa", `${name}-${semantic}.svg`);
      const handlePng = path.join(PROOFS, animationReport.slug, "semantic-alpha-qa", `${name}-${semantic}.png`);
      fs.writeFileSync(handleSvg, inject(fs.readFileSync(handleSvg, "utf8"), animationReport.slug, frame, (item) => item.semantic === semantic));
      run("/usr/bin/sips", ["-s", "format", "png", handleSvg, "--out", handlePng]);
      handlePaths[side] = handlePng;
      matrices[side] = state.worldMatrices.get(`asset_${semantic}`);
    }
    const qa = alphaQa(pngPath, handlePaths, matrices);
    if (!qa.passed) throw new Error(`${animationReport.slug} frame ${frame}: alpha QA failed ${JSON.stringify(qa)}`);
    const compositePath = path.join(PROOFS, animationReport.slug, "composites", `frame-${String(sequence).padStart(4, "0")}.png`);
    makeComposite(pngPath, compositePath);
    animationReport.frameReports[sequence].alphaQa = qa;
  }
  const contacts = animationReport.contactFrames.map((frame) => path.join(PROOFS, animationReport.slug, "rgba-frames", `${frameName(frame)}.png`));
  const contactSheet = path.join(PROOFS, animationReport.transparentContactSheet);
  run(MAGICK, [...contacts, "-filter", "point", "-resize", "128x104!", "+append", "-background", "none", contactSheet]);
  run(FFMPEG, ["-y", "-framerate", String(model.fps), "-start_number", "0", "-i", path.join(PROOFS, animationReport.slug, "composites", "frame-%04d.png"), "-frames:v", String(animationReport.renderedFrames.length), "-vf", "format=yuv420p", "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p", "-movflags", "+faststart", path.join(PROOFS, animationReport.mp4)]);
}
run(MAGICK, [...report.animations.map((animation) => path.join(PROOFS, animation.transparentContactSheet)), "-background", "none", "-append", path.join(PROOFS, report.aggregateTransparentContactSheet)]);
report.status = "rendered_from_live_keyframes_with_queried_motion_gated_bridges";
report.liveUnderlaps = { path: "../live-underlaps-v3.json", count: liveUnderlaps.underlapCount, sha256: crypto.createHash("sha256").update(fs.readFileSync(path.join(HERE, "live-underlaps-v3.json"))).digest("hex") };
report.notes.push("Four v3 seam bridges are inserted behind matching cup fill layers and use the freshly queried live opacity keys: zero in bind/idle, one only through rotated motion, then zero at the terminal frame.");
fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ status: report.status, animations: report.animations.length, underlaps: liveUnderlaps.underlapCount }, null, 2)}\n`);
