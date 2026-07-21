import { FPS } from "./rig-spec.mjs";
import {
  PERFORMANCE_SPECS as LIVE_PERFORMANCE_SPECS,
  validatePerformanceSpecs,
} from "./performance-spec.mjs";

const performance = (spec) => Object.freeze({ endpointPolicy: spec.loop ? "closed-loop" : "return-to-bind", ...spec });

export const GIF_ONLY_PERFORMANCE_SPECS = Object.freeze([
  performance({
    slug: "curious_tilt",
    displayName: "Curious Tilt",
    stateName: "Curious Tilt",
    durationSeconds: 1.8,
    fps: FPS,
    loop: true,
    requiredControls: ["rig_root", "rig_hair"],
    minimumMovingControlCount: 2,
    allowedVisibilityControls: ["rig_body__hair_underlap"],
    semanticPreviewFrames: [0, 18, 54, 90, 108],
    tracks: {
      rig_root: {
        dx: [[0, 0], [18, -2], [36, -1], [54, 2], [72, 1], [90, -1], [108, 0]],
        dy: [[0, 0], [18, 1], [36, 0], [54, -1], [72, 0], [90, 1], [108, 0]],
        rotationDeg: [[0, 0], [18, -2.5], [36, -1], [54, 2.5], [72, 1], [90, -1], [108, 0]],
      },
      rig_hair: {
        rotationDeg: [[0, 0], [18, 2], [36, -1], [54, -2], [72, 1.5], [90, 0.8], [108, 0]],
      },
      rig_body__hair_underlap: {
        opacity: [[0, 0], [4, 1], [104, 1], [108, 0]],
      },
    },
  }),
  performance({
    slug: "victory_shimmy",
    displayName: "Victory Shimmy",
    stateName: "Victory Shimmy",
    durationSeconds: 1.4,
    fps: FPS,
    loop: true,
    requiredControls: ["rig_root", "rig_hair"],
    minimumMovingControlCount: 2,
    allowedVisibilityControls: ["rig_body__hair_underlap"],
    semanticPreviewFrames: [0, 14, 28, 56, 84],
    tracks: {
      rig_root: {
        dx: [[0, 0], [14, -4], [28, 4], [42, -3], [56, 3], [70, -1], [84, 0]],
        dy: [[0, 0], [14, 1], [28, -2], [42, 1], [56, -2], [70, 0], [84, 0]],
        rotationDeg: [[0, 0], [14, -1.5], [28, 1.5], [42, -1.2], [56, 1.2], [70, -0.5], [84, 0]],
        scaleX: [[0, 1], [14, 1.01], [28, 0.995], [42, 1.008], [56, 0.997], [70, 1.003], [84, 1]],
        scaleY: [[0, 1], [14, 0.99], [28, 1.005], [42, 0.992], [56, 1.003], [70, 0.997], [84, 1]],
      },
      rig_hair: {
        rotationDeg: [[0, 0], [14, 3], [28, -3], [42, 2], [56, -2], [70, 1], [84, 0]],
      },
      rig_body__hair_underlap: {
        opacity: [[0, 0], [4, 1], [80, 1], [84, 0]],
      },
    },
  }),
]);

export const SHOWCASE_PERFORMANCE_SPECS = Object.freeze([
  ...LIVE_PERFORMANCE_SPECS,
  ...GIF_ONLY_PERFORMANCE_SPECS,
]);

export function validateShowcasePerformanceSpecs({ throwOnError = false } = {}) {
  return validatePerformanceSpecs(SHOWCASE_PERFORMANCE_SPECS, { throwOnError });
}
