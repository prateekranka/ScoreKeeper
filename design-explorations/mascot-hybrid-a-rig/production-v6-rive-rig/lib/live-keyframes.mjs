import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const DEFAULT_INPUT = path.join(ROOT, 'live-keyframes.json');
export const DEFAULT_OUTPUT = path.join(ROOT, 'proofs');
export const REQUIRED_SLUGS = [
  'idle_breathe_blink',
  'hair_bounce',
  'victory_pop',
  'curious_tilt',
  'celebrate_shimmy',
];
export const SCHEMA_ID = 'scorekeeper.rive-live-keyframes/v1';
export const APPROVED_SOURCE_RELATIVE = '../production-v5-vector-master/canonical-dimensional-pixel.svg';
export const APPROVED_SOURCE_SHA256 = '52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75';
export const DEFAULT_CANVAS = { width: 512, height: 416 };
export const DEFAULT_FPS = 30;
export const SEMANTIC_PART_INDICES = Object.freeze({
  tab: [0, 1],
  cup: [2, 3, 20, 21, 22, 23, 24, 25, 29, 30, 31, 32],
  handle_l: [4, 5, 6, 7, 8, 9, 10, 11],
  handle_r: [12, 13, 14, 15, 16, 17, 18, 19],
  hair: [26],
  badge: [27, 28],
  eye_l: [33],
  eye_r: [34],
  mouth: [35, 36, 37],
  stem: [38, 39, 40, 41],
  base: [42, 43, 44, 45, 46, 47],
});
export const SOURCE_ELEMENT_COUNT = 48;
export const ALLOWED_INTERPOLATIONS = new Set(['linear', 'hold', 'cubic']);
export const ALLOWED_PROPERTIES = new Set([
  'x',
  'y',
  'dx',
  'dy',
  'rotationDeg',
  'scaleX',
  'scaleY',
  'opacity',
]);

const IDENTITY = [1, 0, 0, 1, 0, 0];
const finite = (value) => typeof value === 'number' && Number.isFinite(value);
const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

