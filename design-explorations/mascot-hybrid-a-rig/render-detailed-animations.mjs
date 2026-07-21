#!/usr/bin/env node

import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import {
  CANVAS,
  CONTROL_PARENT,
  CONTROL_COUNTS,
  FPS,
  PIVOTS,
  RIG_VERSION,
  SEMANTIC_UNITS,
  VALIDATION as RIG_VALIDATION,
} from "./rig-spec-v2.mjs";
import {
  DETAILED_PERFORMANCE_SPECS,
  validateDetailedPerformanceSpecs,
} from "./detailed-performance-spec.mjs";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const OUTPUT = join(ROOT, "detailed");
const FRAMES = join(OUTPUT, "frames");
const PREVIEWS = join(OUTPUT, "previews");
const REPORTS = join(OUTPUT, "reports");
const PADDING = 64;
const WIDTH = CANVAS.width + PADDING * 2;
const HEIGHT = CANVAS.height + PADDING * 2;
const IDENTITY = [1, 0, 0, 1, 0, 0];

rmSync(FRAMES, { recursive: true, force: true });
mkdirSync(FRAMES, { recursive: true });
mkdirSync(PREVIEWS, { recursive: true });
mkdirSync(REPORTS, { recursive: true });

function bezier(t, p1, p2) {
  const mt = 1 - t;
  return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t;
}

function easedProgress(progress) {
  let low = 0;
  let high = 1;
  let t = progress;
  for (let index = 0; index < 12; index += 1) {
    const x = bezier(t, 0.42, 0.58);
    if (x < progress) low = t;
    else high = t;
    t = (low + high) / 2;
  }
  return bezier(t, 0, 1);
}

function trackValue(keys, frame) {
  if (!keys) return undefined;
  if (frame <= keys[0][0]) return keys[0][1];
  if (frame >= keys.at(-1)[0]) return keys.at(-1)[1];
  for (let index = 0; index < keys.length - 1; index += 1) {
    const [startFrame, startValue] = keys[index];
    const [endFrame, endValue] = keys[index + 1];
    if (frame < startFrame || frame > endFrame) continue;
    const progress = easedProgress((frame - startFrame) / (endFrame - startFrame));
    return startValue + (endValue - startValue) * progress;
  }
  return keys.at(-1)[1];
}

function matrixFor(properties, frame, pivot) {
  const dx = trackValue(properties?.dx, frame) ?? 0;
  const dy = trackValue(properties?.dy, frame) ?? 0;
  const rotation = ((trackValue(properties?.rotationDeg, frame) ?? 0) * Math.PI) / 180;
  const scaleX = trackValue(properties?.scaleX, frame) ?? 1;
  const scaleY = trackValue(properties?.scaleY, frame) ?? 1;
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

function controlMatrix(spec, frame, control, cache) {
  if (cache.has(control)) return cache.get(control);
  const parent = CONTROL_PARENT[control];
  const parentMatrix = parent ? controlMatrix(spec, frame, parent, cache) : IDENTITY;
  const local = matrixFor(spec?.tracks?.[control], frame, PIVOTS[control]);
  const matrix = compose(parentMatrix, local);
  cache.set(control, matrix);
  return matrix;
}

function transformedPoint(matrix, x, y) {
  return {
    x: matrix[0] * x + matrix[2] * y + matrix[4] + PADDING,
    y: matrix[1] * x + matrix[3] * y + matrix[5] + PADDING,
  };
}

function formatted(value) {
  return Number(value.toFixed(6));
}

function renderContour(unit, matrix, { fill = unit.fill, opacity = 1 } = {}) {
  const d = unit.contour.commands.map((command) => {
    if (command.commandType === "close") return "Z";
    const point = transformedPoint(matrix, command.x, command.y);
    return `${command.commandType === "moveTo" ? "M" : "L"}${formatted(point.x)},${formatted(point.y)}`;
  }).join(" ");
  const opacityAttribute = opacity < 1 ? ` opacity="${formatted(opacity)}"` : "";
  return `<path data-unit="${unit.id}" data-control="${unit.control}" d="${d}" fill="${fill}"${opacityAttribute}/>`;
}

function renderSvg(spec, frame, { transparent = false } = {}) {
  const cache = new Map();
  const underlapOpacity = trackValue(spec?.tracks?.rig_body__hair_underlap?.opacity, frame) ?? 0;
  const cupMatrix = controlMatrix(spec, frame, "rig_cup", cache);
  const background = transparent ? "" : `<rect width="${WIDTH}" height="${HEIGHT}" fill="#F4F2EC"/>`;
  const markup = SEMANTIC_UNITS.map((unit) => {
    const matrix = controlMatrix(spec, frame, unit.control, cache);
    const underlap = unit.control.startsWith("rig_hair") && underlapOpacity > 0
      ? renderContour(unit, cupMatrix, { fill: "#EFB944", opacity: underlapOpacity })
      : "";
    return `${underlap}${underlap ? "\n" : ""}${renderContour(unit, matrix)}`;
  }).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
${background}
${markup}
</svg>
`;
}

writeFileSync(join(PREVIEWS, "neutral-v2.svg"), renderSvg(null, 0, { transparent: true }));

const animationReports = [];
for (const spec of DETAILED_PERFORMANCE_SPECS) {
  const directory = join(FRAMES, spec.slug);
  mkdirSync(directory, { recursive: true });
  const terminal = Math.round(spec.durationSeconds * spec.fps);
  for (let frame = 0; frame <= terminal; frame += 1) {
    writeFileSync(join(directory, `${String(frame).padStart(4, "0")}.svg`), renderSvg(spec, frame));
  }
  animationReports.push({
    slug: spec.slug,
    displayName: spec.displayName,
    durationSeconds: spec.durationSeconds,
    fps: spec.fps,
    terminalFrame: terminal,
    renderedFrameCount: terminal + 1,
    movingControls: Object.keys(spec.tracks),
    movingSemanticControlCount: Object.keys(spec.tracks).filter((control) => control !== "rig_body__hair_underlap").length,
    semanticPreviewFrames: spec.semanticPreviewFrames,
    endpointPolicy: spec.endpointPolicy,
  });
}

const performanceValidation = validateDetailedPerformanceSpecs();
const report = {
  status: RIG_VALIDATION.valid && performanceValidation.valid ? "detailed-v2-authored" : "failed",
  rigVersion: RIG_VERSION,
  canvas: CANVAS,
  previewCanvas: { width: WIDTH, height: HEIGHT, padding: PADDING },
  fps: FPS,
  artworkLocked: true,
  canonicalSourcePathCount: RIG_VALIDATION.canonicalSourcePathCount,
  canonicalContourCount: RIG_VALIDATION.canonicalContourCount,
  semanticControlCounts: CONTROL_COUNTS,
  performanceValidation,
  animations: animationReports,
  liveRiveModified: false,
};
writeFileSync(join(REPORTS, "detailed-v2-authoring.json"), `${JSON.stringify(report, null, 2)}\n`);
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
