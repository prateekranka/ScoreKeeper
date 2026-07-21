import {
  CANVAS,
  CANONICAL_PARTS,
  HAIR_SOURCE_PATH_INDICES,
} from "./rig-spec.mjs";

export { CANVAS, CANONICAL_PARTS };

export const ARTWORK_LOCKED = true;
export const RIG_VERSION = "detailed-v2-preview";
export const FPS = 30;

export const PIVOTS = Object.freeze({
  rig_root: { x: 256, y: 401 },
  rig_base: { x: 256, y: 401 },
  rig_stem: { x: 255, y: 325 },
  rig_cup: { x: 255, y: 245 },
  rig_handle_l: { x: 88, y: 150 },
  rig_handle_r: { x: 422, y: 150 },
  rig_eye_l: { x: 196, y: 147 },
  rig_eye_r: { x: 312, y: 147 },
  rig_mouth: { x: 255, y: 205 },
  rig_shine: { x: 118, y: 81 },
  rig_hair: { x: 254, y: 89 },
  rig_hair_fringe: { x: 254, y: 72 },
});

export const CONTROL_PARENT = Object.freeze({
  rig_root: null,
  rig_base: "rig_root",
  rig_stem: "rig_root",
  rig_cup: "rig_root",
  rig_handle_l: "rig_cup",
  rig_handle_r: "rig_cup",
  rig_eye_l: "rig_cup",
  rig_eye_r: "rig_cup",
  rig_mouth: "rig_cup",
  rig_shine: "rig_cup",
  rig_hair: "rig_cup",
  rig_hair_fringe: "rig_hair",
});

const HAIR_INDICES = new Set(HAIR_SOURCE_PATH_INDICES);

function commandPoints(contour) {
  return contour.commands.filter((command) => command.commandType !== "close");
}

function boundsFor(contour) {
  const points = commandPoints(contour);
  return Object.freeze({
    minX: Math.min(...points.map((point) => point.x)),
    minY: Math.min(...points.map((point) => point.y)),
    maxX: Math.max(...points.map((point) => point.x)),
    maxY: Math.max(...points.map((point) => point.y)),
  });
}

function inside(bounds, region) {
  return bounds.minX >= region.minX
    && bounds.minY >= region.minY
    && bounds.maxX <= region.maxX
    && bounds.maxY <= region.maxY;
}

const REGIONS = Object.freeze({
  shine: { minX: 100, minY: 65, maxX: 132, maxY: 96 },
  eyeL: { minX: 170, minY: 122, maxX: 222, maxY: 173 },
  eyeR: { minX: 286, minY: 122, maxX: 337, maxY: 173 },
  mouth: { minX: 172, minY: 180, maxX: 338, maxY: 230 },
});

function classifyUnit(sourceIndex, bounds) {
  if (sourceIndex === 164 || sourceIndex === 175) return "rig_hair_fringe";
  if (HAIR_INDICES.has(sourceIndex)) return "rig_hair";
  if (inside(bounds, REGIONS.shine)) return "rig_shine";
  if (inside(bounds, REGIONS.eyeL)) return "rig_eye_l";
  if (inside(bounds, REGIONS.eyeR)) return "rig_eye_r";
  if (inside(bounds, REGIONS.mouth)) return "rig_mouth";
  if (bounds.minY >= 324) return "rig_base";
  if (bounds.minY >= 258 && bounds.maxY <= 331) return "rig_stem";
  if (bounds.maxX <= 100 && bounds.minY < 265) return "rig_handle_l";
  if (bounds.minX >= 412 && bounds.minY < 265) return "rig_handle_r";
  return "rig_cup";
}

export const SEMANTIC_UNITS = Object.freeze(CANONICAL_PARTS.flatMap((entry) => entry.paths.map((contour, contourOffset) => {
  const bounds = boundsFor(contour);
  return Object.freeze({
    id: `source_${String(entry.sourceIndex).padStart(3, "0")}__contour_${String(contourOffset + 1).padStart(2, "0")}`,
    sourceIndex: entry.sourceIndex,
    contourIndex: contourOffset + 1,
    fill: entry.svgColor,
    contour,
    bounds,
    control: classifyUnit(entry.sourceIndex, bounds),
  });
})));

export const CONTROL_UNITS = Object.freeze(Object.fromEntries(Object.keys(PIVOTS).map((control) => [
  control,
  Object.freeze(SEMANTIC_UNITS.filter((unit) => unit.control === control)),
])));

export const CONTROL_COUNTS = Object.freeze(Object.fromEntries(Object.entries(CONTROL_UNITS).map(([control, units]) => [control, units.length])));

const unitIds = new Set(SEMANTIC_UNITS.map((unit) => unit.id));
const expectedUnitCount = CANONICAL_PARTS.reduce((sum, entry) => sum + entry.paths.length, 0);

export const VALIDATION = Object.freeze({
  valid: SEMANTIC_UNITS.length === expectedUnitCount
    && unitIds.size === expectedUnitCount
    && Object.entries(CONTROL_COUNTS).filter(([control]) => control !== "rig_root").every(([, count]) => count > 0),
  canonicalSourcePathCount: CANONICAL_PARTS.length,
  canonicalContourCount: expectedUnitCount,
  semanticUnitCount: SEMANTIC_UNITS.length,
  controlCounts: CONTROL_COUNTS,
  artworkLocked: ARTWORK_LOCKED,
});

if (!VALIDATION.valid) {
  throw new Error(`Detailed v2 rig classification is invalid: ${JSON.stringify(VALIDATION)}`);
}
