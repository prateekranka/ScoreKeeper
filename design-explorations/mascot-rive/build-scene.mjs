#!/usr/bin/env node
// build-scene.mjs — generates the PipCount Bauhaus mascot scene spec for riv_create.
// "Pip": a lacquered score-token mascot built from Bauhaus primitives.
// All geometry in local coords relative to root group at (256,232) on a 512x512 artboard.
import { writeFileSync } from 'node:fs';

// ---------- helpers ----------
const P = (x, y, radius) => (radius !== undefined ? { x, y, radius } : { x, y });
const poly = (id, pts, opts = {}) => ({ id, type: 'polygon', x: 0, y: 0, points: pts, ...opts });
const ellipse = (id, x, y, w, h, opts = {}) => ({ id, type: 'ellipse', x, y, width: w, height: h, ...opts });
const rect = (id, x, y, w, h, opts = {}) => ({ id, type: 'rect', x, y, width: w, height: h, ...opts });

const INK = '#0A0B0B';
const CREAM = '#FFF7E5';
const BLUE = '#064BB8';
const RED = '#F02A1B';
const YELLOW = '#FFB600';
const GREEN = '#00965A';

// body token gradient: light top-left -> deep bottom-right
// NOTE: gradient fills on SMALL shapes render broken (half-size/clipped) in the
// Canvas2D preview pipeline — keep gradients ONLY on the big body circle.
const bodyGrad = { type: 'linear', start: { x: -118, y: -118 }, end: { x: 118, y: 118 }, stops: [
  { color: '#5E72EC', position: 0 }, { color: BLUE, position: 0.55 }, { color: '#04357D', position: 1 } ] };
const CREAM_LIMB = '#F4EBD6'; // limbs slightly deeper than face cream so they read separately

const outline = (thickness = 8) => ({ color: INK, thickness });

// ---------- scene ----------
// NOTE: shape/group x,y is PARENT-RELATIVE. pip sits at artboard (256,232);
// every child below is expressed relative to pip.
const groups = [
  { id: 'pip', x: 256, y: 232, rotation: 1.2 },                    // whole-character root (bob / squash / rotate)
  { id: 'earL', x: -88, y: -26, parent: 'pip', rotation: -2 },
  { id: 'earR', x: 88, y: -26, parent: 'pip', rotation: 2 },
  { id: 'pennant', x: 0, y: -42, parent: 'pip', rotation: 3 },
  { id: 'armL', x: -122, y: 72, parent: 'pip', rotation: -16 },
  { id: 'armR', x: 122, y: 72, parent: 'pip', rotation: 12 },
  { id: 'legL', x: -28, y: 192, parent: 'pip', rotation: 6 },
  { id: 'legR', x: 28, y: 192, parent: 'pip', rotation: -6 },
  { id: 'eyeL', x: -30, y: 34, parent: 'pip' },
  { id: 'eyeR', x: 30, y: 34, parent: 'pip' },
  { id: 'mouthG', x: 0, y: 102, parent: 'pip' },
  { id: 'confetti', x: 0, y: 100, parent: 'pip' },
];

