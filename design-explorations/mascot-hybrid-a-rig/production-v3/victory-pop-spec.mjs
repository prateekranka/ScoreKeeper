import {
  CANVAS,
  FPS,
  ROOT_PIVOT,
  HAIR_PIVOT,
  CANONICAL_PARTS,
  PALETTE,
} from "../rig-spec.mjs";

export { CANVAS, FPS, ROOT_PIVOT, HAIR_PIVOT, CANONICAL_PARTS, PALETTE };

export const DURATION_SECONDS = 2.6;
export const TERMINAL_FRAME = 156;
export const DISPLAY_NAME = "Victory Pop";
export const ARTWORK_LOCKED = true;
export const UNDERLAP_COLOR = "#EFB944";

const key = (frame, value, easing = "smooth") => [frame, value, easing];
const step = (keys) => ({ keys, interpolation: "step" });

// The root track is copied from the approved Victory Pop timing brief. The
// third tuple item chooses the segment's deliberate asymmetric cubic easing.
export const TRACKS = Object.freeze({
  root: {
    dx: [key(0, 0), key(12, -1, "easeOut"), key(18, -1, "easeOut"), key(24, 0, "easeOut"), key(36, 2, "easeOut"), key(48, 2, "easeIn"), key(58, 1, "easeIn"), key(72, 0, "easeIn"), key(84, -1, "easeOut"), key(90, -1, "easeOut"), key(98, 0, "easeOut"), key(108, 1, "easeIn"), key(120, 0.5, "easeIn"), key(132, 0.2, "easeIn"), key(156, 0, "easeIn")],
    // The approved beat timings are retained, but ascent amplitude is reduced
    // to keep the full canonical silhouette inside the 512x416 hero canvas.
    dy: [key(0, 0, "easeOut"), key(8, 1.5, "easeOut"), key(16, 6, "easeOut"), key(22, 2, "easeOut"), key(34, -2.5, "easeOut"), key(46, -4.5, "easeOut"), key(54, -5, "easeIn"), key(64, -4.75, "easeIn"), key(74, -3.5, "easeIn"), key(84, -1.5, "easeIn"), key(90, 4, "easeOut"), key(96, -0.4, "easeOut"), key(106, 1.5, "easeIn"), key(118, 0.6, "easeIn"), key(132, 0.2, "easeIn"), key(156, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(16, -0.8, "easeOut"), key(24, 0.3, "easeOut"), key(38, 0.8, "easeIn"), key(52, 0, "easeIn"), key(68, -0.5, "easeOut"), key(84, -0.6, "easeOut"), key(90, 0.4, "easeOut"), key(100, 0.1, "easeIn"), key(116, -0.1, "easeIn"), key(156, 0, "easeIn")],
    scaleX: [key(0, 1), key(8, 1.012, "easeOut"), key(16, 1.045, "easeOut"), key(24, 1.015, "easeIn"), key(36, 0.992, "easeIn"), key(52, 0.985, "easeOut"), key(64, 0.997, "easeOut"), key(84, 1.02, "easeOut"), key(90, 1.05, "easeOut"), key(96, 1.025, "easeIn"), key(108, 1.012, "easeIn"), key(120, 1.004, "easeIn"), key(132, 1.001, "easeIn"), key(156, 1, "easeIn")],
    scaleY: [key(0, 1), key(8, 0.988, "easeOut"), key(16, 0.955, "easeOut"), key(24, 0.982, "easeIn"), key(36, 1.008, "easeIn"), key(52, 1.015, "easeOut"), key(64, 1.003, "easeOut"), key(84, 0.98, "easeOut"), key(90, 0.95, "easeOut"), key(96, 0.985, "easeIn"), key(108, 0.992, "easeIn"), key(120, 0.997, "easeIn"), key(132, 0.999, "easeIn"), key(156, 1, "easeIn")],
  },
  // Secondary motion stays deliberately conservative so cup/pedestal seams
  // remain invisible while the root carries the large ballistic arc.
  cup: {
    dx: [key(0, 0), key(156, 0, "easeIn")],
    dy: [key(0, 0), key(156, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(156, 0, "easeIn")],
  },
  pedestal: {
    dx: [key(0, 0), key(156, 0, "easeIn")],
    dy: [key(0, 0), key(156, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(156, 0, "easeIn")],
  },
  hairCap: {
    dx: step([key(0, 0), key(30, 0), key(40, -1), key(56, 1), key(76, 0), key(92, -1), key(110, 0), key(132, 0), key(156, 0)]),
    dy: step([key(0, 0), key(30, 0), key(40, 1), key(56, -1), key(76, 0), key(92, 0), key(110, 0), key(132, 0), key(156, 0)]),
    rotationDeg: [key(0, 0), key(18, 0, "easeOut"), key(34, -4.5, "easeOut"), key(54, 5.5, "easeIn"), key(74, 2.5, "easeIn"), key(90, -4, "easeOut"), key(108, 1, "easeIn"), key(132, 0, "easeIn"), key(156, 0, "easeIn")],
  },
  hairFringe: {
    dx: step([key(0, 0), key(32, 0), key(42, -1), key(58, 1), key(78, 0), key(94, -1), key(112, 0), key(134, 0), key(156, 0)]),
    dy: step([key(0, 0), key(32, 0), key(42, 1), key(58, -1), key(78, 0), key(94, 0), key(112, 0), key(134, 0), key(156, 0)]),
    rotationDeg: [key(0, 0), key(20, 0, "easeOut"), key(36, -3.8, "easeOut"), key(56, 4.6, "easeIn"), key(76, 2, "easeIn"), key(92, -3.2, "easeOut"), key(110, 0.8, "easeIn"), key(134, 0, "easeIn"), key(156, 0, "easeIn")],
  },
  eyeL: {
    dx: step([key(0, 0), key(34, 0), key(56, 1), key(76, 0), key(94, -1), key(116, 0), key(156, 0)]),
    dy: step([key(0, 0), key(34, 0), key(56, -1), key(76, 0), key(94, 0), key(116, 0), key(156, 0)]),
    scaleY: step([key(0, 1), key(49, 1), key(50, 0.12), key(53, 0.12), key(54, 1), key(81, 1), key(82, 0.12), key(85, 0.12), key(86, 1), key(156, 1)]),
  },
  eyeR: {
    dx: step([key(0, 0), key(34, 0), key(56, 1), key(76, 0), key(94, -1), key(116, 0), key(156, 0)]),
    dy: step([key(0, 0), key(34, 0), key(56, -1), key(76, 0), key(94, 0), key(116, 0), key(156, 0)]),
    scaleY: step([key(0, 1), key(49, 1), key(50, 0.12), key(53, 0.12), key(54, 1), key(81, 1), key(82, 0.12), key(85, 0.12), key(86, 1), key(156, 1)]),
  },
  mouth: {
    dx: step([key(0, 0), key(34, 0), key(56, 1), key(76, 0), key(94, -1), key(116, 0), key(156, 0)]),
    dy: step([key(0, 0), key(34, 0), key(56, -1), key(76, 0), key(94, 0), key(116, 0), key(156, 0)]),
  },
  shine: {
    dx: step([key(0, 0), key(38, 0), key(52, 1), key(68, 0), key(88, -1), key(110, 0), key(156, 0)]),
    dy: step([key(0, 0), key(38, 0), key(52, -1), key(68, 0), key(88, 0), key(110, 0), key(156, 0)]),
    scaleX: [key(0, 1), key(42, 1, "easeOut"), key(54, 1.035, "easeOut"), key(66, 1, "easeIn"), key(156, 1, "easeIn")],
    scaleY: [key(0, 1), key(42, 1, "easeOut"), key(54, 1.035, "easeOut"), key(66, 1, "easeIn"), key(156, 1, "easeIn")],
  },
});

export const SOURCE_GROUPS = Object.freeze({
  cup: [1,2,8,9,10,11,15,17,18,20,23,25,26,30,34,41,42,43,44,45,47,49,52,53,55,56,57,58,59,62,63,65,66,67,68,69,70,72,73,74,75,76,78,81,86,88,89,91,92,94,97,99,100,101,102,103,107,108,110,112,115,116,117,118,122,126,129,130,132,133,134,135,136,140,142,144,145,147,149,151,152,153,156,157,158,160,161,162,163,166,171,172,178,179],
  pedestal: [3,4,6,7,16,19,21,27,31,33,35,36,38,39,40,46,51,54,60,61,71,77,79,82,93,95,96,104,105,106,109,113,119,120,123,124,125,127,128,131,138,141,146,148,150,159,165,168,173,174,176,177,180],
  hair: [5,28,50,137,164,175],
  face: [12,13,14,22,24,32,37,48,64,80,83,84,85,87,90,111,114,121,143,154,155,167,169,170,181],
  shine: [29,98,139],
});

export const PATH1_SPECIAL = Object.freeze({
  1: "cup",
  2: "shine",
  3: "eyeL",
  4: "eyeR",
  5: "mouth",
});

const sourceGroup = new Map();
for (const [owner, indices] of Object.entries(SOURCE_GROUPS)) for (const index of indices) sourceGroup.set(index, owner);

export function ownerFor(sourceIndex, contourIndex = 1) {
  if (sourceIndex === 1) return PATH1_SPECIAL[contourIndex] ?? "cup";
  if (sourceGroup.get(sourceIndex) === "face") {
    if ([13, 80, 90].includes(sourceIndex)) return "eyeR";
    if ([14, 114, 154, 155, 167, 169].includes(sourceIndex)) return "eyeL";
    return "mouth";
  }
  if (sourceGroup.get(sourceIndex) === "shine") return "shine";
  return sourceGroup.get(sourceIndex);
}

const coverage = new Set(Object.values(SOURCE_GROUPS).flat());
export const OWNERSHIP_VALIDATION = Object.freeze({
  sourceEntryCount: CANONICAL_PARTS.length,
  expectedSourceEntryCount: 181,
  sourceEntriesCoveredExactlyOnce: coverage.size === 181 && [...coverage].every((index) => index >= 1 && index <= 181),
  missingSourceEntries: [...Array(181).keys()].slice(1).filter((index) => !coverage.has(index)),
  duplicateSourceEntries: [],
  path1SpecialContourCount: Object.keys(PATH1_SPECIAL).length,
  hairSourceIndices: SOURCE_GROUPS.hair,
  canonicalPaletteCount: PALETTE.length,
});

if (!OWNERSHIP_VALIDATION.sourceEntriesCoveredExactlyOnce) {
  throw new Error(`Invalid source ownership: ${JSON.stringify(OWNERSHIP_VALIDATION)}`);
}