export function sha256File(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

export function fail(message) {
  throw new Error(`LIVE_KEYFRAMES_INVALID ${message}`);
}

function number(value, label) {
  const result = Number(value);
  if (!Number.isFinite(result)) fail(`${label} must be finite; got ${JSON.stringify(value)}`);
  return result;
}

function integer(value, label, minimum = 0) {
  const result = Number(value);
  if (!Number.isInteger(result) || result < minimum) fail(`${label} must be an integer >= ${minimum}; got ${JSON.stringify(value)}`);
  return result;
}

function optionalString(value, label) {
  if (value == null) return undefined;
  if (typeof value !== 'string' || !value.trim()) fail(`${label} must be a non-empty string`);
  return value;
}

function normalizeSource(rawSource) {
  if (!isObject(rawSource)) fail('source is required and must be an object');
  const sourcePath = optionalString(rawSource.path, 'source.path');
  const sourceHash = optionalString(rawSource.sha256, 'source.sha256');
  if (!sourcePath || !sourceHash) fail('source.path and source.sha256 are required');
  if (!/^[a-f0-9]{64}$/.test(sourceHash)) fail('source.sha256 must be a 64-character lowercase hex digest');

  const resolvedPath = path.resolve(ROOT, sourcePath);
  const approvedPath = path.resolve(ROOT, APPROVED_SOURCE_RELATIVE);
  if (resolvedPath !== approvedPath) {
    fail(`source.path must resolve to approved SVG ${APPROVED_SOURCE_RELATIVE}; got ${sourcePath}`);
  }
  if (!fs.existsSync(resolvedPath)) fail(`approved source SVG is missing: ${resolvedPath}`);
  const actualHash = sha256File(resolvedPath);
  if (sourceHash !== APPROVED_SOURCE_SHA256 || actualHash !== APPROVED_SOURCE_SHA256 || sourceHash !== actualHash) {
    fail(`source SHA-256 mismatch; expected ${APPROVED_SOURCE_SHA256}, declared ${sourceHash}, actual ${actualHash}`);
  }
  return { path: sourcePath, resolvedPath, sha256: sourceHash };
}

function normalizeCanvas(rawCanvas) {
  if (!isObject(rawCanvas)) fail('canvas is required and must be an object');
  const width = integer(rawCanvas.width, 'canvas.width', 1);
  const height = integer(rawCanvas.height, 'canvas.height', 1);
  if (width !== DEFAULT_CANVAS.width || height !== DEFAULT_CANVAS.height) {
    fail(`canvas must be ${DEFAULT_CANVAS.width}x${DEFAULT_CANVAS.height} to match the approved SVG`);
  }
  return { width, height };
}

function normalizePivot(rawPivot, label) {
  if (rawPivot == null) return { x: 0, y: 0 };
  if (!isObject(rawPivot)) fail(`${label} must be an object with x and y`);
  return { x: number(rawPivot.x, `${label}.x`), y: number(rawPivot.y, `${label}.y`) };
}

function normalizeTransform(rawTransform, label) {
  if (rawTransform == null) rawTransform = {};
  if (!isObject(rawTransform)) fail(`${label} must be an object`);
  // Rive exports may spell the local translation as x/y or translationX/Y.
  const x = number(rawTransform.x ?? rawTransform.translationX ?? 0, `${label}.x`);
  const y = number(rawTransform.y ?? rawTransform.translationY ?? 0, `${label}.y`);
  const rotationDeg = number(rawTransform.rotationDeg ?? rawTransform.rotation ?? 0, `${label}.rotationDeg`);
  const scaleX = number(rawTransform.scaleX ?? 1, `${label}.scaleX`);
  const scaleY = number(rawTransform.scaleY ?? 1, `${label}.scaleY`);
  const opacity = number(rawTransform.opacity ?? 1, `${label}.opacity`);
  if (scaleX === 0 || scaleY === 0) fail(`${label}.scaleX/scaleY may not be zero`);
  if (opacity < 0 || opacity > 1) fail(`${label}.opacity must be between 0 and 1`);
  return {
    x,
    y,
    rotationDeg,
    scaleX,
    scaleY,
    opacity,
    pivot: normalizePivot(rawTransform.pivot ?? { x: rawTransform.pivotX ?? 0, y: rawTransform.pivotY ?? 0 }, `${label}.pivot`),
  };
}

function normalizeNode(rawNode, index) {
  if (!isObject(rawNode)) fail(`nodes[${index}] must be an object`);
  const name = optionalString(rawNode.name, `nodes[${index}].name`);
  if (!name) fail(`nodes[${index}].name is required`);
  const parent = rawNode.parent == null ? null : optionalString(rawNode.parent, `${name}.parent`);
  const kind = rawNode.kind ?? (rawNode.source ? 'asset' : 'pivot');
  if (kind !== 'pivot' && kind !== 'nestedArtboard' && kind !== 'asset') fail(`${name}.kind must be pivot, nestedArtboard, or asset`);
  if (kind === 'asset' && rawNode.source !== 'canonical-svg') fail(`${name}.source must be canonical-svg`);
  let semanticPart;
  let sourceElementIndices;
  if (kind === 'asset') {
    semanticPart = optionalString(rawNode.semanticPart, `${name}.semanticPart`);
    const providedIndices = rawNode.sourceElementIndices;
    if (providedIndices != null) {
      if (!Array.isArray(providedIndices) || providedIndices.length === 0) fail(`${name}.sourceElementIndices must be a non-empty array`);
      sourceElementIndices = providedIndices.map((value, valueIndex) => integer(value, `${name}.sourceElementIndices[${valueIndex}]`, 0));
    }
    if (!semanticPart && sourceElementIndices) {
      semanticPart = Object.keys(SEMANTIC_PART_INDICES).find((part) => JSON.stringify(SEMANTIC_PART_INDICES[part]) === JSON.stringify(sourceElementIndices));
    }
    if (!semanticPart || !Object.hasOwn(SEMANTIC_PART_INDICES, semanticPart)) {
      fail(`${name} must declare one of semanticPart ${Object.keys(SEMANTIC_PART_INDICES).join(', ')}`);
    }
    const expectedIndices = SEMANTIC_PART_INDICES[semanticPart];
    if (sourceElementIndices && JSON.stringify(sourceElementIndices) !== JSON.stringify(expectedIndices)) {
      fail(`${name}.sourceElementIndices do not match semanticPart ${semanticPart}`);
    }
    sourceElementIndices = expectedIndices;
  }
  return {
    name,
    parent,
    kind,
    source: kind === 'asset' ? 'canonical-svg' : undefined,
    semanticPart,
    sourceElementIndices,
    transform: normalizeTransform(rawNode.transform, `${name}.transform`),
  };
}

function normalizeInterpolation(rawKeyframe, label) {
  if (!isObject(rawKeyframe)) return 'linear';
  const interpolation = String(rawKeyframe.interpolation ?? rawKeyframe.easing ?? 'linear').toLowerCase();
  if (!ALLOWED_INTERPOLATIONS.has(interpolation)) fail(`${label}.interpolation must be one of linear, hold, cubic`);
  return interpolation;
}

function normalizeCurve(rawKeyframe, label) {
  if (!isObject(rawKeyframe)) return { x1: 0.25, y1: 0.1, x2: 0.25, y2: 1 };
  const rawCurve = rawKeyframe.curve ?? rawKeyframe.bezier;
  if (rawCurve == null) return { x1: 0.25, y1: 0.1, x2: 0.25, y2: 1 };
  let curve;
  if (Array.isArray(rawCurve) && rawCurve.length === 4) {
    curve = {
      x1: number(rawCurve[0], `${label}.curve[0]`),
      y1: number(rawCurve[1], `${label}.curve[1]`),
      x2: number(rawCurve[2], `${label}.curve[2]`),
      y2: number(rawCurve[3], `${label}.curve[3]`),
    };
  } else {
    if (!isObject(rawCurve)) fail(`${label}.curve must be [x1,y1,x2,y2] or an object`);
    curve = {
      x1: number(rawCurve.x1, `${label}.curve.x1`),
      y1: number(rawCurve.y1, `${label}.curve.y1`),
      x2: number(rawCurve.x2, `${label}.curve.x2`),
      y2: number(rawCurve.y2, `${label}.curve.y2`),
    };
  }
  if (curve.x1 < 0 || curve.x1 > 1 || curve.x2 < 0 || curve.x2 > 1) {
    fail(`${label}.curve x controls must be in [0,1] for monotonic cubic interpolation`);
  }
  return curve;
}

function normalizeKeyframe(rawKeyframe, index, label) {
  let frame;
  let value;
  let metadata = rawKeyframe;
  if (Array.isArray(rawKeyframe)) {
    if (rawKeyframe.length < 2) fail(`${label}[${index}] must contain [frame, value]`);
    [frame, value] = rawKeyframe;
    metadata = {};
  } else if (isObject(rawKeyframe)) {
    frame = rawKeyframe.frame ?? rawKeyframe.time;
    value = rawKeyframe.value;
  } else {
    fail(`${label}[${index}] must be an object or [frame,value]`);
  }
  return {
    frame: integer(frame, `${label}[${index}].frame`, 0),
    value: number(value, `${label}[${index}].value`),
    interpolation: normalizeInterpolation(metadata, `${label}[${index}]`),
    curve: normalizeCurve(metadata, `${label}[${index}]`),
  };
}

function normalizeTrack(rawTrack, label, durationFrames) {
  if (rawTrack == null) return [];
  const values = Array.isArray(rawTrack) ? rawTrack : [rawTrack];
  const normalized = values.map((value, index) => normalizeKeyframe(value, index, label));
  normalized.sort((a, b) => a.frame - b.frame);
  for (let index = 0; index < normalized.length; index += 1) {
    const keyframe = normalized[index];
    if (keyframe.frame > durationFrames) fail(`${label}[${index}].frame ${keyframe.frame} exceeds durationFrames ${durationFrames}`);
    if (index > 0 && keyframe.frame === normalized[index - 1].frame) fail(`${label} contains duplicate frame ${keyframe.frame}`);
  }
  return normalized;
}

function normalizeAnimation(rawAnimation, slug, nodeNames) {
  if (!isObject(rawAnimation)) fail(`animations.${slug} must be an object`);
  const durationFrames = integer(rawAnimation.durationFrames, `animations.${slug}.durationFrames`, 1);
  const tracks = rawAnimation.tracks;
  if (!isObject(tracks)) fail(`animations.${slug}.tracks is required and must be an object`);
  const normalizedTracks = {};
  for (const [nodeName, rawNodeTracks] of Object.entries(tracks)) {
    if (!nodeNames.has(nodeName)) fail(`animations.${slug} targets unknown node ${nodeName}`);
    if (!isObject(rawNodeTracks)) fail(`animations.${slug}.tracks.${nodeName} must be an object`);
    normalizedTracks[nodeName] = {};
    for (const [property, rawTrack] of Object.entries(rawNodeTracks)) {
      if (!ALLOWED_PROPERTIES.has(property)) fail(`animations.${slug} has unsupported property ${nodeName}.${property}`);
      normalizedTracks[nodeName][property] = normalizeTrack(rawTrack, `animations.${slug}.tracks.${nodeName}.${property}`, durationFrames);
    }
    if (normalizedTracks[nodeName].x && normalizedTracks[nodeName].dx) fail(`animations.${slug}.tracks.${nodeName} may use x or dx, not both`);
    if (normalizedTracks[nodeName].y && normalizedTracks[nodeName].dy) fail(`animations.${slug}.tracks.${nodeName} may use y or dy, not both`);
  }
  if (rawAnimation.contactFrames != null && !Array.isArray(rawAnimation.contactFrames)) fail(`animations.${slug}.contactFrames must be an array`);
  const contactFrames = rawAnimation.contactFrames == null ? undefined : rawAnimation.contactFrames.map((frame, index) => integer(frame, `animations.${slug}.contactFrames[${index}]`, 0));
  if (contactFrames?.some((frame) => frame > durationFrames)) fail(`animations.${slug}.contactFrames contains a frame after durationFrames`);
  return {
    slug,
    label: String(rawAnimation.label ?? slug),
    durationFrames,
    loop: Boolean(rawAnimation.loop ?? false),
    tracks: normalizedTracks,
    contactFrames,
  };
}

export function normalizeAndValidate(raw) {
  if (!isObject(raw)) fail('root must be a JSON object');
  if (raw.schema !== SCHEMA_ID) fail(`schema must be ${SCHEMA_ID}`);
  const source = normalizeSource(raw.source);
  const canvas = normalizeCanvas(raw.canvas);
  const fps = integer(raw.fps ?? DEFAULT_FPS, 'fps', 1);
  const artboard = optionalString(raw.artboard, 'artboard');
  if (!artboard) fail('artboard is required');
  if (!Array.isArray(raw.nodes) || raw.nodes.length === 0) fail('nodes must be a non-empty array');
  const nodes = raw.nodes.map(normalizeNode);
  const nodeNames = new Set();
  for (const node of nodes) {
    if (nodeNames.has(node.name)) fail(`duplicate node name ${node.name}`);
    nodeNames.add(node.name);
  }
  const assetNodes = nodes.filter((node) => node.kind === 'asset');
  if (assetNodes.length !== Object.keys(SEMANTIC_PART_INDICES).length) {
    fail(`nodes must contain exactly ${Object.keys(SEMANTIC_PART_INDICES).length} canonical-svg semantic asset nodes; found ${assetNodes.length}`);
  }
  const semanticParts = new Set(assetNodes.map((node) => node.semanticPart));
  if (semanticParts.size !== Object.keys(SEMANTIC_PART_INDICES).length) fail('each canonical-svg semanticPart must be present exactly once');
  if (Object.keys(SEMANTIC_PART_INDICES).some((part) => !semanticParts.has(part))) fail(`missing canonical-svg semanticPart; expected ${Object.keys(SEMANTIC_PART_INDICES).join(', ')}`);
  const coveredIndices = assetNodes.flatMap((node) => node.sourceElementIndices).sort((a, b) => a - b);
  const expectedIndices = Array.from({ length: SOURCE_ELEMENT_COUNT }, (_, value) => value);
  if (JSON.stringify(coveredIndices) !== JSON.stringify(expectedIndices)) fail(`canonical-svg source elements must be covered exactly once in 0…${SOURCE_ELEMENT_COUNT - 1}`);
  for (const node of nodes) {
    if (node.parent !== null && !nodeNames.has(node.parent)) fail(`${node.name}.parent targets unknown node ${node.parent}`);
    if (node.parent === node.name) fail(`${node.name} cannot parent itself`);
  }
  const children = new Map(nodes.map((node) => [node.name, []]));
  for (const node of nodes) if (node.parent) children.get(node.parent).push(node.name);
  const visited = new Set();
  const visit = (name, ancestors = new Set()) => {
    if (ancestors.has(name)) fail(`node hierarchy contains a cycle at ${name}`);
    if (visited.has(name)) return;
    visited.add(name);
    const next = new Set(ancestors).add(name);
    for (const child of children.get(name)) visit(child, next);
  };
  for (const node of nodes.filter((candidate) => candidate.parent === null)) visit(node.name);
  if (visited.size !== nodes.length) fail('node hierarchy must be connected to a root (or contains a cycle)');
  const animationsRaw = raw.animations;
  if (!isObject(animationsRaw)) fail('animations is required and must be an object keyed by slug');
  const animations = {};
  for (const slug of REQUIRED_SLUGS) {
    if (!(slug in animationsRaw)) fail(`required animation ${slug} is missing`);
    animations[slug] = normalizeAnimation(animationsRaw[slug], slug, nodeNames);
  }
  return { schema: raw.schema, source, canvas, fps, artboard, nodes, animations, nodeNames };
}

export function readAndValidate(inputPath = DEFAULT_INPUT) {
  const resolvedInput = path.resolve(inputPath);
  if (!fs.existsSync(resolvedInput)) fail(`input JSON is missing: ${resolvedInput}`);
  let raw;
  try {
    raw = JSON.parse(fs.readFileSync(resolvedInput, 'utf8'));
  } catch (error) {
    fail(`input JSON could not be parsed: ${error.message}`);
  }
  return normalizeAndValidate(raw);
}

export function normalizeKeyframesForTrack(track) {
  return track ?? [];
}

function cubicBezier(t, p1, p2, p3, p4) {
  const one = 1 - t;
  return one ** 3 * p1 + 3 * one ** 2 * t * p2 + 3 * one * t ** 2 * p3 + t ** 3 * p4;
}

function solveCubicProgress(x, curve) {
  const { x1, y1, x2, y2 } = curve;
  let low = 0;
  let high = 1;
  for (let iteration = 0; iteration < 24; iteration += 1) {
    const t = (low + high) / 2;
    const currentX = cubicBezier(t, 0, x1, x2, 1);
    if (currentX < x) low = t;
    else high = t;
  }
  return cubicBezier((low + high) / 2, 0, y1, y2, 1);
}

export function interpolate(track, frame, fallback) {
  if (!track?.length) return fallback;
  if (frame <= track[0].frame) return track[0].value;
  const last = track[track.length - 1];
  if (frame >= last.frame) return last.value;
  let low = 0;
  let high = track.length - 1;
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (track[middle].frame <= frame) low = middle;
    else high = middle;
  }
  const left = track[low];
  const right = track[high];
  const progress = (frame - left.frame) / (right.frame - left.frame);
  // A keyframe declares the interpolation of the outgoing segment. This
  // mirrors Rive timeline semantics and keeps the terminal keyframe inert.
  const mode = left.interpolation ?? 'linear';
  if (mode === 'hold') return left.value;
  const eased = mode === 'cubic' ? solveCubicProgress(progress, left.curve) : progress;
  return left.value + (right.value - left.value) * eased;
}

