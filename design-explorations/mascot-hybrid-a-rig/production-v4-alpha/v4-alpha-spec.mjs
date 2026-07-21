import {
  CANVAS,
  FPS,
  ROOT_PIVOT,
  HAIR_PIVOT,
  CANONICAL_PARTS,
  PALETTE,
} from "../rig-spec.mjs";
import { SEMANTIC_UNITS } from "../rig-spec-v2.mjs";

export { CANVAS, FPS, ROOT_PIVOT, HAIR_PIVOT, CANONICAL_PARTS, PALETTE };

export const DISPLAY_NAME = "ScoreKeeper Hero — Victory Lift";
export const DURATION_SECONDS = 3;
export const FRAME_COUNT = 180;
export const TERMINAL_FRAME = FRAME_COUNT - 1;
export const OUTPUT_FPS = 60;

// Canonical cleanup is intentionally narrow and auditable. The handle-hole
// entries are omitted from the art and re-applied as post-transform alpha
// masks so the holes follow their independent handle controls.
export const CLEANUP = Object.freeze({
  leftHole: Object.freeze([18, 152, 156]),
  rightHole: Object.freeze([17, 89, 151]),
  fringeRemoval: Object.freeze([41, 70, 99, 126, 142, 157]),
  shineLocked: Object.freeze([29, 98, 139]),
  retainedStructuralShading: Object.freeze([52, 58, 147, 158]),
  leftHoleMetric: Object.freeze({ x: 49, y: 129, width: 23, height: 40, expectedFinalColorPixels: 920 }),
  rightHoleMetric: Object.freeze({ x: 441, y: 129, width: 24, height: 40, expectedFinalColorPixels: 949 }),
  maxBindDiffPixels: 3011,
});

export const REMOVED_SOURCE_INDICES = Object.freeze([
  ...CLEANUP.leftHole,
  ...CLEANUP.rightHole,
  ...CLEANUP.fringeRemoval,
]);

export const PIVOTS = Object.freeze({
  rig_root: { x: 256, y: 401 },
  cup: { x: 255, y: 245 },
  pedestal: { x: 256, y: 401 },
  handleL: { x: 88, y: 150 },
  handleR: { x: 422, y: 150 },
  hair_cap: HAIR_PIVOT,
  hair_fringe: { x: 254, y: 72 },
  eyeL: { x: 196, y: 147 },
  eyeR: { x: 312, y: 147 },
  mouth: { x: 255, y: 205 },
  shine: { x: 118, y: 81 },
});

const key = (frame, value, easing = "smooth") => [frame, value, easing];
const step = (keys) => ({ keys, interpolation: "step" });

