import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const ARTWORK_LOCKED = true;
export const CANVAS = Object.freeze({ width: 512, height: 416 });
export const FPS = 60;
export const RIG_BACKEND = "pivot-fk";

export const ROOT_PIVOT = Object.freeze({ x: 256, y: 401 });
export const HAIR_PIVOT = Object.freeze({ x: 254, y: 89 });
export const HAIR_SOURCE_PATH_INDICES = Object.freeze([5, 28, 50, 137, 164, 175]);
export const HAIR_UNDERLAP_COLOR = "#ffefb944";

export const M = (x, y) => ({ commandType: "moveTo", x, y });
export const L = (x, y) => ({ commandType: "lineTo", x, y });
export const Z = () => ({ commandType: "close" });
export const fill = (color) => ({ paintType: "fill", color });

export function pivot(name, parent, x, y, base = {}) {
  return {
    kind: "pivot",
    name,
    parent,
    x,
    y,
    base: {
      rotation: base.rotation ?? 0,
      scaleX: base.scaleX ?? 1,
      scaleY: base.scaleY ?? 1,
      opacity: base.opacity ?? 1,
    },
  };
}

export function part(name, parent, paths, paints, x = 0, y = 0, base = {}) {
  return { kind: "part", name, parent, x, y, paths, paints, base: { opacity: base.opacity ?? 1 } };
}

function parseCanonicalSvg() {
  const svgPath = fileURLToPath(new URL("./svg/scorekeeper-cup-hybrid-a-canonical.svg", import.meta.url));
  const svg = readFileSync(svgPath, "utf8");
  const pattern = /<path\s+d="([^"]+)"\s+fill="(#[0-9A-Fa-f]{6})"(?:\s+transform="translate\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)")?\s*\/>/g;
  const entries = [];
  let match;
  while ((match = pattern.exec(svg))) {
    const [, d, hex, txRaw = "0", tyRaw = "0"] = match;
    const tx = Number(txRaw);
    const ty = Number(tyRaw);
    const tokens = d.match(/[MLZ]|-?\d+(?:\.\d+)?/g) ?? [];
    const paths = [];
    let commands = [];
    let cursor = 0;
    while (cursor < tokens.length) {
      const token = tokens[cursor++];
      if (token === "M" || token === "L") {
        const x = Number(tokens[cursor++]) + tx;
        const y = Number(tokens[cursor++]) + ty;
        commands.push(token === "M" ? M(x, y) : L(x, y));
      } else if (token === "Z") {
        commands.push(Z());
        paths.push({ name: `contour-${paths.length + 1}`, commands });
        commands = [];
      } else {
        throw new Error(`Unsupported canonical SVG token: ${token}`);
      }
    }
    if (commands.length) throw new Error("Canonical SVG contains an unclosed contour");
    entries.push({
      sourceIndex: entries.length + 1,
      svgColor: hex.toUpperCase(),
      riveColor: `#ff${hex.slice(1).toLowerCase()}`,
      paths,
    });
  }
  if (entries.length !== 181) throw new Error(`Expected 181 canonical SVG paths, found ${entries.length}`);
  return entries;
}

export const CANONICAL_PARTS = Object.freeze(parseCanonicalSvg());
export const PALETTE = Object.freeze([...new Set(CANONICAL_PARTS.map((entry) => entry.svgColor))]);
export const COLORS = Object.freeze(Object.fromEntries(PALETTE.map((color, index) => [`sample_${index + 1}`, color])));
export const RIVE_COLORS = Object.freeze({ transparent: "#00000000" });

const controls = [
  pivot("rig_root", null, ROOT_PIVOT.x, ROOT_PIVOT.y),
  pivot("rig_body", "rig_root", 0, 0),
  pivot("rig_hair", "rig_root", HAIR_PIVOT.x - ROOT_PIVOT.x, HAIR_PIVOT.y - ROOT_PIVOT.y),
];

const bodyParts = CANONICAL_PARTS.filter((entry) => !HAIR_SOURCE_PATH_INDICES.includes(entry.sourceIndex)).map((entry) => part(
  `rig_body__svg_trace_${String(entry.sourceIndex).padStart(3, "0")}`,
  "rig_body",
  entry.paths,
  [fill(entry.riveColor)],
  -ROOT_PIVOT.x,
  -ROOT_PIVOT.y,
));

const underlapPaths = CANONICAL_PARTS
  .filter((entry) => HAIR_SOURCE_PATH_INDICES.includes(entry.sourceIndex))
  .flatMap((entry) => entry.paths);
if (!underlapPaths.length) throw new Error("Hair underlap source paths are missing");
const hairUnderlap = part(
  "rig_body__hair_underlap",
  "rig_body",
  underlapPaths,
  [fill(HAIR_UNDERLAP_COLOR)],
  -ROOT_PIVOT.x,
  -ROOT_PIVOT.y,
  { opacity: 0 },
);

const hairParts = CANONICAL_PARTS.filter((entry) => HAIR_SOURCE_PATH_INDICES.includes(entry.sourceIndex)).map((entry) => {
  const isHair = HAIR_SOURCE_PATH_INDICES.includes(entry.sourceIndex);
  const parent = isHair ? "rig_hair" : "rig_body";
  const prefix = isHair ? "rig_hair" : "rig_body";
  const pivotPoint = isHair ? HAIR_PIVOT : ROOT_PIVOT;
  return part(
    `${prefix}__svg_trace_${String(entry.sourceIndex).padStart(3, "0")}`,
    parent,
    entry.paths,
    [fill(entry.riveColor)],
    -pivotPoint.x,
    -pivotPoint.y,
  );
});

export const NODES = Object.freeze([...controls, ...bodyParts, hairUnderlap, ...hairParts]);
export const PIVOTS = Object.freeze(NODES.filter((node) => node.kind === "pivot"));
export const PARTS = Object.freeze(NODES.filter((node) => node.kind === "part"));
export const BASE_BY_NAME = Object.freeze(Object.fromEntries(NODES.map((node) => [node.name, {
  x: node.x,
  y: node.y,
  rotation: node.base?.rotation ?? 0,
  scaleX: node.base?.scaleX ?? 1,
  scaleY: node.base?.scaleY ?? 1,
  opacity: node.base?.opacity ?? 1,
}])));

export const HAIR_PART_NAMES = Object.freeze(
  PARTS.filter((node) => node.parent === "rig_hair").map((node) => node.name),
);

export const VALIDATION = Object.freeze({
  valid: NODES.length === 185 && PIVOTS.length === 3 && PARTS.length === 182 && HAIR_PART_NAMES.length === 6,
  readyForLive: true,
  backend: RIG_BACKEND,
  nodeCount: NODES.length,
  pivotCount: PIVOTS.length,
  partCount: PARTS.length,
  hairPartCount: HAIR_PART_NAMES.length,
  hiddenUnderlapCount: 1,
});