export function localMatrix(transform) {
  const radians = (transform.rotationDeg * Math.PI) / 180;
  const cosine = Math.cos(radians);
  const sine = Math.sin(radians);
  const sx = transform.scaleX;
  const sy = transform.scaleY;
  const { x: px, y: py } = transform.pivot;
  // Parent-space local transform: T(translation) * T(pivot) * R * S * T(-pivot).
  const rs = [cosine * sx, sine * sx, -sine * sy, cosine * sy, 0, 0];
  const translate = (x, y) => [1, 0, 0, 1, x, y];
  return multiplyMatrices(translate(transform.x, transform.y), multiplyMatrices(translate(px, py), multiplyMatrices(rs, translate(-px, -py))));
}

export function multiplyMatrices(left, right) {
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

export function matrixAttribute(matrix) {
  return `matrix(${matrix.map((value) => Math.round(value * 1e6) / 1e6).join(' ')})`;
}

export function frameState(model, animation, frame) {
  const transforms = new Map();
  const worldMatrices = new Map();
  const worldOpacities = new Map();
  for (const node of model.nodes) {
    const track = animation.tracks[node.name] ?? {};
    const base = node.transform;
    transforms.set(node.name, {
      x: track.x ? interpolate(track.x, frame, base.x) : base.x + interpolate(track.dx, frame, 0),
      y: track.y ? interpolate(track.y, frame, base.y) : base.y + interpolate(track.dy, frame, 0),
      rotationDeg: interpolate(track.rotationDeg, frame, base.rotationDeg),
      scaleX: interpolate(track.scaleX, frame, base.scaleX),
      scaleY: interpolate(track.scaleY, frame, base.scaleY),
      opacity: Math.max(0, Math.min(1, interpolate(track.opacity, frame, base.opacity))),
      pivot: base.pivot,
    });
  }
  const byParent = new Map();
  for (const node of model.nodes) {
    const children = byParent.get(node.parent) ?? [];
    children.push(node);
    byParent.set(node.parent, children);
  }
  const visit = (node, parentMatrix = IDENTITY, parentOpacity = 1) => {
    const local = localMatrix(transforms.get(node.name));
    const world = multiplyMatrices(parentMatrix, local);
    worldMatrices.set(node.name, world);
    worldOpacities.set(node.name, parentOpacity * transforms.get(node.name).opacity);
    for (const child of byParent.get(node.name) ?? []) visit(child, world, worldOpacities.get(node.name));
  };
  for (const root of byParent.get(null) ?? []) visit(root);
  return { transforms, worldMatrices, worldOpacities };
}

export function readSvgInner(sourcePath) {
  const svg = fs.readFileSync(sourcePath, 'utf8');
  const match = svg.match(/<svg\b[^>]*>([\s\S]*)<\/svg>\s*$/i);
  if (!match) fail(`approved SVG does not contain a valid outer <svg>: ${sourcePath}`);
  return match[1].trim();
}

export function readSvgAssetDocument(sourcePath) {
  const inner = readSvgInner(sourcePath);
  const defsMatch = inner.match(/<defs\b[\s\S]*?<\/defs>/i);
  if (!defsMatch) fail(`approved SVG is missing shared <defs>: ${sourcePath}`);
  const elements = [...inner.replace(defsMatch[0], '').matchAll(/<(?:rect|path)\b[^>]*\/\s*>/gi)].map((match) => match[0]);
  if (elements.length !== SOURCE_ELEMENT_COUNT) fail(`approved SVG must contain exactly ${SOURCE_ELEMENT_COUNT} visible rect/path elements; found ${elements.length}`);
  return { defs: defsMatch[0], elements };
}

export function frameSvg(model, animation, frame, sourceDocument) {
  const state = frameState(model, animation, frame);
  const assets = model.nodes.filter((node) => node.kind === 'asset').sort((left, right) => left.sourceElementIndices[0] - right.sourceElementIndices[0]);
  const elementsByIndex = new Map();
  for (const node of assets) {
    for (const sourceIndex of node.sourceElementIndices) elementsByIndex.set(sourceIndex, node);
  }
  // Emit one transformed wrapper per source element, sorted by original source
  // order. This preserves exact z-order even when a semantic part's elements
  // are interleaved with another part in the approved SVG (the cup is).
  const content = Array.from({ length: SOURCE_ELEMENT_COUNT }, (_, sourceIndex) => {
    const node = elementsByIndex.get(sourceIndex);
    const matrix = state.worldMatrices.get(node.name);
    const opacity = Math.round(state.worldOpacities.get(node.name) * 1e6) / 1e6;
    const element = sourceDocument.elements[sourceIndex];
    return `  <g id="${node.name.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}__source_${String(sourceIndex).padStart(3, '0')}" transform="${matrixAttribute(matrix)}" opacity="${opacity}">${element}</g>`;
  }).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${model.canvas.width}" height="${model.canvas.height}" viewBox="0 0 ${model.canvas.width} ${model.canvas.height}">\n  <title>${animation.slug} frame ${frame}</title>\n  <metadata>Live Rive keyframe proof; no offline motion spec.</metadata>\n  ${sourceDocument.defs}\n${content}\n</svg>\n`;
}

export function semanticPartFrameSvg(model, animation, frame, sourceDocument, semanticPart) {
  const state = frameState(model, animation, frame);
  const node = model.nodes.find((candidate) => candidate.kind === 'asset' && candidate.semanticPart === semanticPart);
  if (!node) fail(`semantic part ${semanticPart} is missing from the normalized model`);
  const matrix = state.worldMatrices.get(node.name);
  const opacity = Math.round(state.worldOpacities.get(node.name) * 1e6) / 1e6;
  const content = node.sourceElementIndices.map((sourceIndex) => {
    const element = sourceDocument.elements[sourceIndex];
    return `  <g id="${node.name.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}__source_${String(sourceIndex).padStart(3, '0')}" transform="${matrixAttribute(matrix)}" opacity="${opacity}">${element}</g>`;
  }).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${model.canvas.width}" height="${model.canvas.height}" viewBox="0 0 ${model.canvas.width} ${model.canvas.height}">\n  <title>${animation.slug} frame ${frame} ${semanticPart} alpha proof</title>\n  <metadata>Semantic-layer alpha QA generated from live Rive keyframes.</metadata>\n  ${sourceDocument.defs}\n${content}\n</svg>\n`;
}

export function animationFrames(animation) {
  return Array.from({ length: animation.durationFrames + 1 }, (_, frame) => frame);
}

export function contactFrameNumbers(animation) {
  if (animation.contactFrames?.length) return [...new Set(animation.contactFrames)].sort((a, b) => a - b);
  const terminal = animation.loop ? animation.durationFrames - 1 : animation.durationFrames;
  return [...new Set([0, Math.round(terminal * 0.28), Math.round(terminal * 0.58), terminal])];
}
