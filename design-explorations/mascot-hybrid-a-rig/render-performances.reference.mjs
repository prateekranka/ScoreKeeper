#!/usr/bin/env node

/**
 * Canonical proof renderer for the Pocket Bookkeeper articulated Rive rig.
 *
 * The renderer deliberately consumes the same local-transform performance spec
 * used by the Rive builder. Every canonical frame is first written as vector
 * SVG at 60 fps, then rasterized at 512 x 512 with CairoSVG. Review GIFs are
 * sampled from those canonical frames at 20 fps.
 *
 * Usage:
 *   node render-performances.mjs
 *   node render-performances.mjs --only 01_welcome__full_wave
 *   node render-performances.mjs --smoke
 *   node render-performances.mjs --strict
 */

import { execFile, execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, join, relative } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import {
  BASE_BY_NAME,
  CANVAS,
  COLORS,
  FPS,
  NODES,
  PIVOTS,
} from "./rig-spec.mjs";
import { PERFORMANCE_SPECS as RAW_PERFORMANCE_SPECS } from "./performance-spec.mjs";

const execFileAsync = promisify(execFile);
const ROOT = fileURLToPath(new URL(".", import.meta.url));
const FRAMES_DIR = join(ROOT, "frames");
const GIF_DIR = join(ROOT, "gifs");
const PREVIEW_DIR = join(ROOT, "previews");
const MANIFEST_PATH = join(ROOT, "preview-manifest.json");
const QA_PATH = join(ROOT, "preview-qa-report.json");
const CONTACT_SHEET_PATH = join(PREVIEW_DIR, "pocket-bookkeeper-semantic-contact-sheet.png");
const PALETTE_PATH = join(PREVIEW_DIR, "pocket-bookkeeper-palette.png");
const GIF_FPS = 20;
const GIF_FRAME_STEP = FPS / GIF_FPS;
const EPSILON = 1e-6;
const FONT = existsSync("/System/Library/Fonts/Supplemental/Arial.ttf")
  ? "/System/Library/Fonts/Supplemental/Arial.ttf"
  : "/System/Library/Fonts/SFNS.ttf";

if (!Number.isInteger(GIF_FRAME_STEP)) {
  throw new Error(`Canonical FPS ${FPS} must be evenly divisible by GIF FPS ${GIF_FPS}.`);
}

const args = new Set(process.argv.slice(2));
const optionValue = (name) => {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
};
const ONLY = optionValue("--only");
const SMOKE = args.has("--smoke");
const STRICT = args.has("--strict");
const KEEP_FRAMES = !args.has("--discard-frames");

function commandPath(candidates) {
  for (const candidate of candidates) {
    try {
      return execFileSync("/usr/bin/which", [candidate], { encoding: "utf8" }).trim();
    } catch {
      // Try the next executable name.
    }
  }
  return null;
}

const CAIROSVG = commandPath(["cairosvg"]);
const MAGICK = commandPath(["magick", "convert"]);
const IDENTIFY = commandPath(["identify", "magick"]);

function requireTools() {
  const missing = [];
  if (!CAIROSVG) missing.push("cairosvg");
  if (!MAGICK) missing.push("magick/convert");
  if (!IDENTIFY) missing.push("identify");
  if (missing.length) throw new Error(`Missing required renderer tools: ${missing.join(", ")}`);
}

function normalizePerformances(raw) {
  let entries;
  if (Array.isArray(raw)) entries = raw;
  else if (Array.isArray(raw?.performances)) entries = raw.performances;
  else if (raw && typeof raw === "object") {
    entries = Object.entries(raw).map(([id, spec]) => ({ id, ...spec }));
  } else {
    throw new Error("PERFORMANCE_SPECS must be an array or an object of performance specs.");
  }

  return entries.map((spec, index) => {
    const id = spec.id ?? spec.slug ?? spec.name ?? `performance_${index + 1}`;
    const durationFrames = Number(
      spec.durationFrames ??
        spec.endFrame ??
        spec.lastFrame ??
        (spec.durationSeconds != null ? Math.round(spec.durationSeconds * FPS) : NaN),
    );
    if (!Number.isInteger(durationFrames) || durationFrames < 1) {
      throw new Error(`${id}: durationFrames/endFrame must be a positive integer.`);
    }
    const normalized = {
      ...spec,
      id,
      slug: spec.slug ?? slugify(id),
      label: spec.label ?? spec.displayName ?? spec.name ?? humanize(id),
      durationFrames,
      loop: Boolean(spec.loop ?? spec.isLooping ?? spec.runtimeLoop),
      tracks: spec.tracks ?? {},
    };
    validatePerformanceSpec(normalized);
    return normalized;
  });
}