// The performance has five readable beats: anticipation (0–24), launch/turn
// (25–58), expressive apex (59–92), landing/overshoot (93–123), and settle
// (124–179). Every secondary track intentionally has different timing to keep
// the silhouette alive rather than uniformly rigid.
export const TRACKS = Object.freeze({
  rig_root: {
    dx: [key(0, 0), key(16, 1.2, "easeInOut"), key(38, -1.5, "easeOut"), key(64, -3, "easeInOut"), key(93, -1, "easeOut"), key(111, 1, "easeIn"), key(145, 0.35, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(12, 4, "easeIn"), key(25, 0, "easeOut"), key(48, -19, "easeOut"), key(72, -30, "easeInOut"), key(92, -12, "easeIn"), key(101, 6, "easeOut"), key(113, -2, "easeOut"), key(135, 2, "easeIn"), key(158, 0.7, "easeIn"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(18, -1.1, "easeIn"), key(42, 2.4, "easeOut"), key(67, 2.9, "easeInOut"), key(90, -2.2, "easeOut"), key(104, 1.5, "easeOut"), key(125, -0.5, "easeIn"), key(152, 0.2, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(12, 1.018, "easeIn"), key(25, 0.972, "easeOut"), key(48, 1.03, "easeOut"), key(72, 1.012, "easeInOut"), key(101, 1.055, "easeOut"), key(113, 0.983, "easeOut"), key(135, 1.012, "easeIn"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(12, 0.968, "easeIn"), key(25, 1.035, "easeOut"), key(48, 0.968, "easeOut"), key(72, 0.988, "easeInOut"), key(101, 0.94, "easeOut"), key(113, 1.02, "easeOut"), key(135, 0.994, "easeIn"), key(179, 1, "easeIn")],
  },
  cup: {
    dx: [key(0, 0), key(28, 0), key(53, 1.8, "easeOut"), key(83, -1.5, "easeIn"), key(105, 0.6, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(32, 0.5), key(58, -2.4, "easeOut"), key(88, 1.5, "easeIn"), key(108, -0.5, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(34, -1, "easeOut"), key(62, 2.6, "easeOut"), key(89, -1.8, "easeIn"), key(111, 0.8, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(25, 1), key(55, 1.014, "easeOut"), key(86, 0.992, "easeIn"), key(105, 1.006, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(25, 1), key(55, 0.986, "easeOut"), key(86, 1.01, "easeIn"), key(105, 0.997, "easeOut"), key(179, 1, "easeIn")],
  },
  pedestal: {
    dx: [key(0, 0), key(42, 0), key(58, 1.65, "easeOut"), key(88, -1.35, "easeIn"), key(108, 0.5, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(32, 0.35, "easeIn"), key(58, -2.15, "easeOut"), key(88, 1.3, "easeIn"), key(108, -0.45, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(42, -0.2, "easeOut"), key(62, 2.35, "easeOut"), key(89, -1.65, "easeIn"), key(111, 0.7, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(25, 1.001, "easeIn"), key(55, 1.012, "easeOut"), key(86, 0.994, "easeIn"), key(105, 1.005, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(25, 0.999, "easeIn"), key(55, 0.988, "easeOut"), key(86, 1.008, "easeIn"), key(105, 0.998, "easeOut"), key(179, 1, "easeIn")],
  },
  handleL: {
    dx: [key(0, 0), key(28, -0.45, "easeOut"), key(55, 0.7, "easeOut"), key(82, -0.35, "easeIn"), key(108, 0.2, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(34, -0.4, "easeOut"), key(62, 0.6, "easeIn"), key(93, -0.3, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(22, -1.4, "easeIn"), key(48, 2.4, "easeOut"), key(72, -1.8, "easeIn"), key(96, 1.2, "easeOut"), key(122, -0.55, "easeIn"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(48, 1.025, "easeOut"), key(72, 0.985, "easeIn"), key(122, 1.008, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(48, 0.985, "easeOut"), key(72, 1.018, "easeIn"), key(122, 0.997, "easeOut"), key(179, 1, "easeIn")],
  },
  handleR: {
    dx: [key(0, 0), key(34, 0.4, "easeOut"), key(60, -0.7, "easeOut"), key(86, 0.35, "easeIn"), key(114, -0.2, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(38, -0.3, "easeOut"), key(68, 0.7, "easeIn"), key(97, -0.25, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(28, 1.5, "easeIn"), key(54, -2.5, "easeOut"), key(78, 1.7, "easeIn"), key(103, -1.1, "easeOut"), key(130, 0.6, "easeIn"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(54, 1.02, "easeOut"), key(78, 0.986, "easeIn"), key(130, 1.007, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(54, 0.986, "easeOut"), key(78, 1.02, "easeIn"), key(130, 0.998, "easeOut"), key(179, 1, "easeIn")],
  },
  hair_cap: {
    dx: [key(0, 0), key(42, -2, "easeOut"), key(69, 3.5, "easeOut"), key(96, -2.5, "easeIn"), key(125, 1.2, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(45, 1, "easeOut"), key(73, -2.5, "easeIn"), key(102, 1.4, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(34, -2.5, "easeOut"), key(62, 3.5, "easeOut"), key(91, -3.1, "easeIn"), key(122, 1.8, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(65, 1.035, "easeOut"), key(94, 0.98, "easeIn"), key(130, 1.01, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(65, 0.968, "easeOut"), key(94, 1.025, "easeIn"), key(130, 0.994, "easeOut"), key(179, 1, "easeIn")],
  },
  hair_fringe: {
    dx: [key(0, 0), key(48, -3, "easeOut"), key(77, 4.5, "easeOut"), key(108, -2.7, "easeIn"), key(139, 1.2, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(51, 1.4, "easeOut"), key(81, -3, "easeIn"), key(113, 1.7, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(40, -3.8, "easeOut"), key(70, 5, "easeOut"), key(101, -4.5, "easeIn"), key(134, 2.6, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(72, 1.05, "easeOut"), key(105, 0.975, "easeIn"), key(141, 1.01, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(72, 0.96, "easeOut"), key(105, 1.03, "easeIn"), key(141, 0.995, "easeOut"), key(179, 1, "easeIn")],
  },
  eyeL: {
    dx: [key(0, 0), key(54, 1, "easeOut"), key(90, -1.5, "easeIn"), key(132, 0.8, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(54, -1, "easeOut"), key(90, 1.2, "easeIn"), key(132, -0.5, "easeOut"), key(179, 0, "easeIn")],
    scaleY: step([key(0, 1), key(64, 1), key(67, 0.1), key(72, 0.1), key(75, 1), key(126, 1), key(129, 0.1), key(134, 0.1), key(137, 1), key(179, 1)]),
  },
  eyeR: {
    dx: [key(0, 0), key(54, 1, "easeOut"), key(90, -1.5, "easeIn"), key(132, 0.8, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(54, -1, "easeOut"), key(90, 1.2, "easeIn"), key(132, -0.5, "easeOut"), key(179, 0, "easeIn")],
    scaleY: step([key(0, 1), key(69, 1), key(72, 0.1), key(77, 0.1), key(80, 1), key(131, 1), key(134, 0.1), key(139, 0.1), key(142, 1), key(179, 1)]),
  },
  mouth: {
    dx: [key(0, 0), key(55, 1.2, "easeOut"), key(91, -1.2, "easeIn"), key(132, 0.5, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(58, -1.5, "easeOut"), key(92, 1.1, "easeIn"), key(132, -0.5, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(55, 1.12, "easeOut"), key(91, 0.92, "easeIn"), key(132, 1.05, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(55, 1.18, "easeOut"), key(91, 0.9, "easeIn"), key(132, 1.08, "easeOut"), key(179, 1, "easeIn")],
  },
  shine: {
    dx: [key(0, 0), key(58, 2, "easeOut"), key(80, -1.5, "easeIn"), key(108, 1, "easeOut"), key(179, 0, "easeIn")],
    dy: [key(0, 0), key(58, -2, "easeOut"), key(80, 1, "easeIn"), key(108, -0.5, "easeOut"), key(179, 0, "easeIn")],
    rotationDeg: [key(0, 0), key(62, 6, "easeOut"), key(83, -5, "easeIn"), key(110, 2, "easeOut"), key(179, 0, "easeIn")],
    scaleX: [key(0, 1), key(62, 1.12, "easeOut"), key(83, 0.92, "easeIn"), key(110, 1.05, "easeOut"), key(179, 1, "easeIn")],
    scaleY: [key(0, 1), key(62, 1.12, "easeOut"), key(83, 0.92, "easeIn"), key(110, 1.05, "easeOut"), key(179, 1, "easeIn")],
    opacity: [key(0, 1), key(60, 1, "easeOut"), key(68, 0.7, "easeIn"), key(83, 1, "easeOut"), key(110, 0.86, "easeIn"), key(179, 1, "easeIn")],
  },
});

export const CONTROL_NAMES = Object.freeze([
  "rig_root", "cup", "pedestal", "handleL", "handleR", "hair_cap", "hair_fringe", "eyeL", "eyeR", "mouth", "shine",
]);

const v2ControlByUnit = new Map(SEMANTIC_UNITS.map((unit) => [unit.id, unit.control]));
export const V2_CONTROL_BY_SOURCE_CONTOUR = Object.freeze(Object.fromEntries(SEMANTIC_UNITS.map((unit) => [
  `${unit.sourceIndex}:${unit.contourIndex}`,
  unit.control,
])));

export function semanticControlFor(sourceIndex, contourIndex) {
  const v2 = v2ControlByUnit.get(`source_${String(sourceIndex).padStart(3, "0")}__contour_${String(contourIndex).padStart(2, "0")}`);
  if (v2 === "rig_handle_l") return "handleL";
  if (v2 === "rig_handle_r") return "handleR";
  if (v2 === "rig_hair") return "hair_cap";
  if (v2 === "rig_hair_fringe") return "hair_fringe";
  // Complete detailed-v2 mapping for all remaining semantic controls. This
  // prevents pedestal/face contours from falling into unrelated animation
  // tracks when a source entry happens to share a legacy index.
  const remaining = {
    rig_base: "pedestal",
    rig_stem: "pedestal",
    rig_eye_l: "eyeL",
    rig_eye_r: "eyeR",
    rig_mouth: "mouth",
    rig_shine: "shine",
    rig_cup: "cup",
    rig_root: "cup",
  };
  return remaining[v2] ?? "cup";
}

export const SOURCE_002_LIMITATION = "source_002 contour1 contains the combined cup+outer-handle silhouette; semantic handle controls animate exact v2 handle contours, while this outer shell contour remains cup-owned.";
