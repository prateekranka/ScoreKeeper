import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
export const APPROVED_SVG = path.resolve(ROOT, "../production-v5-vector-master/canonical-dimensional-pixel.svg");
export const APPROVED_SHA256 = "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75";

export const SEMANTIC_PARTS = Object.freeze({
  tab: { indices: [0, 1], pivot: { x: 463, y: 72 }, rig: "rig_tab" },
  cup: { indices: [2, 3, 20, 21, 22, 23, 24, 25, 29, 30, 31, 32], pivot: { x: 255, y: 245 }, rig: "rig_cup" },
  handle_l: { indices: [4, 5, 6, 7, 8, 9, 10, 11], pivot: { x: 88, y: 150 }, rig: "rig_handle_l" },
  handle_r: { indices: [12, 13, 14, 15, 16, 17, 18, 19], pivot: { x: 422, y: 150 }, rig: "rig_handle_r" },
  hair: { indices: [26], pivot: { x: 254, y: 89 }, rig: "rig_hair" },
  badge: { indices: [27, 28], pivot: { x: 118, y: 81 }, rig: "rig_badge" },
  eye_l: { indices: [33], pivot: { x: 196, y: 147 }, rig: "rig_eye_l" },
  eye_r: { indices: [34], pivot: { x: 312, y: 147 }, rig: "rig_eye_r" },
  mouth: { indices: [35, 36, 37], pivot: { x: 255, y: 205 }, rig: "rig_mouth" },
  stem: { indices: [38, 39, 40, 41], pivot: { x: 255, y: 325 }, rig: "rig_stem" },
  base: { indices: [42, 43, 44, 45, 46, 47], pivot: { x: 256, y: 401 }, rig: "rig_base" },
});