const shapes = [
  // ground shadow (not under pip — stays planted, artboard coords)
  ellipse('shadow', 256, 440, 300, 48, { z: 5, fill: { color: INK }, opacity: 0.13 }),

  // body token (all children below are pip-relative)
  ellipse('bodyClip', 0, 74, 236, 236, { z: 9, parent: 'pip' }),
  ellipse('body', 0, 74, 236, 236, { z: 10, parent: 'pip', fill: { gradient: bodyGrad }, stroke: outline(10) }),
  ellipse('bodyHi', -58, 24, 64, 36, { z: 11, parent: 'pip', fill: { color: '#FFFFFF' }, opacity: 0.16, blendMode: 'screen', clipBy: 'bodyClip' }),
  ellipse('bodyAO', 0, 108, 176, 88, { z: 13, parent: 'pip', fill: { color: INK }, opacity: 0.10, blendMode: 'multiply', clipBy: 'bodyClip' }),
  ellipse('faceAO', 0, 128, 120, 36, { z: 14, parent: 'pip', fill: { color: INK }, opacity: 0.07, blendMode: 'multiply', clipBy: 'bodyClip' }),
  ellipse('rim', 0, 74, 198, 198, { z: 12, parent: 'pip', stroke: { color: '#470A0B0B', thickness: 4 } }),

  // chest pips (below face plate)
  ellipse('pip1', 0, 142, 30, 30, { z: 20, parent: 'pip', fill: { color: YELLOW }, stroke: outline(5) }),
  ellipse('pip2', -20, 172, 30, 30, { z: 21, parent: 'pip', fill: { color: RED }, stroke: outline(5) }),
  ellipse('pip3', 20, 172, 30, 30, { z: 22, parent: 'pip', fill: { color: GREEN }, stroke: outline(5) }),

  // ears (rounded triangles, asymmetric Bauhaus: yellow left / red right)
  poly('earLShape', [P(-34, 14, 16), P(-4, -80, 16), P(30, 14, 16)], { z: 30, parent: 'earL', fill: { color: YELLOW }, stroke: outline(7) }),
  poly('earRShape', [P(34, 14, 16), P(4, -80, 16), P(-30, 14, 16)], { z: 31, parent: 'earR', fill: { color: RED }, stroke: outline(7) }),

  // pennant (felt green flag + pip, ink pole) — children relative to pennant pivot
  rect('pole', 0, -36, 9, 72, { z: 40, parent: 'pennant', cornerRadius: 4, fill: { color: INK } }),
  poly('flag', [P(-3, -64, 8), P(62, -52, 8), P(-3, -34, 8)], { z: 41, parent: 'pennant', fill: { color: GREEN }, stroke: outline(6) }),
  ellipse('flagPip', 23, -50, 14, 14, { z: 42, parent: 'pennant', fill: { color: CREAM }, stroke: outline(4) }),
  ellipse('poleMount', 0, 0, 28, 28, { z: 43, parent: 'pennant', fill: { color: '#E8A33D' }, stroke: outline(5) }),
  ellipse('poleMountCore', 0, 0, 12, 12, { z: 44, parent: 'pennant', fill: { color: INK } }),

  // arms (cream stubs, pivots at shoulders)
  rect('armLShape', -20, 40, 40, 80, { z: 50, parent: 'armL', cornerRadius: 20, fill: { color: CREAM_LIMB }, stroke: outline(8) }),
  rect('armRShape', -20, 40, 40, 80, { z: 51, parent: 'armR', cornerRadius: 20, fill: { color: CREAM_LIMB }, stroke: outline(8) }),

  // legs
  rect('legLShape', -19, 24, 38, 48, { z: 52, parent: 'legL', cornerRadius: 19, fill: { color: CREAM_LIMB }, stroke: outline(8) }),
  rect('legRShape', -19, 24, 38, 48, { z: 53, parent: 'legR', cornerRadius: 19, fill: { color: CREAM_LIMB }, stroke: outline(8) }),

  // face plate (cream)
  ellipse('face', 0, 60, 148, 148, { z: 60, parent: 'pip', fill: { color: CREAM }, stroke: outline(9) }),
  ellipse('blushL', -58, 88, 20, 20, { z: 61, parent: 'pip', fill: { color: '#FF8A65' }, opacity: 0.45 }),
  ellipse('blushR', 58, 88, 20, 20, { z: 62, parent: 'pip', fill: { color: '#FF8A65' }, opacity: 0.45 }),

  // eyes (sclera + pupil + catchlight; blink via eye group scaleY, look via pupil x)
  ellipse('scleraL', 0, 0, 30, 30, { z: 70, parent: 'eyeL', fill: { color: '#FFFFFF' } }),
  ellipse('pupilL', 0, 2.5, 13, 13, { z: 71, parent: 'eyeL', fill: { color: INK } }),
  ellipse('catchL', -3, -4, 8, 8, { z: 72, parent: 'eyeL', fill: { color: '#FFFFFF' } }),
  ellipse('scleraR', 0, 0, 30, 30, { z: 73, parent: 'eyeR', fill: { color: '#FFFFFF' } }),
  ellipse('pupilR', 0, 2.5, 13, 13, { z: 74, parent: 'eyeR', fill: { color: INK } }),
  ellipse('catchR', -3, -4, 8, 8, { z: 75, parent: 'eyeR', fill: { color: '#FFFFFF' } }),

  // nose — small lacquer triangle (Bauhaus)
  poly('nose', [P(-12, -6, 6), P(12, -6, 6), P(0, 12, 6)], { z: 80, parent: 'pip', x: 0, y: 76, fill: { color: RED }, stroke: outline(5) }),

  // mouth — closed smile arc (open path, round-cap stroke)
  { id: 'mouthShape', type: 'polygon', x: 0, y: 0, closed: false, z: 90, parent: 'mouthG',
    points: [ { x: -24, y: 0, cubic: { rotation: 28, distance: 24 } },
              { x: 24, y: 0, cubic: { rotation: 152, distance: 24 } } ],
    stroke: { color: INK, thickness: 7, cap: 'round' } },

  // confetti (celebrate only; invisible in idle via opacity 0)
  ellipse('c1', -4, 0, 16, 16, { z: 100, parent: 'confetti', fill: { color: YELLOW }, stroke: outline(3), opacity: 0 }),
  ellipse('c2', 6, 4, 14, 14, { z: 101, parent: 'confetti', fill: { color: RED }, stroke: outline(3), opacity: 0 }),
  ellipse('c3', 10, -6, 12, 12, { z: 102, parent: 'confetti', fill: { color: BLUE }, stroke: outline(3), opacity: 0 }),
  ellipse('c4', -12, -4, 14, 14, { z: 103, parent: 'confetti', fill: { color: GREEN }, stroke: outline(3), opacity: 0 }),
  ellipse('c5', 0, -10, 12, 12, { z: 104, parent: 'confetti', fill: { color: CREAM }, stroke: outline(3), opacity: 0 }),
  ellipse('c6', 14, 10, 10, 10, { z: 105, parent: 'confetti', fill: { color: YELLOW }, stroke: outline(3), opacity: 0 }),
];