function validatePerformanceSpec(spec) {
  const pivotNames = new Set(PIVOTS.map((pivot) => pivot.name));
  const allowedProperties = new Set(["dx", "dy", "rotationDeg", "scaleX", "scaleY", "opacity"]);
  for (const [pivotName, track] of Object.entries(spec.tracks)) {
    if (!pivotNames.has(pivotName)) throw new Error(`${spec.id}: track targets unknown pivot ${pivotName}.`);
    for (const [property, rawKeyframes] of Object.entries(track)) {
      if (!allowedProperties.has(property)) {
        throw new Error(`${spec.id}: unsupported track property ${pivotName}.${property}.`);
      }
      for (const [frame, value] of normalizeKeyframes(rawKeyframes)) {
        if (!Number.isFinite(frame) || !Number.isFinite(value)) {
          throw new Error(`${spec.id}: ${pivotName}.${property} contains a non-finite keyframe.`);
        }
        if (frame < 0 || frame > spec.durationFrames) {
          throw new Error(
            `${spec.id}: ${pivotName}.${property} frame ${frame} is outside 0…${spec.durationFrames}.`,
          );
        }
      }
    }
  }
}

function slugify(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function humanize(value) {
  return String(value)
    .replace(/^\d+[_-]*/, "")
    .replace(/__+/g, " — ")
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function round(value, digits = 4) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function xmlEscape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function normalizeKeyframes(rawTrack) {
  if (rawTrack == null) return [];
  if (typeof rawTrack === "number") return [[0, rawTrack]];
  if (!Array.isArray(rawTrack)) throw new Error("A property track must be a number or keyframe array.");
  return rawTrack
    .map((keyframe) => {
      if (Array.isArray(keyframe)) return [Number(keyframe[0]), Number(keyframe[1])];
      if (keyframe && typeof keyframe === "object") {
        return [Number(keyframe.frame ?? keyframe.time), Number(keyframe.value)];
      }
      throw new Error(`Unsupported keyframe ${JSON.stringify(keyframe)}`);
    })
    .sort((a, b) => a[0] - b[0]);
}

function interpolate(rawTrack, frame, fallback) {
  const keyframes = normalizeKeyframes(rawTrack);
  if (!keyframes.length) return fallback;
  if (frame <= keyframes[0][0]) return keyframes[0][1];
  const last = keyframes.at(-1);
  if (frame >= last[0]) return last[1];
  let low = 0;
  let high = keyframes.length - 1;
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (keyframes[middle][0] <= frame) low = middle;
    else high = middle;
  }
  const [frameA, valueA] = keyframes[low];
  const [frameB, valueB] = keyframes[high];
  const progress = (frame - frameA) / (frameB - frameA);
  return valueA + (valueB - valueA) * progress;
}

function evaluatedPivot(spec, pivot, frame) {
  const base = BASE_BY_NAME[pivot.name];
  const track = spec.tracks[pivot.name] ?? {};
  return {
    x: base.x + interpolate(track.dx, frame, 0),
    y: base.y + interpolate(track.dy, frame, 0),
    rotation: base.rotation + (interpolate(track.rotationDeg, frame, 0) * Math.PI) / 180,
    scaleX: interpolate(track.scaleX, frame, base.scaleX),
    scaleY: interpolate(track.scaleY, frame, base.scaleY),
    opacity: Math.max(0, Math.min(1, interpolate(track.opacity, frame, base.opacity))),
  };
}

function localMatrix(transform) {
  const cosine = Math.cos(transform.rotation);
  const sine = Math.sin(transform.rotation);
  // Local = T * R * S. SVG's six matrix values are [a b c d e f].
  return [
    cosine * transform.scaleX,
    sine * transform.scaleX,
    -sine * transform.scaleY,
    cosine * transform.scaleY,
    transform.x,
    transform.y,
  ];
}

function multiplyMatrices(left, right) {
  const [a1, b1, c1, d1, e1, f1] = left;
  const [a2, b2, c2, d2, e2, f2] = right;
  return [
    a1 * a2 + c1 * b2,
    b1 * a2 + d1 * b2,
    a1 * c2 + c1 * d2,
    b1 * c2 + d1 * d2,
    a1 * e2 + c1 * f2 + e1,
    b1 * e2 + d1 * f2 + f1,
  ];
}

function transformPoint(matrix, x = 0, y = 0) {
  return {
    x: matrix[0] * x + matrix[2] * y + matrix[4],
    y: matrix[1] * x + matrix[3] * y + matrix[5],
  };
}

function matrixAttribute(matrix) {
  return `matrix(${matrix.map((value) => round(value, 6)).join(" ")})`;
}

function riveColor(riveArgb) {
  if (!/^#[0-9A-Fa-f]{8}$/.test(riveArgb)) return { color: riveArgb, opacity: 1 };
  return {
    color: `#${riveArgb.slice(3)}`.toUpperCase(),
    opacity: parseInt(riveArgb.slice(1, 3), 16) / 255,
  };
}

function pathData(commands) {
  return commands
    .map((command) => {
      if (command.commandType === "moveTo") return `M ${round(command.x, 3)} ${round(command.y, 3)}`;
      if (command.commandType === "lineTo") return `L ${round(command.x, 3)} ${round(command.y, 3)}`;
      if (command.commandType === "cubicTo") {
        return `C ${round(command.control1X, 3)} ${round(command.control1Y, 3)} ${round(command.control2X, 3)} ${round(command.control2Y, 3)} ${round(command.endX, 3)} ${round(command.endY, 3)}`;
      }
      if (command.commandType === "close") return "Z";
      throw new Error(`Unsupported path command ${command.commandType}`);
    })
    .join(" ");
}

function partMarkup(node) {
  const fill = node.paints.find((paint) => paint.paintType === "fill");
  const stroke = node.paints.find((paint) => paint.paintType === "stroke");
  const fillColor = fill ? riveColor(fill.color) : null;
  const strokeColor = stroke ? riveColor(stroke.color) : null;
  const attributes = [
    fillColor ? `fill="${fillColor.color}"` : 'fill="none"',
    fillColor && fillColor.opacity !== 1 ? `fill-opacity="${round(fillColor.opacity)}"` : "",
    strokeColor ? `stroke="${strokeColor.color}"` : "",
    strokeColor && strokeColor.opacity !== 1 ? `stroke-opacity="${round(strokeColor.opacity)}"` : "",
    stroke ? `stroke-width="${stroke.width}"` : "",
    stroke ? 'stroke-linecap="round" stroke-linejoin="round"' : "",
  ]
    .filter(Boolean)
    .join(" ");
  const transform = node.x || node.y ? ` transform="translate(${node.x} ${node.y})"` : "";
  return `<g id="${xmlEscape(node.name)}"${transform}>\n${node.paths
    .map(
      (path) =>
        `  <path id="${xmlEscape(`${node.name}__${path.name}`)}" d="${pathData(path.commands)}" ${attributes}/>`,
    )
    .join("\n")}\n</g>`;
}

const CHILDREN = (() => {
  const children = new Map();
  for (const node of NODES) {
    const siblings = children.get(node.parent) ?? [];
    siblings.push(node);
    children.set(node.parent, siblings);
  }
  return children;
})();

function frameState(spec, frame) {
  const transforms = new Map();
  const worldMatrices = new Map();
  const worldOpacities = new Map();
  for (const pivot of PIVOTS) transforms.set(pivot.name, evaluatedPivot(spec, pivot, frame));

  function visit(pivot, parentWorld = [1, 0, 0, 1, 0, 0], parentOpacity = 1) {
    const transform = transforms.get(pivot.name);
    const world = multiplyMatrices(parentWorld, localMatrix(transform));
    const opacity = parentOpacity * transform.opacity;
    worldMatrices.set(pivot.name, world);
    worldOpacities.set(pivot.name, opacity);
    for (const child of CHILDREN.get(pivot.name) ?? []) {
      if (child.kind === "pivot") visit(child, world, opacity);
    }
  }
  for (const root of CHILDREN.get(null) ?? []) {
    if (root.kind === "pivot") visit(root);
  }
  return { transforms, worldMatrices, worldOpacities };
}

function renderTree(spec, frame) {
  const state = frameState(spec, frame);
  function render(node, depth = 0) {
    const indent = "  ".repeat(depth);
    if (node.kind === "part") return `${indent}${partMarkup(node).replaceAll("\n", `\n${indent}`)}`;
    const transform = state.transforms.get(node.name);
    const contents = (CHILDREN.get(node.name) ?? [])
      .map((child) => render(child, depth + 1))
      .join("\n");
    return `${indent}<g id="${xmlEscape(node.name)}" transform="${matrixAttribute(localMatrix(transform))}" opacity="${round(transform.opacity, 6)}">\n${contents}\n${indent}</g>`;
  }
  return (CHILDREN.get(null) ?? []).map((node) => render(node, 1)).join("\n");
}

function frameSvg(spec, frame) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}">
  <title>${xmlEscape(spec.label)} — frame ${frame}</title>
  <metadata>Canonical ${FPS}fps frame ${frame}/${spec.durationFrames}; runtimeLoop=${spec.loop}</metadata>
  <rect width="${CANVAS}" height="${CANVAS}" fill="${COLORS.cobalt.toUpperCase()}"/>
${renderTree(spec, frame)}
</svg>
`;
}

function frameName(frame) {
  return `frame-${String(frame).padStart(4, "0")}`;
}

function relativePath(path) {
  return relative(ROOT, path).split("\\").join("/");
}

async function runLimited(tasks, concurrency = 8) {
  let next = 0;
  const workers = Array.from({ length: Math.min(concurrency, tasks.length) }, async () => {
    while (next < tasks.length) {
      const index = next++;
      await tasks[index]();
    }
  });
  await Promise.all(workers);
}

function canonicalFrames(spec) {
  return Array.from({ length: spec.durationFrames + 1 }, (_, frame) => frame);
}

function smokeFrames(spec) {
  return [...new Set([0, Math.round(spec.durationFrames / 2), spec.durationFrames])].sort((a, b) => a - b);
}

function gifFrames(spec) {
  const frames = [];
  const terminal = spec.loop ? spec.durationFrames - 1 : spec.durationFrames;
  for (let frame = 0; frame <= terminal; frame += GIF_FRAME_STEP) frames.push(frame);
  if (!spec.loop && frames.at(-1) !== spec.durationFrames) frames.push(spec.durationFrames);
  return frames;
}

function contactFrames(spec) {
  const provided = spec.contactFrames ?? spec.previewFrames;
  if (Array.isArray(provided) && provided.length) {
    return provided.slice(0, 4).map((frame) => Math.max(0, Math.min(spec.durationFrames, Math.round(frame))));
  }
  return [0, 0.28, 0.58, spec.loop ? 0.86 : 1].map((ratio) => Math.round(spec.durationFrames * ratio));
}

function stageLabels(spec) {
  const labels = spec.contactLabels ?? spec.previewLabels;
  return Array.isArray(labels) && labels.length >= 4
    ? labels.slice(0, 4)
    : ["START", "ANTICIPATE", "ACTION", spec.loop ? "LOOP RETURN" : "RESOLVE"];
}

function createPalette() {
  mkdirSync(PREVIEW_DIR, { recursive: true });
  execFileSync(MAGICK, [
    "-size",
    "1x1",
    `xc:${COLORS.cobalt}`,
    "-size",
    "1x1",
    `xc:${COLORS.cream}`,
    "+append",
    PALETTE_PATH,
  ]);
}

async function renderPerformance(spec) {
  const performanceDir = join(FRAMES_DIR, spec.slug);
  const svgDir = join(performanceDir, "svg");
  const pngDir = join(performanceDir, "png");
  rmSync(performanceDir, { recursive: true, force: true });
  mkdirSync(svgDir, { recursive: true });
  mkdirSync(pngDir, { recursive: true });

  const requestedFrames = SMOKE ? smokeFrames(spec) : canonicalFrames(spec);
  for (const frame of requestedFrames) {
    writeFileSync(join(svgDir, `${frameName(frame)}.svg`), frameSvg(spec, frame));
  }

  await runLimited(
    requestedFrames.map((frame) => async () => {
      await execFileAsync(CAIROSVG, [
        join(svgDir, `${frameName(frame)}.svg`),
        "-o",
        join(pngDir, `${frameName(frame)}.png`),
        "--output-width",
        String(CANVAS),
        "--output-height",
        String(CANVAS),
      ]);
    }),
  );

  if (SMOKE) {
    return {
      spec,
      svgDir,
      pngDir,
      gifPath: null,
      renderedFrames: requestedFrames,
      gifSampleFrames: [],
    };
  }

  const sampledFrames = gifFrames(spec);
  const gifSuffix = spec.loop ? "loop" : "replay-preview";
  const gifPath = join(GIF_DIR, `${spec.slug}-${gifSuffix}.gif`);
  rmSync(gifPath, { force: true });
  const gifArgs = ["-delay", String(100 / GIF_FPS)];
  for (const frame of sampledFrames) gifArgs.push(join(pngDir, `${frameName(frame)}.png`));
  // A longer last-frame delay makes the one-shot's resolved pose readable. The
  // file is explicitly named as a replay preview; this does not alter runtime looping.
  if (!spec.loop) {
    gifArgs.push("-delay", "35", join(pngDir, `${frameName(spec.durationFrames)}.png`));
  }
  gifArgs.push("-dither", "None", "-remap", PALETTE_PATH, "-layers", "Optimize", "-loop", "0", gifPath);
  execFileSync(MAGICK, gifArgs, { maxBuffer: 64 * 1024 * 1024 });

  return {
    spec,
    svgDir,
    pngDir,
    gifPath,
    renderedFrames: requestedFrames,
    gifSampleFrames: sampledFrames,
  };
}

function trackStatistics(spec) {
  const properties = ["dx", "dy", "rotationDeg", "scaleX", "scaleY", "opacity"];
  const animatedPivots = new Set();
  const articulatedPivots = new Set();
  const opacityPivots = new Set();
  const propertyRanges = {};
  let keyframeCount = 0;
  let animatedPropertyCount = 0;

  for (const [pivotName, track] of Object.entries(spec.tracks)) {
    for (const property of properties) {
      if (track[property] == null) continue;
      const values = normalizeKeyframes(track[property]).map(([, value]) => value);
      keyframeCount += values.length;
      const min = Math.min(...values);
      const max = Math.max(...values);
      const range = max - min;
      propertyRanges[`${pivotName}.${property}`] = { min: round(min), max: round(max), range: round(range) };
      if (range > EPSILON) {
        animatedPivots.add(pivotName);
        animatedPropertyCount += 1;
        if (/arm|paw|leg|foot|head|ear|eye|tail/.test(pivotName)) articulatedPivots.add(pivotName);
        if (property === "opacity") opacityPivots.add(pivotName);
      }
    }
  }

  const worldOrigins = new Map(PIVOTS.map((pivot) => [pivot.name, []]));
  for (const frame of canonicalFrames(spec)) {
    const state = frameState(spec, frame);
    for (const pivot of PIVOTS) {
      worldOrigins.get(pivot.name).push(transformPoint(state.worldMatrices.get(pivot.name)));
    }
  }
  const travelByPivot = {};
  let peakWorldTravelPx = 0;
  let peakWorldTravelPivot = null;
  for (const [pivotName, points] of worldOrigins) {
    let travel = 0;
    for (let index = 1; index < points.length; index += 1) {
      travel += Math.hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y);
    }
    travelByPivot[pivotName] = round(travel, 2);
    if (travel > peakWorldTravelPx) {
      peakWorldTravelPx = travel;
      peakWorldTravelPivot = pivotName;
    }
  }

  const rootStart = worldOrigins.get("rig_root")?.[0];
  const rootDisplacements = (worldOrigins.get("rig_root") ?? []).map((point) =>
    Math.hypot(point.x - rootStart.x, point.y - rootStart.y),
  );
  const isIdle = `${spec.id} ${spec.slug}`.toLowerCase().includes("idle");
  const richnessPassed =
    animatedPivots.size >= (isIdle ? 3 : 5) &&
    articulatedPivots.size >= (isIdle ? 2 : 3) &&
    peakWorldTravelPx >= (isIdle ? 3 : 20);

  return {
    keyframeCount,
    animatedPivotCount: animatedPivots.size,
    animatedPivots: [...animatedPivots],
    articulatedPivotCount: articulatedPivots.size,
    articulatedPivots: [...articulatedPivots],
    opacityEventPivotCount: opacityPivots.size,
    animatedPropertyCount,
    rootPeakDisplacementPx: round(Math.max(0, ...rootDisplacements), 2),
    peakWorldTravelPx: round(peakWorldTravelPx, 2),
    peakWorldTravelPivot,
    travelByPivot,
    propertyRanges,
    richnessPassed,
  };
}

function loopEndpointValidation(spec) {
  if (!spec.loop) return { required: false, passed: true, maxDelta: 0, differences: [] };
  const start = frameState(spec, 0);
  const end = frameState(spec, spec.durationFrames);
  const differences = [];
  let maxDelta = 0;
  for (const pivot of PIVOTS) {
    const a = start.transforms.get(pivot.name);
    const b = end.transforms.get(pivot.name);
    for (const property of ["x", "y", "rotation", "scaleX", "scaleY", "opacity"]) {
      const delta = Math.abs(a[property] - b[property]);
      maxDelta = Math.max(maxDelta, delta);
      if (delta > EPSILON) differences.push({ pivot: pivot.name, property, delta: round(delta, 8) });
    }
  }
  return { required: true, passed: differences.length === 0, maxDelta: round(maxDelta, 8), differences };
}

function semanticBeatValidation(spec) {
  const beats = spec.semanticBeats ?? spec.beats;
  if (!beats) return { provided: false, passed: true, orderedFrames: [] };
  const values = Array.isArray(beats)
    ? beats.map((beat) => ({ name: beat.name ?? beat.label ?? "beat", frame: Number(beat.frame ?? beat.time) }))
    : Object.entries(beats).map(([name, frame]) => ({ name, frame: Number(frame) }));
  const passed = values.every(
    (beat, index) =>
      Number.isFinite(beat.frame) &&
      beat.frame >= 0 &&
      beat.frame <= spec.durationFrames &&
      (index === 0 || beat.frame >= values[index - 1].frame),
  );
  return { provided: true, passed, orderedFrames: values };
}

function identifyDimensions(paths) {
  const { stdout } = execFileSyncCapture(IDENTIFY, ["-format", "%wx%h\n", ...paths]);
  return [...new Set(stdout.trim().split(/\s+/).filter(Boolean))];
}

function execFileSyncCapture(command, commandArgs) {
  try {
    return { stdout: execFileSync(command, commandArgs, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 }) };
  } catch (error) {
    return { stdout: "", error: error.message };
  }
}

function gifFrameCount(gifPath) {
  if (!gifPath) return 0;
  const { stdout } = execFileSyncCapture(IDENTIFY, ["-format", "%n\n", gifPath]);
  const count = Number(stdout.trim().split(/\s+/)[0]);
  return Number.isFinite(count) ? count : 0;
}

function gifPaletteValidation(gifPath) {
  if (!gifPath) return { required: false, passed: true, colors: [] };
  const { stdout, error } = execFileSyncCapture(MAGICK, [
    gifPath,
    "-coalesce",
    "-unique-colors",
    "txt:-",
  ]);
  const colors = [...stdout.matchAll(/#([0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?\b/g)].map(
    (match) => `#${match[1].toUpperCase()}`,
  );
  const uniqueColors = [...new Set(colors)];
  const allowed = new Set([COLORS.cobalt.toUpperCase(), COLORS.cream.toUpperCase()]);
  return {
    required: true,
    passed: !error && uniqueColors.length === 2 && uniqueColors.every((color) => allowed.has(color)),
    colors: uniqueColors,
    error: error ?? null,
  };
}