const INDEX_TO_PART = new Map(Object.entries(SEMANTIC_PARTS).flatMap(([part, spec]) => spec.indices.map((index) => [index, part])));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function attrs(markup) {
  return Object.fromEntries([...markup.matchAll(/([\w-]+)="([^"]*)"/g)].map((match) => [match[1], match[2]]));
}

function parseColor(value) {
  const hex = value.replace("#", "");
  assert(hex.length === 6, `Expected #rrggbb, found ${value}`);
  return [0, 2, 4].map((offset) => Number.parseInt(hex.slice(offset, offset + 2), 16));
}

function rgbaHex(rgb) {
  return `#ff${rgb.map((channel) => Math.max(0, Math.min(255, Math.round(channel))).toString(16).padStart(2, "0")).join("")}`;
}

function parseOffset(raw) {
  return raw.endsWith("%") ? Number(raw.slice(0, -1)) / 100 : Number(raw);
}

export function parseApprovedSvg(svgText) {
  const gradients = new Map();
  for (const match of svgText.matchAll(/<linearGradient\b([^>]*)>([\s\S]*?)<\/linearGradient>/g)) {
    const definition = attrs(match[1]);
    const stops = [...match[2].matchAll(/<stop\b([^>]*)\/>/g)].map((stop) => {
      const values = attrs(stop[1]);
      return { offset: parseOffset(values.offset), color: parseColor(values["stop-color"]) };
    });
    gradients.set(definition.id, {
      id: definition.id,
      x1: Number(definition.x1),
      y1: Number(definition.y1),
      x2: Number(definition.x2),
      y2: Number(definition.y2),
      stops,
    });
  }
  const withoutDefs = svgText.replace(/<defs>[\s\S]*?<\/defs>/, "");
  const elements = [...withoutDefs.matchAll(/<(rect|path)\b([^>]*)\/>/g)].map((match, index) => {
    const values = attrs(match[2]);
    return {
      index,
      type: match[1],
      fill: values.fill,
      x: values.x == null ? undefined : Number(values.x),
      y: values.y == null ? undefined : Number(values.y),
      width: values.width == null ? undefined : Number(values.width),
      height: values.height == null ? undefined : Number(values.height),
      d: values.d,
      semanticPart: INDEX_TO_PART.get(index),
    };
  });
  assert(gradients.size === 6, `Expected 6 gradients, found ${gradients.size}`);
  assert(elements.length === 48, `Expected 48 visible elements, found ${elements.length}`);
  assert(elements.every((element) => element.semanticPart), "Every source element must map to one semantic part");
  const covered = [...INDEX_TO_PART.keys()].sort((a, b) => a - b);
  assert(JSON.stringify(covered) === JSON.stringify(Array.from({ length: 48 }, (_, index) => index)), "Semantic source coverage must be exact");
  return { gradients, elements };
}

function gradientColor(gradient, y) {
  const denominator = gradient.y2 - gradient.y1;
  const raw = denominator === 0 ? 0 : (y - gradient.y1) / denominator;
  const position = Math.max(0, Math.min(1, raw));
  let left = gradient.stops[0];
  let right = gradient.stops.at(-1);
  for (let index = 1; index < gradient.stops.length; index += 1) {
    if (position <= gradient.stops[index].offset) {
      left = gradient.stops[index - 1];
      right = gradient.stops[index];
      break;
    }
  }
  const span = right.offset - left.offset;
  const t = span === 0 ? 0 : (position - left.offset) / span;
  return left.color.map((channel, index) => channel + (right.color[index] - channel) * t);
}

function hairSpanAt(y) {
  if (y >= 31 && y < 49) return [215, 354];
  if (y >= 49 && y < 72) return [215, 326];
  if (y >= 72 && y < 91) return [236, 286];
  return null;
}

function sourceRows(element) {
  if (element.type === "rect") {
    assert(Number.isInteger(element.x) && Number.isInteger(element.y) && Number.isInteger(element.width) && Number.isInteger(element.height), `Element ${element.index} must be integer aligned`);
    return Array.from({ length: element.height }, (_, offset) => ({ y: element.y + offset, interval: [element.x, element.x + element.width] }));
  }
  assert(element.index === 26, `Unexpected source path at ${element.index}`);
  assert(element.d.replaceAll(/\s+/g, " ").trim() === "M215 31 H354 V49 H326 V72 H286 V91 H236 V72 H215 Z", "Hair path changed after approval");
  return Array.from({ length: 60 }, (_, offset) => ({ y: 31 + offset, interval: hairSpanAt(31 + offset) }));
}

function unionIntervals(intervals) {
  const sorted = intervals.map((interval) => [...interval]).sort((left, right) => left[0] - right[0] || left[1] - right[1]);
  const result = [];
  for (const interval of sorted) {
    const previous = result.at(-1);
    if (previous && interval[0] <= previous[1]) previous[1] = Math.max(previous[1], interval[1]);
    else result.push(interval);
  }
  return result;
}

function fillKey(fill) {
  const match = fill.match(/^url\(#([^)]+)\)$/);
  return match ? match[1] : fill.toLowerCase();
}

function layerGroups(elements) {
  const layerByIndex = new Map();
  for (const part of Object.keys(SEMANTIC_PARTS)) {
    const ordered = elements.filter((element) => element.semanticPart === part).sort((a, b) => a.index - b.index);
    let layer = -1;
    let previousFill = null;
    for (const element of ordered) {
      const key = fillKey(element.fill);
      if (key !== previousFill) layer += 1;
      previousFill = key;
      layerByIndex.set(element.index, layer);
    }
  }
  return layerByIndex;
}

function rectanglePath(name, x1, y1, x2, y2, pivot) {
  return {
    name,
    commands: [
      { commandType: "moveTo", x: x1 - pivot.x, y: y1 - pivot.y },
      { commandType: "lineTo", x: x2 - pivot.x, y: y1 - pivot.y },
      { commandType: "lineTo", x: x2 - pivot.x, y: y2 - pivot.y },
      { commandType: "lineTo", x: x1 - pivot.x, y: y2 - pivot.y },
      { commandType: "close" },
    ],
  };
}

export function buildScanlineShapes(svgText) {
  const parsed = parseApprovedSvg(svgText);
  const layers = layerGroups(parsed.elements);
  const groups = new Map();
  for (const element of parsed.elements) {
    const material = fillKey(element.fill);
    const layer = layers.get(element.index);
    for (const row of sourceRows(element)) {
      const key = `${element.semanticPart}|${layer}|${material}|${row.y}`;
      const group = groups.get(key) ?? {
        semanticPart: element.semanticPart,
        rig: SEMANTIC_PARTS[element.semanticPart].rig,
        material,
        layer,
        y: row.y,
        intervals: [],
        sourceElementIndices: new Set(),
      };
      group.intervals.push(row.interval);
      group.sourceElementIndices.add(element.index);
      groups.set(key, group);
    }
  }
  const shapes = [...groups.values()]
    .sort((left, right) => {
      const leftOrder = Math.min(...left.sourceElementIndices);
      const rightOrder = Math.min(...right.sourceElementIndices);
      return leftOrder - rightOrder || left.layer - right.layer || left.y - right.y;
    })
    .map((group) => {
      const gradient = parsed.gradients.get(group.material);
      const rgb = gradient ? gradientColor(gradient, group.y + 0.5) : parseColor(group.material);
      const pivot = SEMANTIC_PARTS[group.semanticPart].pivot;
      const intervals = unionIntervals(group.intervals);
      return {
        name: `${group.rig}__${group.material.replace("#", "solid_")}__l${String(group.layer).padStart(2, "0")}__y${String(group.y).padStart(3, "0")}`,
        semanticPart: group.semanticPart,
        rig: group.rig,
        material: group.material,
        layer: group.layer,
        y: group.y,
        color: rgbaHex(rgb),
        sourceElementIndices: [...group.sourceElementIndices].sort((a, b) => a - b),
        paths: intervals.map((interval, index) => rectanglePath(`span-${index + 1}`, interval[0], group.y, interval[1], group.y + 1, pivot)),
      };
    });
  const byPart = Object.fromEntries(Object.keys(SEMANTIC_PARTS).map((part) => [part, shapes.filter((shape) => shape.semanticPart === part)]));
  return { ...parsed, shapes, byPart };
}

export function loadApprovedArtwork() {
  const svgText = fs.readFileSync(APPROVED_SVG, "utf8");
  const sha256 = crypto.createHash("sha256").update(svgText).digest("hex");
  assert(sha256 === APPROVED_SHA256, `Approved SVG hash mismatch: ${sha256}`);
  return { svgText, sha256, ...buildScanlineShapes(svgText) };
}

export function selfTest() {
  const artwork = loadApprovedArtwork();
  assert(Object.values(artwork.byPart).every((shapes) => shapes.length > 0), "Every semantic part needs scanline shapes");
  for (const shape of artwork.shapes) {
    assert(/^#[0-9a-f]{8}$/.test(shape.color), `${shape.name}: invalid Rive color ${shape.color}`);
    assert(shape.paths.length > 0, `${shape.name}: missing paths`);
  }
  const gold = artwork.gradients.get("goldBody");
  let maxAdjacentDelta = 0;
  for (let y = 49; y < 244; y += 1) {
    const left = gradientColor(gold, y + 0.5);
    const right = gradientColor(gold, y + 1.5);
    for (let channel = 0; channel < 3; channel += 1) maxAdjacentDelta = Math.max(maxAdjacentDelta, Math.abs(Math.round(left[channel]) - Math.round(right[channel])));
  }
  assert(maxAdjacentDelta <= 2, `goldBody scanline delta ${maxAdjacentDelta} would band`);
  return { sourceElements: artwork.elements.length, gradients: artwork.gradients.size, scanlineShapes: artwork.shapes.length, parts: Object.keys(artwork.byPart).length, maxAdjacentDelta };
}

if (import.meta.url === `file://${process.argv[1]}`) process.stdout.write(`${JSON.stringify(selfTest(), null, 2)}\n`);