// ---------- animation tracks ----------
const EIO = 'ease-in-out';
const kf = (frame, value, easing) => (easing ? { frame, value, easing } : { frame, value });

// ---- idle: 3.5s @ 60fps = 210 frames, loop ----
const idle = {
  name: 'idle', fps: 60, duration: 210, loop: 'loop',
  tracks: [
    // breathing bob (y peaks at 52/157 when stretched)
    { target: 'pip', property: 'y', keyframes: [kf(0, 232), kf(52, 227, EIO), kf(105, 232, EIO), kf(157, 227, EIO), kf(210, 232, EIO)] },
    { target: 'pip', property: 'rotation', keyframes: [kf(0, 1.2), kf(40, 2.4, EIO), kf(130, 0, EIO), kf(210, 1.2, EIO)] },
    { target: 'pip', property: 'scaleY', keyframes: [kf(0, 1), kf(52, 1.02, EIO), kf(105, 0.99, EIO), kf(157, 1.02, EIO), kf(210, 1, EIO)] },
    // shadow counter-moves (smaller/lighter when body rises)
    { target: 'shadow', property: 'scaleX', keyframes: [kf(0, 1), kf(52, 0.965, EIO), kf(105, 1.03, EIO), kf(157, 0.965, EIO), kf(210, 1, EIO)] },
    { target: 'shadow', property: 'opacity', keyframes: [kf(0, 0.13), kf(52, 0.115, EIO), kf(105, 0.13, EIO), kf(157, 0.115, EIO), kf(210, 0.13, EIO)] },
    // ears wiggle out of phase with body (secondary motion)
    { target: 'earL', property: 'rotation', keyframes: [kf(0, -2), kf(45, -7, EIO), kf(110, 2, EIO), kf(165, -5, EIO), kf(210, -2, EIO)] },
    { target: 'earR', property: 'rotation', keyframes: [kf(0, 2), kf(45, 7, EIO), kf(110, -2, EIO), kf(165, 5, EIO), kf(210, 2, EIO)] },
    // pennant flutter (fast, small, lagged)
    { target: 'pennant', property: 'rotation', keyframes: [kf(0, 3), kf(20, -3, EIO), kf(50, 8, EIO), kf(80, -1, EIO), kf(110, 8, EIO), kf(140, -2, EIO), kf(170, 7, EIO), kf(210, 3, EIO)] },
    // arms sway (around static -14/+14)
    { target: 'armL', property: 'rotation', keyframes: [kf(0, -16), kf(55, -19, EIO), kf(110, -13, EIO), kf(165, -19, EIO), kf(210, -16, EIO)] },
    { target: 'armR', property: 'rotation', keyframes: [kf(0, 12), kf(55, 15, EIO), kf(110, 9, EIO), kf(165, 15, EIO), kf(210, 12, EIO)] },
    // smile breathes with the body
    { target: 'mouthG', property: 'scaleX', keyframes: [kf(0, 1), kf(52, 1.06, EIO), kf(105, 0.98, EIO), kf(157, 1.06, EIO), kf(210, 1, EIO)] },
    // blink ~1/3 into cycle, right eye lags 1 frame
    { target: 'eyeL', property: 'scaleY', keyframes: [kf(125, 1), kf(127, 1), kf(129, 0.08, 'ease-in'), kf(131, 1, 'ease-out'), kf(210, 1)] },
    { target: 'eyeR', property: 'scaleY', keyframes: [kf(126, 1), kf(128, 1), kf(130, 0.08, 'ease-in'), kf(132, 1, 'ease-out'), kf(210, 1)] },
    // occasional glance toward "the score" (pupils shift right, then back)
    { target: 'pupilL', property: 'x', keyframes: [kf(0, 0), kf(160, 0), kf(170, 4.5, 'ease-out'), kf(185, 4.5, 'hold'), kf(195, 0, EIO), kf(210, 0)] },
    { target: 'pupilR', property: 'x', keyframes: [kf(0, 0), kf(160, 0), kf(170, 4.5, 'ease-out'), kf(185, 4.5, 'hold'), kf(195, 0, EIO), kf(210, 0)] },
  ],
};

