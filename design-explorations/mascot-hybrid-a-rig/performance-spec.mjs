import { BASE_BY_NAME, FPS } from "./rig-spec.mjs";

const terminal = (durationSeconds) => Math.round(durationSeconds * FPS);
const performance = (spec) => Object.freeze({ endpointPolicy: spec.loop ? "closed-loop" : "return-to-bind", ...spec });

export const PERFORMANCE_SPECS = Object.freeze([
  performance({
    slug: "idle",
    displayName: "Idle",
    stateName: "Idle",
    durationSeconds: 2.4,
    fps: FPS,
    loop: true,
    requiredControls: ["rig_root", "rig_hair"],
    minimumMovingControlCount: 2,
    allowedVisibilityControls: ["rig_body__hair_underlap"],
    semanticPreviewFrames: [0, 36, 72, 108, 144],
    tracks: {
      rig_root: {
        dy: [[0, 0], [36, -2], [72, 0], [108, 1], [144, 0]],
        scaleX: [[0, 1], [36, 1.008], [72, 1], [108, 0.996], [144, 1]],
        scaleY: [[0, 1], [36, 0.992], [72, 1], [108, 1.004], [144, 1]],
      },
      rig_hair: {
        rotationDeg: [[0, 0], [24, -1.2], [60, 0.8], [96, -0.6], [120, 0.5], [144, 0]],
      },
      rig_body__hair_underlap: {
        opacity: [[0, 0], [4, 1], [140, 1], [144, 0]],
      },
    },
  }),
  performance({
    slug: "celebrate",
    displayName: "Celebrate",
    stateName: "Celebrate",
    durationSeconds: 1.2,
    fps: FPS,
    loop: false,
    requiredControls: ["rig_root", "rig_hair"],
    minimumMovingControlCount: 2,
    allowedVisibilityControls: ["rig_body__hair_underlap"],
    semanticPreviewFrames: [0, 12, 32, 48, 72],
    tracks: {
      rig_root: {
        dy: [[0, 0], [12, 4], [32, -24], [48, -10], [72, 0]],
        rotationDeg: [[0, 0], [12, -3], [32, 4], [48, -2], [72, 0]],
        scaleX: [[0, 1], [12, 1.04], [32, 0.98], [48, 1.02], [72, 1]],
        scaleY: [[0, 1], [12, 0.96], [32, 1.04], [48, 0.99], [72, 1]],
      },
      rig_hair: {
        dy: [[0, 0], [12, 0], [32, 1], [48, -0.5], [72, 0]],
        rotationDeg: [[0, 0], [12, -2.5], [32, 4], [48, -2], [60, 0.8], [72, 0]],
      },
      rig_body__hair_underlap: {
        opacity: [[0, 0], [4, 1], [68, 1], [72, 0]],
      },
    },
  }),
  performance({
    slug: "hair_sway",
    displayName: "Hair Sway",
    stateName: "Hair Sway",
    durationSeconds: 1.6,
    fps: FPS,
    loop: true,
    requiredControls: ["rig_hair"],
    minimumMovingControlCount: 1,
    allowedVisibilityControls: ["rig_body__hair_underlap"],
    semanticPreviewFrames: [0, 24, 48, 72, 96],
    tracks: {
      rig_hair: {
        rotationDeg: [[0, 0], [24, -2.5], [48, 2], [72, -1.5], [96, 0]],
        scaleX: [[0, 1], [24, 1.008], [48, 0.995], [72, 1.005], [96, 1]],
      },
      rig_body__hair_underlap: {
        opacity: [[0, 0], [4, 1], [92, 1], [96, 0]],
      },
    },
  }),
]);

export const PERFORMANCE_BY_SLUG = Object.freeze(Object.fromEntries(PERFORMANCE_SPECS.map((spec) => [spec.slug, spec])));

export function terminalFrame(spec) {
  return terminal(spec.durationSeconds);
}

export function validatePerformanceSpecs(specs = PERFORMANCE_SPECS, { throwOnError = false } = {}) {
  const errors = [];
  if (!Array.isArray(specs) || specs.length === 0) errors.push("No animation performances have been authored.");
  const allowedProperties = new Set(["dx", "dy", "rotationDeg", "scaleX", "scaleY", "opacity"]);
  for (const spec of specs) {
    const end = terminalFrame(spec);
    const movingControls = Object.keys(spec.tracks ?? {});
    if (movingControls.length < spec.minimumMovingControlCount) errors.push(`${spec.slug}: moving-control minimum not met`);
    for (const control of spec.requiredControls ?? []) {
      if (!BASE_BY_NAME[control]) errors.push(`${spec.slug}: unknown required control ${control}`);
    }
    for (const [control, properties] of Object.entries(spec.tracks ?? {})) {
      if (!BASE_BY_NAME[control]) errors.push(`${spec.slug}: unknown track control ${control}`);
      for (const [property, keys] of Object.entries(properties)) {
        if (!allowedProperties.has(property)) errors.push(`${spec.slug}/${control}: unsupported property ${property}`);
        if (!Array.isArray(keys) || keys.length < 2 || keys[0]?.[0] !== 0 || keys.at(-1)?.[0] !== end) {
          errors.push(`${spec.slug}/${control}/${property}: endpoints must be 0 and ${end}`);
          continue;
        }
        for (let index = 0; index < keys.length; index += 1) {
          const [frame, value] = keys[index];
          if (!Number.isInteger(frame) || !Number.isFinite(value)) errors.push(`${spec.slug}/${control}/${property}: invalid key ${index}`);
          if (index > 0 && frame <= keys[index - 1][0]) errors.push(`${spec.slug}/${control}/${property}: frames must increase`);
        }
        if (spec.loop && keys[0][1] !== keys.at(-1)[1]) errors.push(`${spec.slug}/${control}/${property}: loop does not close`);
      }
    }
  }
  const report = { valid: errors.length === 0, errors, performanceCount: specs.length, fps: FPS };
  if (throwOnError && errors.length) throw new Error(errors.join("\n"));
  return report;
}
