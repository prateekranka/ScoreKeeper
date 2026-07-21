import { FPS, PIVOTS } from "./rig-spec-v2.mjs";

const k = (...pairs) => pairs;
const performance = (spec) => Object.freeze({ endpointPolicy: "return-to-bind", ...spec });

const RAW_DETAILED_PERFORMANCE_SPECS = Object.freeze([
  performance({
    slug: "idle_alive",
    displayName: "Idle Alive",
    durationSeconds: 4,
    fps: FPS,
    loop: true,
    semanticPreviewFrames: [0, 30, 44, 68, 94, 120],
    tracks: {
      rig_root: {
        dy: k([0, 0], [30, -1.5], [60, 0], [90, -1.2], [120, 0]),
        rotationDeg: k([0, 0], [30, -0.35], [60, 0], [90, 0.3], [120, 0]),
        scaleX: k([0, 1], [30, 1.003], [60, 1], [90, 1.002], [120, 1]),
        scaleY: k([0, 1], [30, 0.997], [60, 1], [90, 0.998], [120, 1]),
      },
      rig_cup: {
        dy: k([0, 0], [30, -1], [60, 0], [90, -0.8], [120, 0]),
        scaleX: k([0, 1], [30, 1.004], [60, 1], [90, 1.003], [120, 1]),
        scaleY: k([0, 1], [30, 0.996], [60, 1], [90, 0.997], [120, 1]),
      },
      rig_eye_l: {
        dx: k([0, 0], [56, 0], [62, 2], [78, 2], [84, 0], [120, 0]),
        scaleY: k([0, 1], [40, 1], [43, 0.12], [46, 1], [92, 1], [95, 0.12], [98, 1], [120, 1]),
      },
      rig_eye_r: {
        dx: k([0, 0], [58, 0], [64, 2], [80, 2], [86, 0], [120, 0]),
        scaleY: k([0, 1], [41, 1], [44, 0.12], [47, 1], [93, 1], [96, 0.12], [99, 1], [120, 1]),
      },
      rig_mouth: {
        dy: k([0, 0], [30, 0.6], [60, 0], [90, 0.4], [120, 0]),
        scaleX: k([0, 1], [30, 1.015], [60, 1], [90, 1.01], [120, 1]),
      },
      rig_shine: {
        rotationDeg: k([0, 0], [28, -2], [36, 2], [44, 0], [88, -1.5], [96, 1.5], [104, 0], [120, 0]),
        scaleX: k([0, 1], [32, 1.08], [40, 1], [92, 1.06], [100, 1], [120, 1]),
        scaleY: k([0, 1], [32, 1.08], [40, 1], [92, 1.06], [100, 1], [120, 1]),
      },
      rig_hair: {
        rotationDeg: k([0, 0], [34, 1.4], [64, -1], [94, 1.1], [120, 0]),
        dy: k([0, 0], [30, 0.4], [60, 0], [90, 0.3], [120, 0]),
      },
      rig_stem: {
        rotationDeg: k([0, 0], [30, 0.25], [60, 0], [90, -0.2], [120, 0]),
      },
      rig_base: {
        scaleX: k([0, 1], [30, 1.002], [60, 1], [90, 1.002], [120, 1]),
      },
      rig_body__hair_underlap: { opacity: k([0, 0], [3, 1], [117, 1], [120, 0]) },
    },
  }),
  performance({
    slug: "big_celebrate",
    displayName: "Big Celebrate",
    durationSeconds: 3,
    fps: FPS,
    loop: false,
    semanticPreviewFrames: [0, 12, 24, 44, 58, 72, 90],
    tracks: {
      rig_root: {
        dy: k([0, 0], [12, 8], [24, -18], [38, -12], [52, 5], [60, 0], [72, -2], [90, 0]),
        rotationDeg: k([0, 0], [12, -1], [24, 2], [38, -1.5], [52, 0.8], [60, 0], [72, -0.3], [90, 0]),
        scaleX: k([0, 1], [12, 1.06], [24, 0.97], [38, 1.01], [52, 1.045], [60, 0.99], [72, 1.01], [90, 1]),
        scaleY: k([0, 1], [12, 0.92], [24, 1.06], [38, 0.99], [52, 0.94], [60, 1.02], [72, 0.99], [90, 1]),
      },
      rig_cup: {
        dy: k([0, 0], [12, 3], [24, -5], [38, 1], [52, 3], [60, -1], [72, 0], [90, 0]),
        rotationDeg: k([0, 0], [12, 1.5], [24, -3], [38, 2], [52, -1], [60, 0.8], [72, -0.3], [90, 0]),
        scaleX: k([0, 1], [12, 1.025], [24, 0.985], [52, 1.02], [72, 1], [90, 1]),
        scaleY: k([0, 1], [12, 0.97], [24, 1.02], [52, 0.98], [72, 1], [90, 1]),
      },
      rig_handle_l: { rotationDeg: k([0, 0], [12, -2], [24, -7], [38, -4], [52, 2], [64, -1], [90, 0]) },
      rig_handle_r: { rotationDeg: k([0, 0], [12, 2], [24, 7], [38, 4], [52, -2], [64, 1], [90, 0]) },
      rig_eye_l: { scaleY: k([0, 1], [10, 1], [13, 0.15], [16, 1], [48, 1.1], [54, 0.12], [58, 1], [90, 1]) },
      rig_eye_r: { scaleY: k([0, 1], [11, 1], [14, 0.15], [17, 1], [48, 1.1], [55, 0.12], [59, 1], [90, 1]) },
      rig_mouth: {
        dy: k([0, 0], [12, 2], [24, -2], [38, -1], [52, 2], [62, -1], [72, 0], [90, 0]),
        scaleX: k([0, 1], [12, 0.9], [24, 1.12], [38, 1.06], [52, 0.94], [62, 1.04], [72, 1], [90, 1]),
      },
      rig_shine: {
        rotationDeg: k([0, 0], [18, -6], [28, 8], [40, -3], [56, 4], [72, 0], [90, 0]),
        scaleX: k([0, 1], [24, 1.22], [38, 0.95], [56, 1.12], [72, 1], [90, 1]),
        scaleY: k([0, 1], [24, 1.22], [38, 0.95], [56, 1.12], [72, 1], [90, 1]),
      },
      rig_hair: {
        rotationDeg: k([0, 0], [12, 5], [24, -10], [34, 8], [46, -5], [56, 3], [68, -1.5], [90, 0]),
        dy: k([0, 0], [12, 2], [24, -3], [46, 1], [60, 0], [90, 0]),
      },
      rig_stem: { rotationDeg: k([0, 0], [12, 1], [24, -1.8], [40, 1], [56, -0.6], [72, 0], [90, 0]) },
      rig_base: {
        scaleX: k([0, 1], [12, 1.04], [24, 0.99], [52, 1.035], [62, 0.99], [72, 1], [90, 1]),
        scaleY: k([0, 1], [12, 0.96], [24, 1.01], [52, 0.97], [62, 1.01], [72, 1], [90, 1]),
      },
      rig_body__hair_underlap: { opacity: k([0, 0], [2, 1], [87, 1], [90, 0]) },
    },
  }),
  performance({
    slug: "hair_flourish",
    displayName: "Hair Flourish",
    durationSeconds: 3.2,
    fps: FPS,
    loop: false,
    semanticPreviewFrames: [0, 14, 30, 48, 68, 82, 96],
    tracks: {
      rig_root: {
        dy: k([0, 0], [14, 3], [28, -3], [48, 0], [68, -1], [82, 0], [96, 0]),
        rotationDeg: k([0, 0], [14, 1], [28, -1.5], [48, 1], [68, -0.5], [82, 0.2], [96, 0]),
      },
      rig_cup: {
        rotationDeg: k([0, 0], [14, -2], [28, 3], [48, -2], [68, 1], [82, -0.4], [96, 0]),
        scaleY: k([0, 1], [14, 0.98], [28, 1.015], [48, 0.995], [68, 1.005], [96, 1]),
      },
      rig_eye_l: {
        dx: k([0, 0], [18, -2], [34, 2], [52, -1], [72, 1], [88, 0], [96, 0]),
        scaleY: k([0, 1], [8, 1], [11, 0.12], [14, 1], [74, 1], [77, 0.12], [80, 1], [96, 1]),
      },
      rig_eye_r: {
        dx: k([0, 0], [20, -2], [36, 2], [54, -1], [74, 1], [90, 0], [96, 0]),
        scaleY: k([0, 1], [9, 1], [12, 0.12], [15, 1], [75, 1], [78, 0.12], [81, 1], [96, 1]),
      },
      rig_mouth: {
        rotationDeg: k([0, 0], [14, -1.5], [30, 2], [48, -1.2], [68, 0.8], [82, -0.3], [96, 0]),
        scaleX: k([0, 1], [14, 0.94], [30, 1.08], [48, 0.97], [68, 1.04], [82, 1], [96, 1]),
      },
      rig_shine: {
        rotationDeg: k([0, 0], [14, -10], [30, 12], [48, -8], [68, 5], [82, -2], [96, 0]),
        scaleX: k([0, 1], [14, 0.9], [30, 1.2], [48, 0.95], [68, 1.1], [82, 1], [96, 1]),
        scaleY: k([0, 1], [14, 0.9], [30, 1.2], [48, 0.95], [68, 1.1], [82, 1], [96, 1]),
      },
      rig_hair: {
        rotationDeg: k([0, 0], [14, -12], [30, 15], [48, -10], [68, 6], [82, -2.5], [96, 0]),
        dx: k([0, 0], [14, -3], [30, 4], [48, -2], [68, 1.5], [82, -0.5], [96, 0]),
        dy: k([0, 0], [14, 2], [30, -2], [48, 1], [68, -0.5], [96, 0]),
      },
      rig_handle_l: { rotationDeg: k([0, 0], [14, -2], [30, 2.5], [48, -1.5], [68, 0.8], [96, 0]) },
      rig_handle_r: { rotationDeg: k([0, 0], [14, 2], [30, -2.5], [48, 1.5], [68, -0.8], [96, 0]) },
      rig_stem: { rotationDeg: k([0, 0], [14, 0.7], [30, -1], [48, 0.6], [68, -0.3], [96, 0]) },
      rig_body__hair_underlap: { opacity: k([0, 0], [2, 1], [93, 1], [96, 0]) },
    },
  }),
  performance({
    slug: "curious_inspect",
    displayName: "Curious Inspect",
    durationSeconds: 3.4,
    fps: FPS,
    loop: false,
    semanticPreviewFrames: [0, 18, 38, 56, 72, 88, 102],
    tracks: {
      rig_root: {
        dx: k([0, 0], [18, -3], [38, -5], [56, -4], [72, 2], [88, 1], [102, 0]),
        dy: k([0, 0], [18, 2], [38, 1], [56, 2], [72, -1], [88, 0], [102, 0]),
        rotationDeg: k([0, 0], [18, -2], [38, -4.5], [56, -3], [72, 2.5], [88, 0.8], [102, 0]),
      },
      rig_cup: {
        rotationDeg: k([0, 0], [18, -1], [38, -2.5], [56, 1], [72, 2], [88, -0.5], [102, 0]),
        dy: k([0, 0], [18, 1], [38, -1], [56, 0], [72, -1], [88, 0], [102, 0]),
      },
      rig_eye_l: {
        dx: k([0, 0], [14, -2], [34, -3], [48, 3], [66, 3], [82, -1], [96, 0], [102, 0]),
        dy: k([0, 0], [34, 1], [48, -1], [66, -1], [82, 0], [102, 0]),
        scaleY: k([0, 1], [50, 1], [53, 0.1], [57, 1], [102, 1]),
      },
      rig_eye_r: {
        dx: k([0, 0], [16, -2], [36, -3], [50, 3], [68, 3], [84, -1], [98, 0], [102, 0]),
        dy: k([0, 0], [36, 1], [50, -1], [68, -1], [84, 0], [102, 0]),
        scaleY: k([0, 1], [52, 1], [55, 0.1], [59, 1], [102, 1]),
      },
      rig_mouth: {
        rotationDeg: k([0, 0], [18, -2], [38, -3], [56, 2], [72, 2.5], [88, -0.5], [102, 0]),
        scaleX: k([0, 1], [18, 0.94], [38, 0.9], [56, 1.06], [72, 1.1], [88, 0.98], [102, 1]),
        dy: k([0, 0], [38, 1], [56, -1], [72, -1], [88, 0], [102, 0]),
      },
      rig_shine: { rotationDeg: k([0, 0], [18, 3], [38, 7], [56, -4], [72, -5], [88, 1], [102, 0]) },
      rig_hair: {
        rotationDeg: k([0, 0], [18, 4], [38, 7], [56, -3], [72, -5], [88, 2], [102, 0]),
        dx: k([0, 0], [38, 2], [56, -1], [72, -2], [88, 0.5], [102, 0]),
      },
      rig_handle_l: { rotationDeg: k([0, 0], [38, 2.5], [56, -1], [72, -1.5], [102, 0]) },
      rig_handle_r: { rotationDeg: k([0, 0], [38, -1], [56, 1.5], [72, 2], [102, 0]) },
      rig_stem: { rotationDeg: k([0, 0], [38, 1.5], [56, -0.8], [72, -1], [88, 0.3], [102, 0]) },
      rig_base: { scaleX: k([0, 1], [38, 1.01], [56, 1], [72, 1.006], [102, 1]) },
      rig_body__hair_underlap: { opacity: k([0, 0], [2, 1], [99, 1], [102, 0]) },
    },
  }),
  performance({
    slug: "victory_dance",
    displayName: "Victory Dance",
    durationSeconds: 3.6,
    fps: FPS,
    loop: false,
    semanticPreviewFrames: [0, 12, 28, 46, 64, 82, 96, 108],
    tracks: {
      rig_root: {
        dx: k([0, 0], [12, 0], [28, -8], [46, 8], [64, -7], [82, 7], [96, -2], [108, 0]),
        dy: k([0, 0], [12, 7], [28, -5], [46, -3], [64, -5], [82, -3], [96, 1], [108, 0]),
        rotationDeg: k([0, 0], [12, 0], [28, -4], [46, 4], [64, -3.5], [82, 3.5], [96, -1], [108, 0]),
        scaleX: k([0, 1], [12, 1.05], [28, 0.98], [46, 1.02], [64, 0.98], [82, 1.02], [96, 1.01], [108, 1]),
        scaleY: k([0, 1], [12, 0.94], [28, 1.03], [46, 0.98], [64, 1.03], [82, 0.98], [96, 0.99], [108, 1]),
      },
      rig_cup: {
        rotationDeg: k([0, 0], [12, 1], [28, 3], [46, -3], [64, 2.5], [82, -2.5], [96, 1], [108, 0]),
        dy: k([0, 0], [12, 2], [28, -2], [46, 1], [64, -2], [82, 1], [108, 0]),
      },
      rig_handle_l: { rotationDeg: k([0, 0], [12, -2], [28, -7], [46, 2], [64, -6], [82, 3], [96, -1], [108, 0]) },
      rig_handle_r: { rotationDeg: k([0, 0], [12, 2], [28, -2], [46, 7], [64, -3], [82, 6], [96, 1], [108, 0]) },
      rig_eye_l: {
        dx: k([0, 0], [28, -2], [46, 2], [64, -2], [82, 2], [96, 0], [108, 0]),
        scaleY: k([0, 1], [24, 1], [28, 0.45], [34, 1], [60, 1], [64, 0.45], [70, 1], [96, 1], [99, 0.12], [102, 1], [108, 1]),
      },
      rig_eye_r: {
        dx: k([0, 0], [28, -2], [46, 2], [64, -2], [82, 2], [96, 0], [108, 0]),
        scaleY: k([0, 1], [42, 1], [46, 0.45], [52, 1], [78, 1], [82, 0.45], [88, 1], [97, 1], [100, 0.12], [103, 1], [108, 1]),
      },
      rig_mouth: {
        rotationDeg: k([0, 0], [28, -2], [46, 2], [64, -2], [82, 2], [96, -0.5], [108, 0]),
        scaleX: k([0, 1], [12, 0.9], [28, 1.1], [46, 1.03], [64, 1.1], [82, 1.03], [96, 1.06], [108, 1]),
        dy: k([0, 0], [12, 2], [28, -1], [46, 0], [64, -1], [82, 0], [96, -0.5], [108, 0]),
      },
      rig_shine: {
        rotationDeg: k([0, 0], [28, -8], [46, 8], [64, -7], [82, 7], [96, -2], [108, 0]),
        scaleX: k([0, 1], [28, 1.15], [46, 0.95], [64, 1.15], [82, 0.95], [96, 1.05], [108, 1]),
        scaleY: k([0, 1], [28, 1.15], [46, 0.95], [64, 1.15], [82, 0.95], [96, 1.05], [108, 1]),
      },
      rig_hair: {
        rotationDeg: k([0, 0], [12, 4], [28, 10], [46, -11], [64, 9], [82, -9], [96, 3], [108, 0]),
        dx: k([0, 0], [28, 2], [46, -2], [64, 2], [82, -2], [96, 0.5], [108, 0]),
      },
      rig_stem: { rotationDeg: k([0, 0], [12, 0], [28, 2], [46, -2], [64, 1.8], [82, -1.8], [96, 0.5], [108, 0]) },
      rig_base: {
        scaleX: k([0, 1], [12, 1.045], [28, 0.99], [46, 1.015], [64, 0.99], [82, 1.015], [96, 1.01], [108, 1]),
        scaleY: k([0, 1], [12, 0.96], [28, 1.01], [46, 0.99], [64, 1.01], [82, 0.99], [96, 0.99], [108, 1]),
      },
      rig_body__hair_underlap: { opacity: k([0, 0], [2, 1], [105, 1], [108, 0]) },
    },
  }),
]);

