#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const FPS = 60;

export const PIVOTS = Object.freeze({
  rig_root: { parent: null, x: 256, y: 401, pivot: { x: 256, y: 401 } },
  rig_base: { parent: "rig_root", x: 0, y: 0, pivot: { x: 256, y: 401 } },
  rig_stem: { parent: "rig_root", x: -1, y: -76, pivot: { x: 255, y: 325 } },
  rig_handle_l: { parent: "rig_root", x: -168, y: -251, pivot: { x: 88, y: 150 } },
  rig_handle_r: { parent: "rig_root", x: 166, y: -251, pivot: { x: 422, y: 150 } },
  rig_tab: { parent: "rig_root", x: 207, y: -329, pivot: { x: 463, y: 72 } },
  rig_cup: { parent: "rig_root", x: -1, y: -156, pivot: { x: 255, y: 245 } },
  rig_hair: { parent: "rig_root", x: -2, y: -312, pivot: { x: 254, y: 89 }, kind: "nestedArtboard" },
  rig_badge: { parent: "rig_root", x: -138, y: -320, pivot: { x: 118, y: 81 } },
  rig_eye_l: { parent: "rig_root", x: -60, y: -254, pivot: { x: 196, y: 147 } },
  rig_eye_r: { parent: "rig_root", x: 56, y: -254, pivot: { x: 312, y: 147 } },
  rig_mouth: { parent: "rig_root", x: -1, y: -196, pivot: { x: 255, y: 205 } },
});

export const CURVES = Object.freeze({
  gentle: Object.freeze([0.37, 0, 0.63, 1]),
  anticipation: Object.freeze([0.55, 0, 0.8, 0.2]),
  action: Object.freeze([0.2, 0.8, 0.25, 1]),
  recovery: Object.freeze([0.22, 0.75, 0.35, 1]),
});

const k = (curve, ...pairs) => pairs.map(([frame, value], index) =>
  Object.freeze([frame, value, index === pairs.length - 1 ? "gentle" : curve]));