function svgValidation(rendered) {
  const sampleFrames = [...new Set([0, Math.round(rendered.spec.durationFrames / 2), rendered.spec.durationFrames])];
  const checks = sampleFrames.map((frame) => {
    const path = join(rendered.svgDir, `${frameName(frame)}.svg`);
    const svg = readFileSync(path, "utf8");
    return {
      frame,
      width512: /width="512"/.test(svg),
      height512: /height="512"/.test(svg),
      cobaltPresent: svg.toUpperCase().includes(COLORS.cobalt.toUpperCase()),
      creamPresent: svg.toUpperCase().includes(COLORS.cream.toUpperCase()),
      noRasterImage: !/<image\b/i.test(svg),
      usesLocalMatrices: /transform="matrix\(/.test(svg),
    };
  });
  return {
    passed: checks.every((check) => Object.entries(check).every(([key, value]) => key === "frame" || value === true)),
    checks,
  };
}

function buildContactSheet(renderedPerformances) {
  if (SMOKE) return null;
  const contactDir = join(PREVIEW_DIR, ".contact-sheet-work");
  rmSync(contactDir, { recursive: true, force: true });
  mkdirSync(contactDir, { recursive: true });
  const rows = [];
  renderedPerformances.slice(0, 7).forEach((rendered, rowIndex) => {
    const { spec, pngDir } = rendered;
    const labelPath = join(contactDir, `row-${rowIndex}-label.png`);
    const rowPath = join(contactDir, `row-${rowIndex}.png`);
    const runtimeKind = spec.loop ? "RUNTIME LOOP" : "ONE-SHOT ACTION";
    execFileSync(MAGICK, [
      "-size",
      "300x220",
      `xc:${COLORS.cobalt}`,
      "-font",
      FONT,
      "-fill",
      COLORS.cream,
      "-pointsize",
      "18",
      "-gravity",
      "Center",
      "-annotate",
      "+0-22",
      spec.label.replace(" — ", "\n"),
      "-pointsize",
      "13",
      "-annotate",
      "+0+42",
      runtimeKind,
      labelPath,
    ]);
    const thumbs = contactFrames(spec).map((frame, columnIndex) => {
      const thumbPath = join(contactDir, `row-${rowIndex}-thumb-${columnIndex}.png`);
      execFileSync(MAGICK, [
        join(pngDir, `${frameName(frame)}.png`),
        "-resize",
        "220x220!",
        "-font",
        FONT,
        "-stroke",
        COLORS.cobalt,
        "-strokewidth",
        "4",
        "-fill",
        COLORS.cream,
        "-pointsize",
        "13",
        "-gravity",
        "North",
        "-annotate",
        "+0+12",
        stageLabels(spec)[columnIndex],
        "-stroke",
        "none",
        "-annotate",
        "+0+12",
        stageLabels(spec)[columnIndex],
        thumbPath,
      ]);
      return thumbPath;
    });
    execFileSync(MAGICK, [labelPath, ...thumbs, "+append", rowPath]);
    rows.push(rowPath);
  });
  execFileSync(MAGICK, [...rows, "-append", CONTACT_SHEET_PATH]);
  rmSync(contactDir, { recursive: true, force: true });
  return CONTACT_SHEET_PATH;
}