const STRUCTURAL_CONTROLS_WITHOUT_SAFE_UNDERLAP = new Set([
  "rig_cup",
  "rig_handle_l",
  "rig_handle_r",
  "rig_stem",
  "rig_base",
]);

function delayedFringeTrack(spec) {
  const terminal = Math.round(spec.durationSeconds * spec.fps);
  const source = spec.tracks.rig_hair ?? {};
  const result = {};
  for (const [property, keys] of Object.entries(source)) {
    result[property] = keys.map(([frame, value], index) => {
      if (index === 0 || index === keys.length - 1) return [frame, value];
      const delayedFrame = Math.min(terminal - 1, frame + 2);
      const multiplier = property === "rotationDeg" ? 1.22 : 1.12;
      return [delayedFrame, value * multiplier];
    });
  }
  return result;
}

export const DETAILED_PERFORMANCE_SPECS = Object.freeze(RAW_DETAILED_PERFORMANCE_SPECS.map((spec) => Object.freeze({
  ...spec,
  tracks: Object.freeze({
    ...Object.fromEntries(Object.entries(spec.tracks).filter(([control]) => !STRUCTURAL_CONTROLS_WITHOUT_SAFE_UNDERLAP.has(control))),
    rig_hair_fringe: delayedFringeTrack(spec),
  }),
})));