export const PERFORMANCES = Object.freeze([
  Object.freeze({
    slug: "idle_breathe_blink", label: "Idle", durationFrames: 72, loop: true,
    contactFrames: [0, 18, 42, 52, 55, 72],
    tracks: Object.freeze({
      rig_cup: { dy: k("gentle", [0, 0], [18, -3], [42, 2], [72, 0]), scaleX: k("gentle", [0, 1], [18, .996], [42, 1.003], [72, 1]), scaleY: k("gentle", [0, 1], [18, 1.009], [42, .996], [72, 1]) },
      rig_stem: { dy: k("gentle", [0, 0], [20, -1.5], [44, 1], [72, 0]) },
      rig_base: { scaleY: k("gentle", [0, 1], [20, .996], [44, 1.003], [72, 1]) },
      rig_hair: { dy: k("gentle", [0, 0], [22, -2], [46, 1], [72, 0]), rotationDeg: k("gentle", [0, 0], [22, 1.4], [46, -1], [72, 0]) },
      rig_handle_l: { rotationDeg: k("gentle", [0, 0], [21, .9], [45, -.6], [72, 0]) },
      rig_handle_r: { rotationDeg: k("gentle", [0, 0], [24, -.75], [48, .5], [72, 0]) },
      rig_eye_l: { scaleY: k("action", [0, 1], [49, 1], [50, .12], [51, .12], [52, 1], [72, 1]) },
      rig_eye_r: { scaleY: k("action", [0, 1], [52, 1], [53, .12], [54, .12], [55, 1], [72, 1]) },
    }),
  }),
  Object.freeze({
    slug: "hair_bounce", label: "Hair Bounce", durationFrames: 48, loop: false,
    contactFrames: [0, 7, 15, 26, 37, 48],
    tracks: Object.freeze({
      rig_cup: { dy: k("anticipation", [0, 0], [7, 2.5], [15, -2.5], [26, 1], [37, -.4], [48, 0]), scaleY: k("recovery", [0, 1], [7, .99], [15, 1.008], [26, .996], [37, 1.002], [48, 1]) },
      rig_stem: { dy: k("anticipation", [0, 0], [7, 1.2], [16, -1.2], [27, .5], [48, 0]) },
      rig_base: { scaleY: k("recovery", [0, 1], [7, 1.006], [16, .996], [27, 1.003], [48, 1]) },
      rig_hair: { dy: k("action", [0, 0], [7, 2], [15, -11], [26, 3], [37, -1], [48, 0]), rotationDeg: k("action", [0, 0], [7, -1.5], [15, 3.6], [26, -2.2], [37, .8], [48, 0]) },
      rig_handle_l: { rotationDeg: k("action", [0, 0], [8, -1], [17, 1.8], [27, -.8], [39, .25], [48, 0]) },
      rig_handle_r: { rotationDeg: k("action", [0, 0], [10, .8], [19, -1.5], [29, .65], [40, -.2], [48, 0]) },
    }),
  }),
  Object.freeze({
    slug: "victory_pop", label: "Victory Pop", durationFrames: 72, loop: false,
    contactFrames: [0, 14, 24, 29, 44, 49, 64, 72],
    tracks: Object.freeze({
      rig_root: { dy: k("action", [0, 0], [10, 2], [14, 3], [24, -22], [29, -21], [44, 2], [49, 0], [60, -1], [64, 0], [72, 0]), rotationDeg: k("recovery", [0, 0], [14, -1], [25, 1.2], [44, -.8], [60, .25], [72, 0]) },
      rig_cup: { dy: k("action", [0, 0], [14, 3], [24, -2], [29, -1], [44, 2], [49, 0], [64, -.4], [72, 0]), scaleX: k("action", [0, 1], [14, 1.024], [24, .99], [29, .994], [44, 1.012], [49, 1], [64, .998], [72, 1]), scaleY: k("action", [0, 1], [14, .976], [24, 1.018], [29, 1.012], [44, .988], [49, 1], [64, 1.002], [72, 1]) },
      rig_stem: { dy: k("action", [0, 0], [14, 1.8], [25, -1.4], [45, .9], [50, 0], [72, 0]) },
      rig_base: { scaleY: k("recovery", [0, 1], [14, 1.014], [25, .992], [45, 1.008], [50, 1], [72, 1]) },
      rig_hair: { dy: k("action", [0, 0], [14, 2], [27, -9], [32, -6], [47, 3], [52, 0], [63, -1], [72, 0]), rotationDeg: k("action", [0, 0], [14, -2], [27, 4], [32, 2.5], [47, -2.3], [52, 0], [63, .7], [72, 0]) },
      rig_handle_l: { rotationDeg: k("action", [0, 0], [13, -2], [26, 3.4], [46, -2], [51, 0], [62, .5], [72, 0]) },
      rig_handle_r: { rotationDeg: k("action", [0, 0], [15, 1.7], [29, -3], [48, 1.7], [53, 0], [65, -.4], [72, 0]) },
      rig_mouth: { scaleY: k("action", [0, 1], [14, 1], [25, 1.16], [44, 1.1], [52, 1.03], [64, 1], [72, 1]) },
    }),
  }),
  Object.freeze({
    slug: "curious_tilt", label: "Curious Tilt", durationFrames: 84, loop: false,
    contactFrames: [0, 9, 24, 28, 36, 52, 76, 84],
    tracks: Object.freeze({
      rig_eye_l: { dx: k("action", [0, 0], [8, 1.5], [24, 2.6], [28, 2.6], [36, 2.6], [50, -.8], [68, 0], [84, 0]), dy: k("action", [0, 0], [8, -.5], [24, -1], [28, -1], [36, -1], [50, .3], [68, 0], [84, 0]) },
      rig_eye_r: { dx: k("action", [0, 0], [7, 1], [23, 1.9], [28, 1.9], [36, 1.9], [49, -.5], [67, 0], [84, 0]), dy: k("action", [0, 0], [7, -.25], [23, -.7], [28, -.7], [36, -.7], [49, .2], [67, 0], [84, 0]) },
      rig_cup: { dx: k("action", [0, 0], [9, -2], [24, 7], [28, 7], [36, 7], [52, -2], [68, .6], [76, 0], [84, 0]), dy: k("action", [0, 0], [9, 1], [24, -1], [28, -1], [36, -1], [52, 1], [68, -.3], [76, 0], [84, 0]), rotationDeg: k("action", [0, 0], [9, -2], [24, 7], [28, 7], [36, 7], [52, -2.5], [68, .7], [76, 0], [84, 0]) },
      rig_stem: { rotationDeg: k("recovery", [0, 0], [10, -1], [25, 2.6], [29, 2.6], [37, 2.6], [53, -1], [70, .3], [84, 0]) },
      rig_hair: { dx: k("action", [0, 0], [11, -1], [27, 4], [31, 4], [39, 4], [55, -1.5], [72, .5], [84, 0]), dy: k("action", [0, 0], [11, 1], [27, -2], [31, -2], [39, -2], [55, 1], [72, -.3], [84, 0]), rotationDeg: k("action", [0, 0], [11, -2], [27, 5], [31, 5], [39, 5], [55, -2], [72, .6], [84, 0]) },
      rig_handle_l: { rotationDeg: k("action", [0, 0], [10, -1], [26, 3.5], [30, 3.5], [38, 3.5], [54, -1.5], [70, .35], [84, 0]) },
      rig_handle_r: { rotationDeg: k("action", [0, 0], [12, .7], [28, -2.7], [32, -2.7], [40, -2.7], [56, 1.1], [72, -.25], [84, 0]) },
      rig_mouth: { scaleY: k("gentle", [0, 1], [24, 1.06], [28, 1.06], [36, 1.06], [52, 1.02], [68, 1], [84, 1]) },
    }),
  }),
  Object.freeze({
    slug: "celebrate_shimmy", label: "Celebrate Shimmy", durationFrames: 96, loop: true,
    contactFrames: [0, 12, 25, 44, 56, 70, 88, 96],
    tracks: Object.freeze({
      rig_cup: { dx: k("action", [0, 0], [12, -7], [25, 7], [44, 0], [56, 6], [70, -6], [88, 1], [96, 0]), dy: k("gentle", [0, 0], [12, 1], [25, -1], [44, 0], [56, -.8], [70, .8], [88, -.2], [96, 0]), rotationDeg: k("action", [0, 0], [12, -3.5], [25, 3.5], [44, 0], [56, 3], [70, -3.2], [88, .5], [96, 0]) },
      rig_stem: { dx: k("action", [0, 0], [13, -2], [26, 2], [45, 0], [57, 1.7], [71, -1.7], [89, .3], [96, 0]), rotationDeg: k("action", [0, 0], [13, -1.5], [26, 1.5], [45, 0], [57, 1.2], [71, -1.3], [89, .2], [96, 0]) },
      rig_base: { scaleY: k("gentle", [0, 1], [14, 1.006], [27, .994], [45, 1], [58, .996], [72, 1.004], [90, .999], [96, 1]) },
      rig_hair: { dx: k("action", [0, 0], [15, -6], [28, 6], [47, 0], [59, 5], [73, -5], [91, .7], [96, 0]), dy: k("action", [0, 0], [15, -1], [28, 1], [47, 0], [59, 1], [73, -1], [91, 0], [96, 0]), rotationDeg: k("action", [0, 0], [15, -3], [28, 3], [47, 0], [59, 2.6], [73, -2.8], [91, .4], [96, 0]) },
      rig_handle_l: { rotationDeg: k("action", [0, 0], [10, -3], [23, 3], [42, 0], [54, 2.5], [68, -2.7], [86, .4], [96, 0]) },
      rig_handle_r: { rotationDeg: k("action", [0, 0], [13, 2.5], [27, -2.8], [46, 0], [58, -2.3], [72, 2.4], [90, -.3], [96, 0]) },
      rig_eye_l: { dx: k("action", [0, 0], [11, -2], [24, 2], [43, 0], [55, 1.6], [69, -1.7], [87, .2], [96, 0]) },
      rig_eye_r: { dx: k("action", [0, 0], [14, -1.4], [28, 1.7], [47, 0], [59, 1.2], [73, -1.4], [91, .1], [96, 0]) },
      rig_mouth: { scaleY: k("gentle", [0, 1], [12, 1.1], [25, 1.06], [44, 1], [56, 1.08], [70, 1.04], [88, 1.01], [96, 1]) },
    }),
  }),
]);