function buildReport(renderedPerformances, contactSheetPath) {
  const performances = renderedPerformances.map((rendered) => {
    const { spec, svgDir, pngDir, gifPath, renderedFrames, gifSampleFrames } = rendered;
    const loopEndpoints = loopEndpointValidation(spec);
    const semanticBeats = semanticBeatValidation(spec);
    const richness = trackStatistics(spec);
    const vector = svgValidation(rendered);
    const dimensionFrames = [...new Set([0, Math.round(spec.durationFrames / 2), spec.durationFrames])];
    const sampledPngs = dimensionFrames.map((frame) => join(pngDir, `${frameName(frame)}.png`));
    const dimensions = identifyDimensions(sampledPngs);
    const expectedCanonicalCount = SMOKE ? smokeFrames(spec).length : spec.durationFrames + 1;
    const actualGifFrameCount = gifFrameCount(gifPath);
    const expectedGifFrames = SMOKE ? 0 : gifSampleFrames.length + (spec.loop ? 0 : 1);
    const gifPalette = gifPaletteValidation(gifPath);
    const validations = {
      canonicalFrameCount: {
        expected: expectedCanonicalCount,
        actual: renderedFrames.length,
        passed: renderedFrames.length === expectedCanonicalCount,
      },
      pngDimensions: { expected: `${CANVAS}x${CANVAS}`, actual: dimensions, passed: dimensions.length === 1 && dimensions[0] === `${CANVAS}x${CANVAS}` },
      vector,
      loopEndpoints,
      semanticBeats,
      richness: { passed: richness.richnessPassed },
      gifPalette,
      gifFrameCount: {
        expected: expectedGifFrames,
        actual: actualGifFrameCount,
        passed: SMOKE || actualGifFrameCount > 0,
        note: spec.loop
          ? "Duplicate terminal runtime-loop frame intentionally omitted."
          : "Includes one duplicate resolved frame with a longer hold for replay review only.",
      },
    };
    const passed = Object.values(validations).every((validation) => validation.passed !== false);
    return {
      id: spec.id,
      label: spec.label,
      slug: spec.slug,
      runtimeLoop: spec.loop,
      durationFrames: spec.durationFrames,
      durationSeconds: round(spec.durationFrames / FPS, 3),
      canonicalFps: FPS,
      canonicalFrameCount: renderedFrames.length,
      gifPreviewFps: GIF_FPS,
      gifSampleFrames,
      artifacts: {
        svgFrames: relativePath(svgDir),
        pngFrames: relativePath(pngDir),
        gifPreview: gifPath ? relativePath(gifPath) : null,
      },
      richness,
      validations,
      passed,
    };
  });

  const report = {
    schemaVersion: 2,
    generatedAt: new Date().toISOString(),
    renderer: basename(fileURLToPath(import.meta.url)),
    mode: SMOKE ? "smoke" : "full",
    canvas: { width: CANVAS, height: CANVAS, canonicalFps: FPS, gifPreviewFps: GIF_FPS },
    palette: { cobalt: COLORS.cobalt.toUpperCase(), cream: COLORS.cream.toUpperCase() },
    transformConvention: "FK with Local = T * R * S; world = parentWorld * Local",
    performanceCount: performances.length,
    artifacts: {
      semanticContactSheet: contactSheetPath ? relativePath(contactSheetPath) : null,
      palette: relativePath(PALETTE_PATH),
    },
    performances,
    passed: performances.every((performance) => performance.passed),
  };
  return report;
}