function valueAt(keys, frame) {
  if (!keys) return undefined;
  if (frame <= keys[0][0]) return keys[0][1];
  if (frame >= keys.at(-1)[0]) return keys.at(-1)[1];
  return undefined;
}

export function validateDetailedPerformanceSpecs({ throwOnError = false } = {}) {
  const errors = [];
  const knownControls = new Set([...Object.keys(PIVOTS), "rig_body__hair_underlap"]);
  for (const spec of DETAILED_PERFORMANCE_SPECS) {
    const terminal = Math.round(spec.durationSeconds * spec.fps);
    if (spec.fps !== FPS) errors.push(`${spec.slug}: fps mismatch`);
    if (spec.semanticPreviewFrames[0] !== 0 || spec.semanticPreviewFrames.at(-1) !== terminal) {
      errors.push(`${spec.slug}: semantic preview endpoints are incomplete`);
    }
    if (Object.keys(spec.tracks).filter((control) => control !== "rig_body__hair_underlap").length < 7) {
      errors.push(`${spec.slug}: fewer than seven moving semantic controls`);
    }
    for (const [control, properties] of Object.entries(spec.tracks)) {
      if (!knownControls.has(control)) errors.push(`${spec.slug}: unknown control ${control}`);
      for (const [property, keys] of Object.entries(properties)) {
        if (!Array.isArray(keys) || keys.length < 2) errors.push(`${spec.slug}/${control}/${property}: invalid keys`);
        if (keys[0][0] !== 0 || keys.at(-1)[0] !== terminal) errors.push(`${spec.slug}/${control}/${property}: endpoint frame mismatch`);
        const neutral = property === "scaleX" || property === "scaleY" ? 1 : 0;
        if (valueAt(keys, 0) !== neutral || valueAt(keys, terminal) !== neutral) {
          errors.push(`${spec.slug}/${control}/${property}: endpoints are not neutral`);
        }
      }
    }
  }
  const result = { valid: errors.length === 0, animationCount: DETAILED_PERFORMANCE_SPECS.length, errors };
  if (throwOnError && errors.length) throw new Error(errors.join("\n"));
  return result;
}
