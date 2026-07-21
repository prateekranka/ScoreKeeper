#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import {
  CANVAS,
  CANONICAL_PARTS,
  HAIR_SOURCE_PATH_INDICES,
  PALETTE,
  ROOT_PIVOT,
  HAIR_PIVOT,
} from "./rig-spec.mjs";

const SHOWCASE_MODE = process.env.SCOREKEEPER_ANIMATION_SET === "showcase";
const SHOWCASE_PADDING = 64;
const performanceModule = SHOWCASE_MODE
  ? await import("./gif-performance-spec.mjs")
  : await import("./performance-spec.mjs");
const PERFORMANCE_SPECS = SHOWCASE_MODE
  ? performanceModule.SHOWCASE_PERFORMANCE_SPECS
  : performanceModule.PERFORMANCE_SPECS;
const terminalFrame = (spec) => Math.round(spec.durationSeconds * spec.fps);
const validatePerformanceSpecs = () => SHOWCASE_MODE
  ? performanceModule.validateShowcasePerformanceSpecs()
  : performanceModule.validatePerformanceSpecs();

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const SVG_PATH = join(ROOT, "svg", "scorekeeper-cup-hybrid-a-canonical.svg");
const FRAMES_ROOT = join(ROOT, "frames");
const PREVIEWS = join(ROOT, "previews");
const REPORTS = join(ROOT, "reports");
const svg = readFileSync(SVG_PATH, "utf8");
const pathElements = [...svg.matchAll(/<path\s+[^>]*\/>/g)].map((match) => match[0]);

if (pathElements.length !== 181) throw new Error(`Expected 181 path elements, found ${pathElements.length}`);
mkdirSync(FRAMES_ROOT, { recursive: true });
mkdirSync(PREVIEWS, { recursive: true });
mkdirSync(REPORTS, { recursive: true });

const hairIndices = new Set(HAIR_SOURCE_PATH_INDICES);
const bodyParts = CANONICAL_PARTS.filter((entry) => !hairIndices.has(entry.sourceIndex));
const hairParts = CANONICAL_PARTS.filter((entry) => hairIndices.has(entry.sourceIndex));

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
  const e = pivot.x + dx - a * pivot.x - c * pivot.y;
  const f = pivot.y + dy - b * pivot.x - d * pivot.y;
  return [a, b, c, d, e, f];
}

function composeMatrices(parent, child) {
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

function transformedPoint(matrix, x, y) {
  return {
    x: matrix[0] * x + matrix[2] * y + matrix[4],
    y: matrix[1] * x + matrix[3] * y + matrix[5],
  };
}

function formatted(value) {
  return Number(value.toFixed(6));
}

function renderPart(entry, matrix, { fill = entry.svgColor, opacity = 1 } = {}) {
  const d = entry.paths.map((contour) => contour.commands.map((command) => {
    if (command.commandType === "close") return "Z";
    const point = transformedPoint(matrix, command.x, command.y);
    const prefix = command.commandType === "moveTo" ? "M" : "L";
    return `${prefix}${formatted(point.x)},${formatted(point.y)}`;
  }).join(" ")).join(" ");
  const opacityAttribute = opacity < 1 ? ` opacity="${opacity}"` : "";
  return `<path d="${d}" fill="${fill}"${opacityAttribute}/>`;
}

function renderSvg(spec, frame) {
  const padding = SHOWCASE_MODE && spec ? SHOWCASE_PADDING : 0;
  const width = CANVAS.width + padding * 2;
  const height = CANVAS.height + padding * 2;
  const showcaseBackground = SHOWCASE_MODE && spec
    ? `<rect width="${width}" height="${height}" fill="#F4F2EC"/>`
    : "";
  const stageMatrix = [1, 0, 0, 1, padding, padding];
  const rootMatrix = composeMatrices(stageMatrix, matrixFor(spec?.tracks?.rig_root, frame, ROOT_PIVOT));
  const hairMatrix = composeMatrices(rootMatrix, matrixFor(spec?.tracks?.rig_hair, frame, HAIR_PIVOT));
  const underlapOpacity = trackValue(spec?.tracks?.rig_body__hair_underlap?.opacity, frame) ?? 0;
  const bodyMarkup = bodyParts.map((entry) => renderPart(entry, rootMatrix)).join("\n");
  const underlapMarkup = underlapOpacity > 0
    ? hairParts.map((entry) => renderPart(entry, rootMatrix, { fill: "#EFB944", opacity: underlapOpacity })).join("\n")
    : "";
  const hairMarkup = hairParts.map((entry) => renderPart(entry, hairMatrix)).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  ${showcaseBackground}
  <g id="rig_body">${bodyMarkup}</g>
  <g id="rig_body__hair_underlap">${underlapMarkup}</g>
  <g id="rig_hair">${hairMarkup}</g>
</svg>
`;
}

writeFileSync(join(PREVIEWS, "rig-neutral.svg"), renderSvg(null, 0));

const animationReports = [];
for (const spec of PERFORMANCE_SPECS) {
  const directory = join(FRAMES_ROOT, spec.slug);
  mkdirSync(directory, { recursive: true });
  const terminal = terminalFrame(spec);
  const step = Math.max(1, Math.round(spec.fps / 15));
  const frames = [...new Set([
    ...Array.from({ length: Math.floor(terminal / step) + 1 }, (_, index) => Math.min(index * step, terminal)),
    terminal,
    ...spec.semanticPreviewFrames,
  ])].sort((left, right) => left - right);
  for (const frame of frames) {
    writeFileSync(join(directory, `${String(frame).padStart(4, "0")}.svg`), renderSvg(spec, frame));
  }
  animationReports.push({
    slug: spec.slug,
    durationSeconds: spec.durationSeconds,
    terminalFrame: terminal,
    loop: spec.loop,
    requiredControls: spec.requiredControls,
    movingControlCount: Object.keys(spec.tracks).length,
    semanticPreviewFrames: spec.semanticPreviewFrames,
    renderedFrameCount: frames.length,
    endpointsPresent: frames[0] === 0 && frames.at(-1) === terminal,
  });
}

const validation = validatePerformanceSpecs();
const report = {
  status: validation.valid ? "proofs-authored" : "failed",
  canvas: CANVAS,
  previewCanvas: SHOWCASE_MODE
    ? { width: CANVAS.width + SHOWCASE_PADDING * 2, height: CANVAS.height + SHOWCASE_PADDING * 2, transparentPadding: SHOWCASE_PADDING }
    : CANVAS,
  canonicalPathCount: pathElements.length,
  bodyPathCount: pathElements.length - hairIndices.size,
  hairComponent: {
    control: "rig_hair",
    sourcePathIndices: [...hairIndices],
    nativeVectorChildCount: hairIndices.size,
    pivot: HAIR_PIVOT,
    hiddenUnderlap: "rig_body__hair_underlap",
  },
  palette: PALETTE,
  performanceValidation: validation,
  animations: animationReports,
  visibilitySwitchingUsed: false,
  structuralUnderlapOpacityAnimated: true,
  fullPoseDuplicationUsed: false,
};
const reportName = SHOWCASE_MODE ? "offline-preview-qa-showcase.json" : "offline-preview-qa.json";
writeFileSync(join(REPORTS, reportName), `${JSON.stringify(report, null, 2)}\n`);
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