async function main() {
  requireTools();
  mkdirSync(FRAMES_DIR, { recursive: true });
  mkdirSync(GIF_DIR, { recursive: true });
  mkdirSync(PREVIEW_DIR, { recursive: true });
  createPalette();

  let performances = normalizePerformances(RAW_PERFORMANCE_SPECS);
  if (ONLY) {
    performances = performances.filter(
      (spec) => spec.id === ONLY || spec.slug === slugify(ONLY) || spec.id.includes(ONLY),
    );
    if (!performances.length) throw new Error(`No performance matched --only ${ONLY}`);
  }
  if (SMOKE) performances = performances.slice(0, 1);
  if (!SMOKE && !ONLY && performances.length !== 7) {
    console.warn(`Expected seven mascot performances for the semantic contact sheet; found ${performances.length}.`);
  }

  const rendered = [];
  for (const spec of performances) {
    console.log(`Rendering ${spec.id} (${spec.durationFrames + 1} canonical frames)...`);
    rendered.push(await renderPerformance(spec));
  }

  const contactSheetPath = buildContactSheet(rendered);
  const report = buildReport(rendered, contactSheetPath);
  writeFileSync(QA_PATH, `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(
    MANIFEST_PATH,
    `${JSON.stringify(
      {
        ...report,
        qaReport: relativePath(QA_PATH),
        performances: report.performances.map(({ richness, validations, ...performance }) => performance),
      },
      null,
      2,
    )}\n`,
  );

  if (!KEEP_FRAMES && !SMOKE) rmSync(FRAMES_DIR, { recursive: true, force: true });
  console.log(
    JSON.stringify(
      {
        passed: report.passed,
        performanceCount: report.performanceCount,
        manifest: relativePath(MANIFEST_PATH),
        qaReport: relativePath(QA_PATH),
        contactSheet: contactSheetPath ? relativePath(contactSheetPath) : null,
      },
      null,
      2,
    ),
  );
  if (STRICT && !report.passed) process.exitCode = 2;
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