const neutralFor = (property) => ["scaleX", "scaleY", "opacity"].includes(property) ? 1 : 0;
const signature = (performance) => ({ slug: performance.slug, durationFrames: performance.durationFrames, loop: performance.loop, tracks: performance.tracks });

export function motionSpecHash() {
  return crypto.createHash("sha256").update(JSON.stringify({ fps: FPS, pivots: PIVOTS, curves: CURVES, performances: PERFORMANCES.map(signature) })).digest("hex");
}

export function validateMotionSpec() {
  const errors = [];
  const curveNames = new Set();
  const expected = new Map([["idle_breathe_blink", [72, true]], ["hair_bounce", [48, false]], ["victory_pop", [72, false]], ["curious_tilt", [84, false]], ["celebrate_shimmy", [96, true]]]);
  if (PERFORMANCES.length !== expected.size) errors.push(`expected ${expected.size} performances`);
  for (const performance of PERFORMANCES) {
    const contract = expected.get(performance.slug);
    if (!contract || contract[0] !== performance.durationFrames || contract[1] !== performance.loop) errors.push(`${performance.slug}: settings mismatch`);
    for (const [node, properties] of Object.entries(performance.tracks)) {
      if (!PIVOTS[node]) errors.push(`${performance.slug}: unknown node ${node}`);
      for (const [property, keys] of Object.entries(properties)) {
        if (!keys.length || keys[0][0] !== 0 || keys.at(-1)[0] !== performance.durationFrames) errors.push(`${performance.slug}/${node}/${property}: missing endpoints`);
        for (let index = 0; index < keys.length; index += 1) {
          const [frame, value, curve] = keys[index];
          curveNames.add(curve);
          if (!Number.isFinite(frame) || !Number.isFinite(value)) errors.push(`${performance.slug}/${node}/${property}: non-finite key`);
          if (index > 0 && frame <= keys[index - 1][0]) errors.push(`${performance.slug}/${node}/${property}: frames not strictly increasing`);
          if (!CURVES[curve]) errors.push(`${performance.slug}/${node}/${property}: unknown curve ${curve}`);
        }
        if (Math.abs(keys.at(-1)[1] - neutralFor(property)) > 1e-6) errors.push(`${performance.slug}/${node}/${property}: terminal is not bind`);
        if (performance.loop && Math.abs(keys[0][1] - keys.at(-1)[1]) > 1e-6) errors.push(`${performance.slug}/${node}/${property}: loop mismatch`);
      }
    }
  }
  if (curveNames.size !== 4) errors.push(`expected four curve families, found ${[...curveNames].join(",")}`);
  const bySlug = Object.fromEntries(PERFORMANCES.map((item) => [item.slug, item]));
  if (bySlug.hair_bounce.tracks.rig_eye_l || bySlug.hair_bounce.tracks.rig_eye_r) errors.push("hair_bounce: eye scale track forbidden");
  if (Math.min(...bySlug.victory_pop.tracks.rig_root.dy.map((key) => key[1])) > -22) errors.push("victory_pop: root apex too low");
  const curiousHold = bySlug.curious_tilt.tracks.rig_cup.rotationDeg.filter((key) => [28, 36].includes(key[0])).map((key) => key[1]);
  if (curiousHold.length !== 2 || curiousHold[0] !== curiousHold[1]) errors.push("curious_tilt: hold is not flat");
  const shimmy = bySlug.celebrate_shimmy.tracks;
  if (Math.abs(shimmy.rig_handle_r.rotationDeg[1][0] - shimmy.rig_handle_l.rotationDeg[1][0]) < 2) errors.push("celebrate_shimmy: handles not staggered");
  if (Math.abs(shimmy.rig_hair.dx[1][0] - shimmy.rig_cup.dx[1][0]) < 3) errors.push("celebrate_shimmy: hair lag too short");
  const report = {
    passed: errors.length === 0,
    errors,
    fps: FPS,
    specHash: motionSpecHash(),
    curveFamilies: [...curveNames].sort(),
    animations: PERFORMANCES.map((performance) => ({
      slug: performance.slug,
      durationFrames: performance.durationFrames,
      loop: performance.loop,
      trackCount: Object.values(performance.tracks).reduce((total, properties) => total + Object.keys(properties).length, 0),
      keyCount: Object.values(performance.tracks).reduce((total, properties) => total + Object.values(properties).reduce((sum, keys) => sum + keys.length, 0), 0),
    })),
  };
  if (errors.length) throw Object.assign(new Error(errors.join("\n")), { report });
  return report;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const outputPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "spec-validation.json");
  try {
    const report = validateMotionSpec();
    fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } catch (error) {
    const report = error.report ?? { passed: false, errors: [String(error.message ?? error)] };
    fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
    console.error(error.stack ?? String(error));
    process.exitCode = 1;
  }
}