// ---- celebrate: 1.5s @ 60fps = 90 frames, one-shot ----
const celebrate = {
  name: 'celebrate', fps: 60, duration: 90, loop: 'oneShot',
  tracks: [
    // anticipation crouch -> launch -> hang -> fall -> landing squash -> elastic settle
    { target: 'pip', property: 'y', keyframes: [kf(0, 232), kf(10, 232, 'hold'), kf(28, 160, 'ease-out'), kf(48, 160, 'smooth'), kf(62, 232, 'emphasized-accel'), kf(72, 228, 'ease-out'), kf(90, 232, 'ease-in-out')] },
    { target: 'pip', property: 'scaleX', keyframes: [kf(0, 1), kf(10, 1.12, 'ease-in-back'), kf(28, 0.92, 'ease-out'), kf(48, 0.94, 'smooth'), kf(62, 1.1, 'emphasized-accel'), kf(90, 1, 'elastic-out')] },
    { target: 'pip', property: 'scaleY', keyframes: [kf(0, 1), kf(10, 0.86, 'ease-in-back'), kf(28, 1.08, 'ease-out'), kf(48, 1.05, 'smooth'), kf(62, 0.88, 'emphasized-accel'), kf(90, 1, 'elastic-out')] },
    { target: 'pip', property: 'rotation', keyframes: [kf(0, 1.2), kf(10, 1.2, 'hold'), kf(30, 8.2, 'ease-out'), kf(52, -3.8, EIO), kf(62, 1.2, 'ease-out'), kf(90, 1.2)] },
    // shadow reacts: widen on crouch, lighten airborne, slam on landing
    { target: 'shadow', property: 'scaleX', keyframes: [kf(0, 1), kf(10, 1.12, 'ease-in-back'), kf(30, 0.9, 'ease-out'), kf(52, 0.9, 'smooth'), kf(62, 1.16, 'emphasized-accel'), kf(90, 1, 'elastic-out')] },
    { target: 'shadow', property: 'opacity', keyframes: [kf(0, 0.13), kf(10, 0.13, 'hold'), kf(30, 0.09, 'ease-out'), kf(52, 0.09, 'smooth'), kf(62, 0.125, 'emphasized-accel'), kf(90, 0.13, 'ease-in-out')] },
    // arms up!
    { target: 'armL', property: 'rotation', keyframes: [kf(0, -16), kf(10, -16, 'hold'), kf(30, -165, 'ease-out'), kf(52, -165, 'smooth'), kf(75, -16, 'elastic-out'), kf(90, -16)] },
    { target: 'armR', property: 'rotation', keyframes: [kf(0, 12), kf(10, 12, 'hold'), kf(30, 165, 'ease-out'), kf(52, 165, 'smooth'), kf(75, 12, 'elastic-out'), kf(90, 12)] },
    // ears trail on launch, flop on landing
    { target: 'earL', property: 'rotation', keyframes: [kf(0, -2), kf(28, -12, 'ease-out'), kf(48, 3, EIO), kf(62, -4, 'ease-out'), kf(80, -2, 'ease-in-out')] },
    { target: 'earR', property: 'rotation', keyframes: [kf(0, 2), kf(28, 12, 'ease-out'), kf(48, -3, EIO), kf(62, 4, 'ease-out'), kf(80, 2, 'ease-in-out')] },
    // pennant flutters in reaction (lagged follow-through)
    { target: 'pennant', property: 'rotation', keyframes: [kf(0, 3), kf(35, -13, 'ease-out'), kf(58, 15, EIO), kf(72, -3, 'ease-out'), kf(90, 3, 'ease-in-out')] },
    // legs scissor-kick at apex
    { target: 'legL', property: 'rotation', keyframes: [kf(0, 6), kf(10, 6, 'hold'), kf(40, -7, EIO), kf(52, -7, 'smooth'), kf(70, 7, 'ease-out'), kf(90, 6)] },
    { target: 'legR', property: 'rotation', keyframes: [kf(0, -6), kf(10, -6, 'hold'), kf(40, 7, EIO), kf(52, 7, 'smooth'), kf(70, -7, 'ease-out'), kf(90, -6)] },
    // happy squint during the jump
    { target: 'eyeL', property: 'scaleY', keyframes: [kf(0, 1), kf(25, 0.55, 'ease-out'), kf(40, 0.55, 'smooth'), kf(55, 1, EIO), kf(90, 1)] },
    { target: 'eyeR', property: 'scaleY', keyframes: [kf(0, 1), kf(25, 0.55, 'ease-out'), kf(40, 0.55, 'smooth'), kf(55, 1, EIO), kf(90, 1)] },
    // excited pupil glance
    { target: 'pupilL', property: 'x', keyframes: [kf(0, 0), kf(30, 2.5, 'ease-out'), kf(50, 2.5, 'smooth'), kf(65, 0, EIO), kf(90, 0)] },
    { target: 'pupilR', property: 'x', keyframes: [kf(0, 0), kf(30, 2.5, 'ease-out'), kf(50, 2.5, 'smooth'), kf(65, 0, EIO), kf(90, 0)] },
    // grin widens at apex
    { target: 'mouthG', property: 'scaleX', keyframes: [kf(0, 1), kf(30, 1.22, 'ease-out'), kf(48, 1.22, 'smooth'), kf(62, 1, EIO), kf(90, 1)] },
    // blush flares
    { target: 'blushL', property: 'opacity', keyframes: [kf(0, 0.45), kf(30, 0.85, 'ease-out'), kf(50, 0.85, 'smooth'), kf(70, 0.45, EIO), kf(90, 0.45)] },
    { target: 'blushR', property: 'opacity', keyframes: [kf(0, 0.45), kf(30, 0.85, 'ease-out'), kf(50, 0.85, 'smooth'), kf(70, 0.45, EIO), kf(90, 0.45)] },
    // confetti burst at apex (pop out, fly, fade)
    { target: 'c1', property: 'opacity', keyframes: [kf(35, 0, 'hold'), kf(38, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c1', property: 'x', keyframes: [kf(38, -4), kf(58, -74, 'ease-out'), kf(90, -74)] },
    { target: 'c1', property: 'y', keyframes: [kf(38, 0), kf(58, -60, 'ease-out'), kf(90, -60)] },
    { target: 'c1', property: 'rotation', keyframes: [kf(38, 0), kf(58, 220, 'ease-out'), kf(90, 220)] },
    { target: 'c2', property: 'opacity', keyframes: [kf(36, 0, 'hold'), kf(39, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c2', property: 'x', keyframes: [kf(39, 6), kf(58, 86, 'ease-out'), kf(90, 86)] },
    { target: 'c2', property: 'y', keyframes: [kf(39, 4), kf(58, -45, 'ease-out'), kf(90, -45)] },
    { target: 'c2', property: 'rotation', keyframes: [kf(39, 0), kf(58, -160, 'ease-out'), kf(90, -160)] },
    { target: 'c3', property: 'opacity', keyframes: [kf(37, 0, 'hold'), kf(40, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c3', property: 'x', keyframes: [kf(40, 10), kf(58, 105, 'ease-out'), kf(90, 105)] },
    { target: 'c3', property: 'y', keyframes: [kf(40, -6), kf(58, 5, 'ease-out'), kf(90, 5)] },
    { target: 'c3', property: 'rotation', keyframes: [kf(40, 0), kf(58, 140, 'ease-out'), kf(90, 140)] },
    { target: 'c4', property: 'opacity', keyframes: [kf(38, 0, 'hold'), kf(41, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c4', property: 'x', keyframes: [kf(41, -12), kf(58, -95, 'ease-out'), kf(90, -95)] },
    { target: 'c4', property: 'y', keyframes: [kf(41, -4), kf(58, 10, 'ease-out'), kf(90, 10)] },
    { target: 'c4', property: 'rotation', keyframes: [kf(41, 0), kf(58, -200, 'ease-out'), kf(90, -200)] },
    { target: 'c5', property: 'opacity', keyframes: [kf(39, 0, 'hold'), kf(42, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c5', property: 'x', keyframes: [kf(42, 0), kf(58, 20, 'ease-out'), kf(90, 20)] },
    { target: 'c5', property: 'y', keyframes: [kf(42, -10), kf(58, -85, 'ease-out'), kf(90, -85)] },
    { target: 'c5', property: 'rotation', keyframes: [kf(42, 0), kf(58, 90, 'ease-out'), kf(90, 90)] },
    { target: 'c6', property: 'opacity', keyframes: [kf(40, 0, 'hold'), kf(43, 1, 'ease-out'), kf(58, 1, 'smooth'), kf(72, 0, 'ease-in'), kf(90, 0)] },
    { target: 'c6', property: 'x', keyframes: [kf(43, 14), kf(58, 60, 'ease-out'), kf(90, 60)] },
    { target: 'c6', property: 'y', keyframes: [kf(43, 10), kf(58, 50, 'ease-out'), kf(90, 50)] },
    { target: 'c6', property: 'rotation', keyframes: [kf(43, 0), kf(58, -120, 'ease-out'), kf(90, -120)] },
  ],
};

const scene = {
  artboard: { name: 'PipMascot', width: 512, height: 512, backgroundColor: '#00000000' },
  groups,
  shapes,
  animations: [idle, celebrate],
  stateMachine: {
    name: 'PipSM',
    inputs: [{ name: 'score', type: 'trigger' }],
    states: [
      { name: 'idleS', animation: 'idle' },
      { name: 'celebrateS', animation: 'celebrate' },
    ],
    transitions: [
      { from: 'entry', to: 'idleS' },
      { from: 'idleS', to: 'celebrateS', condition: { input: 'score', op: '==', value: true }, exitTimeMs: 80 },
      { from: 'celebrateS', to: 'idleS', exitTimeMs: 1500 },
    ],
  },
};

writeFileSync('scene.json', JSON.stringify(scene));
console.log('scene.json written:', JSON.stringify(scene).length, 'bytes;', shapes.length, 'shapes,', groups.length, 'groups,', idle.tracks.length + celebrate.tracks.length, 'tracks');
