import { BASE_BY_NAME, FPS } from "./rig-spec.mjs";

export function terminalFrame(specOrDurationSeconds) {
  const durationSeconds =
    typeof specOrDurationSeconds === "number"
      ? specOrDurationSeconds
      : specOrDurationSeconds.durationSeconds;
  return Math.round(durationSeconds * FPS);
}

const CONDITIONAL_PIVOTS = [
  "rig_diary",
  "rig_pen",
  "rig_coin_stack_l",
  "rig_coin_stack_r",
  "rig_rolling_coin",
  "rig_fx_wave",
  "rig_fx_sparkles",
  "rig_fx_writing",
  "rig_mouth_smile",
  "rig_mouth_open",
];

const ALLOWED_PROPERTIES = new Set([
  "dx",
  "dy",
  "rotationDeg",
  "scaleX",
  "scaleY",
  "opacity",
]);

const keys = (...pairs) => pairs;
const hold = (end, value) => keys([0, value], [end, value]);

function conditionalTracks(end, overrides = {}) {
  const defaults = Object.fromEntries(
    CONDITIONAL_PIVOTS.map((name) => [
      name,
      { opacity: hold(end, name === "rig_mouth_smile" ? 1 : 0) },
    ]),
  );

  for (const [name, properties] of Object.entries(overrides)) {
    defaults[name] = { ...defaults[name], ...properties };
  }
  return defaults;
}

const IDLE_END = 216;
const WAVE_END = 192;
const SALUTE_END = 144;
const DIARY_END = 156;
const SPLIT_END = 216;
const JUMP_END = 120;
const CATCH_END = 156;

/** Semantic articulation contract for the Pocket Bookkeeper v5 rig. */
export const REQUIRED_ARTICULATION_BY_SLUG = Object.freeze({
  "00_idle__breathe_blink": Object.freeze([
    "rig_root",
    "rig_head",
    "rig_eye_l",
    "rig_eye_r",
    "rig_tail",
    "rig_tail_mid",
    "rig_tail_tip",
  ]),
  "01_welcome__full_wave": Object.freeze([
    "rig_root",
    "rig_head",
    "rig_arm_l_upper",
    "rig_arm_l_fore",
    "rig_paw_l",
    "rig_tail",
    "rig_tail_mid",
    "rig_tail_tip",
  ]),
  "02_welcome_back__happy_salute": Object.freeze([
    "rig_root",
    "rig_head",
    "rig_arm_r_upper",
    "rig_arm_r_fore",
    "rig_paw_r",
    "rig_satchel",
    "rig_tail_mid",
  ]),
  "03_add_expense__write_in_diary": Object.freeze([
    "rig_head",
    "rig_arm_l_upper",
    "rig_arm_l_fore",
    "rig_paw_l",
    "rig_arm_r_upper",
    "rig_arm_r_fore",
    "rig_paw_r",
    "rig_diary",
    "rig_pen",
    "rig_tail_mid",
  ]),
  "04_split_bill__balance_and_present": Object.freeze([
    "rig_root",
    "rig_head",
    "rig_arm_l_upper",
    "rig_arm_l_fore",
    "rig_paw_l",
    "rig_arm_r_upper",
    "rig_arm_r_fore",
    "rig_paw_r",
    "rig_tail_mid",
    "rig_tail_tip",
  ]),
  "05_bills_settled__joy_jump": Object.freeze([
    "rig_root",
    "rig_leg_l",
    "rig_shin_l",
    "rig_leg_r",
    "rig_shin_r",
    "rig_foot_l",
    "rig_foot_r",
    "rig_tail",
    "rig_tail_mid",
    "rig_tail_tip",
    "rig_satchel",
  ]),
  "06_payment_error__catch_rolling_coin": Object.freeze([
    "rig_root",
    "rig_head",
    "rig_arm_r_upper",
    "rig_arm_r_fore",
    "rig_paw_r",
    "rig_rolling_coin",
    "rig_shin_l",
    "rig_shin_r",
    "rig_tail_mid",
    "rig_tail_tip",
  ]),
});

function secondaryArticulationTracks(slug, end) {
  const fifth = Math.round(end * 0.2);
  const twoFifths = Math.round(end * 0.4);
  const threeFifths = Math.round(end * 0.6);
  const fourFifths = Math.round(end * 0.8);
  const common = {
    rig_shin_l: { rotationDeg: keys([0, 0], [twoFifths, -1.5], [fourFifths, 1], [end, 0]) },
    rig_shin_r: { rotationDeg: keys([0, 0], [twoFifths, 1.5], [fourFifths, -1], [end, 0]) },
    rig_tail_mid: { rotationDeg: keys([0, 0], [fifth, -3], [twoFifths, 4], [threeFifths, -3], [fourFifths, 2], [end, 0]) },
    rig_tail_tip: { rotationDeg: keys([0, 0], [fifth, 5], [twoFifths, -6], [threeFifths, 5], [fourFifths, -3], [end, 0]) },
  };

  if (slug === "01_welcome__full_wave") {
    return {
      ...common,
      rig_tail_mid: { rotationDeg: keys([0, 0], [30, -8], [62, 10], [104, -7], [148, 5], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [36, 13], [70, -15], [112, 11], [156, -6], [end, 0]) },
    };
  }
  if (slug === "02_welcome_back__happy_salute") {
    return {
      ...common,
      rig_tail_mid: { rotationDeg: keys([0, 0], [24, 9], [54, -8], [92, 6], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [30, -12], [62, 11], [100, -7], [end, 0]) },
    };
  }
  if (slug === "03_add_expense__write_in_diary") {
    return {
      ...common,
      rig_tail_mid: { rotationDeg: keys([0, 0], [39, -2.5], [78, 2.5], [117, -2.5], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [39, 4], [78, -4], [117, 4], [end, 0]) },
    };
  }
  if (slug === "04_split_bill__balance_and_present") {
    return {
      ...common,
      rig_tail_mid: { rotationDeg: keys([0, 0], [44, -7], [94, 9], [144, -6], [188, 3], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [50, 11], [102, -13], [152, 9], [194, -4], [end, 0]) },
    };
  }
  if (slug === "05_bills_settled__joy_jump") {
    return {
      rig_shin_l: { rotationDeg: keys([0, 0], [14, 22], [34, -38], [58, -48], [82, 18], [102, -7], [end, 0]) },
      rig_shin_r: { rotationDeg: keys([0, 0], [14, -22], [34, 38], [58, 48], [82, -18], [102, 7], [end, 0]) },
      rig_tail_mid: { rotationDeg: keys([0, 0], [14, -9], [38, 18], [66, -14], [92, 8], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [18, 15], [44, -25], [70, 20], [98, -9], [end, 0]) },
    };
  }
  if (slug === "06_payment_error__catch_rolling_coin") {
    return {
      rig_shin_l: { rotationDeg: keys([0, 0], [36, -12], [68, 19], [104, -8], [end, 0]) },
      rig_shin_r: { rotationDeg: keys([0, 0], [36, 9], [68, -16], [104, 7], [end, 0]) },
      rig_tail_mid: { rotationDeg: keys([0, 0], [30, 12], [62, -16], [96, 11], [126, -5], [end, 0]) },
      rig_tail_tip: { rotationDeg: keys([0, 0], [34, -18], [68, 23], [102, -15], [132, 7], [end, 0]) },
    };
  }
  return common;
}

function performance(slug, name, durationSeconds, loop, description, tracks) {
  const endFrame = Math.round(durationSeconds * FPS);
  const articulatedTracks = { ...tracks, ...secondaryArticulationTracks(slug, endFrame) };
  return {
    slug,
    name,
    durationSeconds,
    loop,
    description,
    endpointPolicy: Object.freeze({
      mode: loop ? "seamless_loop" : "return_to_bind_pose",
      startFrame: 0,
      endFrame,
      requiresMatchingValues: true,
    }),
    requiredArticulation: REQUIRED_ARTICULATION_BY_SLUG[slug],
    motionRange: summarizeMotionRange(articulatedTracks),
    tracks: articulatedTracks,
  };
}

const idle = performance(
  "00_idle__breathe_blink",
  "00 Idle — Breathe & Blink",
  3.6,
  true,
  "A warm neutral loop with breathing, two organic blinks, ear listening, tail follow-through, and a softly shifting satchel.",
  {
    ...conditionalTracks(IDLE_END),
    rig_root: {
      dy: keys([0, 0], [54, 2], [108, 0], [162, -2], [216, 0]),
      scaleX: keys([0, 1], [54, 1.012], [108, 1], [162, 0.99], [216, 1]),
      scaleY: keys([0, 1], [54, 0.985], [108, 1], [162, 1.012], [216, 1]),
    },
    rig_head: {
      dy: keys([0, 0], [54, -1], [108, 0], [162, 1], [216, 0]),
      rotationDeg: keys([0, 0], [54, -1.2], [108, 0.5], [162, 1.1], [216, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [46, -3], [82, 2], [146, 0], [174, -7], [188, 2], [216, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [46, 2], [82, -2], [146, 0], [174, 4], [188, -1], [216, 0]),
    },
    rig_eye_l: {
      scaleY: keys([0, 1], [68, 1], [72, 0.08], [76, 1], [164, 1], [168, 0.08], [172, 1], [216, 1]),
      dx: keys([0, 0], [108, 1.5], [162, -1], [216, 0]),
    },
    rig_eye_r: {
      scaleY: keys([0, 1], [68, 1], [72, 0.08], [76, 1], [164, 1], [168, 0.08], [172, 1], [216, 1]),
      dx: keys([0, 0], [108, 1.5], [162, -1], [216, 0]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [42, 8], [92, -5], [145, 7], [188, -3], [216, 0]),
    },
    rig_satchel: {
      dy: keys([0, 0], [54, 1.5], [108, 0], [162, -1], [216, 0]),
      rotationDeg: keys([0, 0], [54, -1.8], [108, 1], [162, 1.6], [216, 0]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [54, 1.8], [108, 0], [162, -1.2], [216, 0]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [54, -1.8], [108, 0], [162, 1.2], [216, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [72, -1.5], [144, 1.2], [216, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [72, 1.5], [144, -1.2], [216, 0]),
    },
    rig_leg_l: {
      scaleY: keys([0, 1], [54, 0.988], [108, 1], [162, 1.008], [216, 1]),
    },
    rig_leg_r: {
      scaleY: keys([0, 1], [54, 0.988], [108, 1], [162, 1.008], [216, 1]),
    },
    rig_foot_l: {
      rotationDeg: keys([0, 0], [80, -1.5], [154, 1], [216, 0]),
    },
    rig_foot_r: {
      rotationDeg: keys([0, 0], [80, 1.5], [154, -1], [216, 0]),
    },
  },
);

const wave = performance(
  "01_welcome__full_wave",
  "01 Welcome — Full Wave",
  3.2,
  false,
  "A first-time greeting: eyes notice the guest, the body anticipates, the left arm lifts through shoulder and elbow, the paw waves three times, and the whole character settles home.",
  {
    ...conditionalTracks(WAVE_END, {
      rig_fx_wave: {
        opacity: keys([0, 0], [42, 0], [50, 1], [142, 1], [154, 0], [192, 0]),
        scaleX: keys([0, 0.72], [50, 0.72], [64, 1.08], [142, 1], [192, 0.72]),
        scaleY: keys([0, 0.72], [50, 0.72], [64, 1.08], [142, 1], [192, 0.72]),
        rotationDeg: keys([0, 0], [64, -5], [104, 5], [142, 0], [192, 0]),
      },
      rig_mouth_smile: {
        opacity: keys([0, 1], [22, 1], [28, 0], [148, 0], [158, 1], [192, 1]),
      },
      rig_mouth_open: {
        opacity: keys([0, 0], [22, 0], [28, 1], [148, 1], [158, 0], [192, 0]),
        scaleY: keys([0, 0.75], [30, 0.75], [48, 1.12], [92, 0.94], [138, 1.08], [158, 0.75], [192, 0.75]),
      },
    }),
    rig_root: {
      dx: keys([0, 0], [16, -5], [30, 4], [52, 1], [146, 1], [164, -3], [180, 1], [192, 0]),
      dy: keys([0, 0], [16, 4], [30, -7], [52, -3], [146, -3], [164, 3], [180, -1], [192, 0]),
      rotationDeg: keys([0, 0], [16, -2], [30, 2], [64, 1], [146, 1], [164, -1.5], [192, 0]),
      scaleX: keys([0, 1], [16, 1.05], [30, 0.98], [52, 1], [164, 1.035], [180, 0.99], [192, 1]),
      scaleY: keys([0, 1], [16, 0.94], [30, 1.05], [52, 1], [164, 0.965], [180, 1.015], [192, 1]),
    },
    rig_head: {
      dx: keys([0, 0], [12, -3], [28, -1], [52, -2], [146, -2], [170, 1], [192, 0]),
      dy: keys([0, 0], [16, 2], [30, -3], [64, -2], [146, -2], [170, 1], [192, 0]),
      rotationDeg: keys([0, 0], [14, -5], [30, 4], [52, -7], [146, -6], [166, 3], [192, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [22, -9], [38, 5], [58, -5], [104, 4], [146, -3], [170, 5], [192, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [22, 6], [38, -3], [58, 3], [104, -3], [146, 2], [170, -4], [192, 0]),
    },
    rig_eye_l: {
      dx: keys([0, 0], [10, -2.5], [30, 0], [146, 0], [192, 0]),
      scaleY: keys([0, 1], [18, 1], [21, 0.08], [25, 1], [112, 1], [116, 0.12], [120, 1], [192, 1]),
    },
    rig_eye_r: {
      dx: keys([0, 0], [10, -2.5], [30, 0], [146, 0], [192, 0]),
      scaleY: keys([0, 1], [18, 1], [21, 0.08], [25, 1], [112, 1], [116, 0.12], [120, 1], [192, 1]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [16, 10], [30, 58], [46, 108], [146, 108], [160, 86], [176, 34], [192, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [26, -8], [46, 34], [58, 15], [74, 34], [90, 13], [106, 35], [122, 14], [138, 31], [150, 18], [176, -4], [192, 0]),
    },
    rig_paw_l: {
      rotationDeg: keys([0, 0], [46, -16], [58, 22], [74, -23], [90, 23], [106, -23], [122, 22], [138, -18], [150, 10], [176, 2], [192, 0]),
      scaleX: keys([0, 1], [50, 1.05], [66, 0.97], [82, 1.05], [98, 0.97], [114, 1.05], [138, 1], [192, 1]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [30, -8], [70, -4], [146, -5], [170, 3], [192, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [30, 8], [70, 3], [146, 5], [170, -2], [192, 0]),
    },
    rig_paw_r: {
      rotationDeg: keys([0, 0], [30, 4], [88, -3], [146, 3], [192, 0]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [18, -10], [40, 18], [66, -8], [94, 18], [122, -6], [148, 15], [174, -5], [192, 0]),
    },
    rig_satchel: {
      dx: keys([0, 0], [28, -2], [60, 2], [146, 2], [170, -1], [192, 0]),
      dy: keys([0, 0], [30, 3], [62, -2], [146, -2], [170, 2], [192, 0]),
      rotationDeg: keys([0, 0], [24, -8], [54, 7], [88, -4], [122, 5], [150, -3], [174, 2], [192, 0]),
    },
    rig_leg_l: {
      rotationDeg: keys([0, 0], [16, -5], [30, 3], [146, 2], [164, -3], [192, 0]),
      scaleY: keys([0, 1], [16, 0.92], [30, 1.04], [52, 1], [164, 0.96], [192, 1]),
    },
    rig_leg_r: {
      rotationDeg: keys([0, 0], [16, 5], [30, -3], [146, -2], [164, 3], [192, 0]),
      scaleY: keys([0, 1], [16, 0.92], [30, 1.04], [52, 1], [164, 0.96], [192, 1]),
    },
    rig_foot_l: {
      rotationDeg: keys([0, 0], [18, -7], [34, 4], [146, 2], [166, -4], [192, 0]),
    },
    rig_foot_r: {
      rotationDeg: keys([0, 0], [18, 7], [34, -4], [146, -2], [166, 4], [192, 0]),
    },
  },
);

const salute = performance(
  "02_welcome_back__happy_salute",
  "02 Welcome Back — Happy Salute",
  2.4,
  false,
  "A familiar returning-user greeting: quick recognition bounce, right-paw salute and wink, a proud satchel pat, then a friendly reset.",
  {
    ...conditionalTracks(SALUTE_END, {
      rig_fx_sparkles: {
        opacity: keys([0, 0], [30, 0], [38, 1], [72, 1], [84, 0], [144, 0]),
        rotationDeg: keys([0, 0], [38, -8], [60, 8], [84, 0], [144, 0]),
        scaleX: keys([0, 0.7], [38, 0.7], [52, 1.18], [72, 1], [144, 0.7]),
        scaleY: keys([0, 0.7], [38, 0.7], [52, 1.18], [72, 1], [144, 0.7]),
      },
      rig_mouth_smile: {
        opacity: keys([0, 1], [24, 1], [30, 0], [88, 0], [96, 1], [144, 1]),
      },
      rig_mouth_open: {
        opacity: keys([0, 0], [24, 0], [30, 1], [88, 1], [96, 0], [144, 0]),
        scaleY: keys([0, 0.8], [30, 0.8], [50, 1.08], [80, 0.9], [96, 0.8], [144, 0.8]),
      },
    }),
    rig_root: {
      dx: keys([0, 0], [12, 3], [24, -2], [40, 1], [92, 1], [108, -3], [126, 1], [144, 0]),
      dy: keys([0, 0], [12, 4], [24, -8], [40, -3], [92, -3], [108, 2], [126, -1], [144, 0]),
      rotationDeg: keys([0, 0], [12, 2], [24, -2], [44, 1], [92, 1], [108, -2], [144, 0]),
      scaleX: keys([0, 1], [12, 1.045], [24, 0.98], [40, 1], [108, 1.025], [126, 0.99], [144, 1]),
      scaleY: keys([0, 1], [12, 0.945], [24, 1.055], [40, 1], [108, 0.975], [126, 1.012], [144, 1]),
    },
    rig_head: {
      dx: keys([0, 0], [10, 2], [24, 0], [42, 3], [82, 3], [104, -1], [144, 0]),
      dy: keys([0, 0], [12, 2], [24, -3], [42, -2], [82, -2], [108, 1], [144, 0]),
      rotationDeg: keys([0, 0], [14, 5], [28, -4], [44, 7], [82, 6], [104, -3], [144, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [20, -7], [36, 5], [60, -3], [88, 4], [112, -2], [144, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [20, 9], [36, -5], [60, 4], [88, -5], [112, 3], [144, 0]),
    },
    rig_eye_l: {
      dx: keys([0, 0], [12, 2], [30, 0], [82, 0], [144, 0]),
      scaleY: keys([0, 1], [96, 1], [100, 0.12], [104, 1], [144, 1]),
    },
    rig_eye_r: {
      dx: keys([0, 0], [12, 2], [30, 0], [82, 0], [144, 0]),
      scaleY: keys([0, 1], [36, 1], [40, 0.06], [72, 0.06], [78, 1], [96, 1], [100, 0.12], [104, 1], [144, 1]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [16, -22], [30, -76], [44, -112], [76, -108], [90, -52], [104, -18], [118, -8], [144, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [22, 18], [38, -32], [52, -48], [76, -42], [90, 20], [104, 46], [118, 12], [144, 0]),
    },
    rig_paw_r: {
      rotationDeg: keys([0, 0], [38, 12], [50, -10], [62, 9], [76, -5], [92, 18], [104, -12], [118, 4], [144, 0]),
      scaleX: keys([0, 1], [44, 1.08], [76, 1.04], [104, 0.98], [144, 1]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [22, 8], [54, 4], [90, 12], [108, 6], [126, -2], [144, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [22, -8], [54, -4], [90, -16], [108, -5], [144, 0]),
    },
    rig_paw_l: {
      rotationDeg: keys([0, 0], [28, -5], [76, 3], [104, -4], [144, 0]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [14, -12], [32, 20], [54, -9], [78, 18], [104, -6], [126, 8], [144, 0]),
    },
    rig_satchel: {
      dx: keys([0, 0], [24, -2], [54, 2], [88, -1], [104, 3], [118, -2], [144, 0]),
      dy: keys([0, 0], [24, 3], [54, -2], [88, 1], [104, -3], [118, 2], [144, 0]),
      rotationDeg: keys([0, 0], [22, -8], [48, 8], [76, -4], [96, 6], [110, -7], [126, 3], [144, 0]),
      scaleX: keys([0, 1], [88, 1], [100, 1.08], [110, 0.96], [124, 1.02], [144, 1]),
      scaleY: keys([0, 1], [88, 1], [100, 0.93], [110, 1.04], [124, 0.99], [144, 1]),
    },
    rig_leg_l: {
      scaleY: keys([0, 1], [12, 0.91], [24, 1.05], [40, 1], [108, 0.97], [144, 1]),
      rotationDeg: keys([0, 0], [12, -4], [24, 3], [108, -2], [144, 0]),
    },
    rig_leg_r: {
      scaleY: keys([0, 1], [12, 0.91], [24, 1.05], [40, 1], [108, 0.97], [144, 1]),
      rotationDeg: keys([0, 0], [12, 4], [24, -3], [108, 2], [144, 0]),
    },
    rig_foot_l: {
      rotationDeg: keys([0, 0], [14, -6], [28, 4], [110, -3], [144, 0]),
    },
    rig_foot_r: {
      rotationDeg: keys([0, 0], [14, 6], [28, -4], [110, 3], [144, 0]),
    },
  },
);

const diary = performance(
  "03_add_expense__write_in_diary",
  "03 Add Expense — Write in Diary",
  2.6,
  true,
  "A focused note-taking loop: the diary is held steady, the pen makes three readable strokes with lifts, the eyes scan the line, then Tally adds a small confirming flourish and nod.",
  {
    ...conditionalTracks(DIARY_END, {
      rig_diary: {
        opacity: hold(DIARY_END, 1),
        dx: keys([0, 0], [26, -1], [52, 1], [78, -1], [104, 1], [130, -1], [156, 0]),
        dy: keys([0, 0], [39, 1], [78, 0], [117, -1], [156, 0]),
        rotationDeg: keys([0, -2], [39, -1], [78, -2.6], [117, -1], [156, -2]),
      },
      rig_pen: {
        opacity: hold(DIARY_END, 1),
        dx: keys([0, 0], [18, 2], [34, -3], [48, 4], [60, 0], [76, 3], [92, -3], [106, 4], [118, 0], [132, 3], [144, -2], [156, 0]),
        dy: keys([0, 0], [18, 5], [34, 8], [48, 4], [60, -3], [76, 5], [92, 8], [106, 4], [118, -3], [132, 5], [144, 7], [156, 0]),
        rotationDeg: keys([0, 0], [18, -7], [34, 8], [48, -5], [60, 10], [76, -6], [92, 8], [106, -5], [118, 12], [132, -9], [144, 6], [156, 0]),
      },
      rig_fx_writing: {
        opacity: keys([0, 0], [16, 0], [22, 1], [48, 1], [56, 0], [72, 0], [78, 1], [106, 1], [114, 0], [128, 0], [134, 1], [146, 1], [152, 0], [156, 0]),
        dx: keys([0, 0], [22, -8], [48, 8], [78, -6], [106, 9], [134, -4], [146, 10], [156, 0]),
        dy: keys([0, 0], [48, 2], [78, 7], [106, 9], [134, 13], [146, 15], [156, 0]),
        scaleX: keys([0, 0.65], [22, 0.65], [48, 1.05], [78, 0.65], [106, 1.05], [134, 0.7], [146, 1.08], [156, 0.65]),
      },
    }),
    rig_root: {
      dx: keys([0, -5], [39, -4], [78, -6], [117, -4], [156, -5]),
      dy: keys([0, 4], [39, 5], [78, 3], [117, 5], [156, 4]),
      rotationDeg: keys([0, -2], [39, -1], [78, -2.5], [117, -1], [156, -2]),
      scaleY: keys([0, 0.985], [39, 0.975], [78, 0.99], [117, 0.975], [156, 0.985]),
    },
    rig_head: {
      dx: keys([0, 2], [26, -2], [52, 2], [78, -2], [104, 2], [130, -1], [156, 2]),
      dy: keys([0, 5], [39, 7], [78, 5], [117, 7], [156, 5]),
      rotationDeg: keys([0, 7], [26, 5], [52, 8], [78, 5], [104, 8], [130, 5], [156, 7]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, -3], [34, -5], [60, 1], [86, -4], [112, 2], [138, -4], [156, -3]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 2], [34, 4], [60, -2], [86, 3], [112, -2], [138, 3], [156, 2]),
    },
    rig_eye_l: {
      dx: keys([0, -3], [24, 2], [50, -2], [76, 2], [102, -2], [128, 2], [156, -3]),
      dy: keys([0, 3], [52, 4], [104, 3], [156, 3]),
      scaleY: keys([0, 0.9], [62, 0.9], [66, 0.08], [70, 0.9], [142, 0.9], [146, 0.12], [150, 0.9], [156, 0.9]),
    },
    rig_eye_r: {
      dx: keys([0, -3], [24, 2], [50, -2], [76, 2], [102, -2], [128, 2], [156, -3]),
      dy: keys([0, 3], [52, 4], [104, 3], [156, 3]),
      scaleY: keys([0, 0.9], [62, 0.9], [66, 0.08], [70, 0.9], [142, 0.9], [146, 0.12], [150, 0.9], [156, 0.9]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, -38], [39, -36], [78, -40], [117, -36], [156, -38]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 54], [39, 52], [78, 56], [117, 52], [156, 54]),
    },
    rig_paw_l: {
      dx: keys([0, 0], [39, -1], [78, 1], [117, -1], [156, 0]),
      dy: keys([0, -3], [39, -2], [78, -4], [117, -2], [156, -3]),
      rotationDeg: keys([0, 8], [39, 5], [78, 9], [117, 5], [156, 8]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 42], [18, 44], [34, 39], [48, 45], [60, 37], [76, 44], [92, 39], [106, 45], [118, 37], [132, 45], [144, 40], [156, 42]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, -65], [18, -58], [34, -72], [48, -57], [60, -48], [76, -59], [92, -73], [106, -57], [118, -47], [132, -60], [144, -71], [156, -65]),
    },
    rig_paw_r: {
      dx: keys([0, 0], [18, 3], [34, -4], [48, 4], [60, -1], [76, 3], [92, -4], [106, 4], [118, -1], [132, 3], [144, -3], [156, 0]),
      dy: keys([0, -1], [18, 3], [34, 6], [48, 2], [60, -4], [76, 3], [92, 6], [106, 2], [118, -4], [132, 3], [144, 5], [156, -1]),
      rotationDeg: keys([0, -8], [18, -14], [34, 5], [48, -12], [60, 8], [76, -13], [92, 5], [106, -12], [118, 9], [132, -15], [144, 4], [156, -8]),
    },
    rig_tail: {
      rotationDeg: keys([0, -5], [39, 2], [78, -8], [117, 3], [156, -5]),
    },
    rig_satchel: {
      dx: keys([0, 1], [39, 0], [78, 2], [117, 0], [156, 1]),
      dy: keys([0, 2], [39, 3], [78, 1], [117, 3], [156, 2]),
      rotationDeg: keys([0, 2], [39, -1], [78, 3], [117, -1], [156, 2]),
    },
    rig_leg_l: {
      rotationDeg: keys([0, -2], [39, -1], [78, -3], [117, -1], [156, -2]),
      scaleY: keys([0, 0.98], [39, 0.97], [78, 0.985], [117, 0.97], [156, 0.98]),
    },
    rig_leg_r: {
      rotationDeg: keys([0, 2], [39, 1], [78, 3], [117, 1], [156, 2]),
      scaleY: keys([0, 0.98], [39, 0.97], [78, 0.985], [117, 0.97], [156, 0.98]),
    },
    rig_foot_l: {
      rotationDeg: keys([0, -2], [52, -1], [104, -3], [156, -2]),
    },
    rig_foot_r: {
      rotationDeg: keys([0, 2], [52, 1], [104, 3], [156, 2]),
    },
  },
);

const split = performance(
  "04_split_bill__balance_and_present",
  "04 Split Bill — Balance & Present",
  3.6,
  false,
  "Tally compares an uneven split, tracks a coin moving from the heavy side to the light side, watches both stacks become equal, then proudly presents the fair result.",
  {
    ...conditionalTracks(SPLIT_END, {
      rig_coin_stack_l: {
        opacity: keys([0, 0], [14, 0], [22, 1], [196, 1], [208, 0], [216, 0]),
        dx: keys([0, 0], [22, 0], [54, -5], [84, -2], [112, 0], [154, -4], [190, 0], [216, 0]),
        dy: keys([0, 0], [22, -13], [72, -13], [112, 0], [154, -4], [190, 0], [216, 0]),
        scaleX: keys([0, 1], [22, 1.2], [72, 1.2], [112, 1], [154, 1.05], [190, 1], [216, 1]),
        scaleY: keys([0, 1], [22, 1.2], [72, 1.2], [112, 1], [154, 1.05], [190, 1], [216, 1]),
        rotationDeg: keys([0, 0], [22, -3], [72, -3], [112, 0], [154, -2], [190, 0], [216, 0]),
      },
      rig_coin_stack_r: {
        opacity: keys([0, 0], [14, 0], [22, 1], [196, 1], [208, 0], [216, 0]),
        dx: keys([0, 0], [22, 0], [54, 5], [84, 2], [112, 0], [154, 4], [190, 0], [216, 0]),
        dy: keys([0, 0], [22, 13], [72, 13], [112, 0], [154, -4], [190, 0], [216, 0]),
        scaleX: keys([0, 1], [22, 0.78], [72, 0.78], [112, 1], [154, 1.05], [190, 1], [216, 1]),
        scaleY: keys([0, 1], [22, 0.78], [72, 0.78], [112, 1], [154, 1.05], [190, 1], [216, 1]),
        rotationDeg: keys([0, 0], [22, 3], [72, 3], [112, 0], [154, 2], [190, 0], [216, 0]),
      },
      rig_rolling_coin: {
        opacity: keys([0, 0], [62, 0], [66, 1], [108, 1], [112, 0], [216, 0]),
        dx: keys([0, 0], [62, 52], [66, 52], [88, 144], [108, 236], [112, 236], [216, 0]),
        dy: keys([0, 0], [62, -152], [72, -166], [88, -176], [104, -165], [112, -152], [216, 0]),
        rotationDeg: keys([0, 0], [66, 0], [88, 180], [108, 360], [112, 390], [216, 0]),
        scaleX: keys([0, 0.82], [66, 0.82], [88, 1.08], [108, 0.82], [216, 0.82]),
        scaleY: keys([0, 0.82], [66, 0.82], [88, 1.08], [108, 0.82], [216, 0.82]),
      },
      rig_fx_sparkles: {
        opacity: keys([0, 0], [112, 0], [122, 1], [176, 1], [188, 0], [216, 0]),
        scaleX: keys([0, 0.65], [122, 0.65], [140, 1.16], [176, 1], [216, 0.65]),
        scaleY: keys([0, 0.65], [122, 0.65], [140, 1.16], [176, 1], [216, 0.65]),
        rotationDeg: keys([0, 0], [122, -10], [148, 8], [176, 0], [216, 0]),
      },
      rig_mouth_smile: {
        opacity: keys([0, 1], [50, 1], [58, 0], [104, 0], [112, 1], [216, 1]),
      },
      rig_mouth_open: {
        opacity: keys([0, 0], [50, 0], [58, 1], [104, 1], [112, 0], [216, 0]),
        scaleY: keys([0, 0.75], [58, 0.75], [82, 1.05], [104, 0.85], [112, 0.75], [216, 0.75]),
      },
    }),
    rig_root: {
      dx: keys([0, 0], [20, -3], [48, -8], [72, 7], [104, 0], [124, 0], [148, 0], [172, 0], [196, -2], [216, 0]),
      dy: keys([0, 0], [20, 3], [48, 1], [72, 1], [104, 0], [124, 4], [148, -8], [172, -3], [196, 2], [216, 0]),
      rotationDeg: keys([0, 0], [20, -2], [48, -4], [72, 4], [104, 0], [124, 0], [148, 1], [172, -1], [196, 1], [216, 0]),
      scaleX: keys([0, 1], [20, 1.03], [48, 1], [104, 1], [124, 1.06], [148, 0.97], [172, 1.01], [216, 1]),
      scaleY: keys([0, 1], [20, 0.96], [48, 1], [104, 1], [124, 0.94], [148, 1.06], [172, 0.99], [216, 1]),
    },
    rig_head: {
      dx: keys([0, 0], [18, -3], [42, -8], [68, 8], [96, 0], [122, 0], [148, 0], [176, 0], [200, 1], [216, 0]),
      dy: keys([0, 0], [20, 2], [48, 3], [72, 3], [104, 0], [124, 3], [148, -3], [176, -1], [216, 0]),
      rotationDeg: keys([0, 0], [20, -4], [48, -9], [72, 9], [104, 0], [124, -3], [148, 5], [176, -2], [200, 2], [216, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [28, -8], [54, 3], [78, -5], [104, 1], [132, -4], [152, 7], [178, -3], [216, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [28, 5], [54, -3], [78, 8], [104, -1], [132, 4], [152, -7], [178, 3], [216, 0]),
    },
    rig_eye_l: {
      dx: keys([0, 0], [24, -4], [54, -4], [70, 4], [94, 4], [112, 0], [216, 0]),
      dy: keys([0, 0], [24, -1], [94, -1], [112, 0], [216, 0]),
      scaleY: keys([0, 1], [116, 1], [120, 0.08], [124, 1], [216, 1]),
    },
    rig_eye_r: {
      dx: keys([0, 0], [24, -4], [54, -4], [70, 4], [94, 4], [112, 0], [216, 0]),
      dy: keys([0, 0], [24, -1], [94, -1], [112, 0], [216, 0]),
      scaleY: keys([0, 1], [116, 1], [120, 0.08], [124, 1], [216, 1]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [18, 28], [34, 72], [74, 58], [108, 46], [126, 72], [154, 88], [178, 64], [196, 28], [216, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [28, -18], [44, 22], [74, 14], [108, 28], [126, 14], [154, 4], [178, 18], [216, 0]),
    },
    rig_paw_l: {
      rotationDeg: keys([0, 0], [34, -8], [54, 8], [74, -4], [108, 2], [132, -8], [154, 6], [178, -3], [216, 0]),
      scaleX: keys([0, 1], [34, 1.05], [108, 1], [154, 1.08], [178, 1], [216, 1]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [18, -28], [34, -44], [74, -72], [108, -46], [126, -72], [154, -88], [178, -64], [196, -28], [216, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [28, 18], [44, -8], [74, -22], [108, -28], [126, -14], [154, -4], [178, -18], [216, 0]),
    },
    rig_paw_r: {
      rotationDeg: keys([0, 0], [34, 8], [54, -8], [74, 4], [108, -2], [132, 8], [154, -6], [178, 3], [216, 0]),
      scaleX: keys([0, 1], [34, 0.9], [108, 1], [154, 1.08], [178, 1], [216, 1]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [18, -8], [42, 15], [70, -10], [102, 12], [128, -8], [154, 18], [182, -6], [216, 0]),
    },
    rig_satchel: {
      dx: keys([0, 0], [28, -3], [58, 2], [88, -2], [118, 2], [148, -2], [178, 1], [216, 0]),
      dy: keys([0, 0], [28, 3], [58, -2], [88, 2], [118, -2], [148, 2], [178, -1], [216, 0]),
      rotationDeg: keys([0, 0], [28, -8], [58, 7], [88, -5], [118, 5], [148, -7], [178, 3], [216, 0]),
    },
    rig_leg_l: {
      rotationDeg: keys([0, 0], [48, -3], [72, 3], [124, -4], [148, 4], [196, -2], [216, 0]),
      scaleY: keys([0, 1], [124, 0.94], [148, 1.05], [178, 0.99], [216, 1]),
    },
    rig_leg_r: {
      rotationDeg: keys([0, 0], [48, 3], [72, -3], [124, 4], [148, -4], [196, 2], [216, 0]),
      scaleY: keys([0, 1], [124, 0.94], [148, 1.05], [178, 0.99], [216, 1]),
    },
    rig_foot_l: {
      rotationDeg: keys([0, 0], [48, -4], [72, 3], [128, -7], [152, 6], [196, -2], [216, 0]),
    },
    rig_foot_r: {
      rotationDeg: keys([0, 0], [48, 4], [72, -3], [128, 7], [152, -6], [196, 2], [216, 0]),
    },
  },
);

const jump = performance(
  "05_bills_settled__joy_jump",
  "05 Bills Settled — Joy Jump",
  2.0,
  false,
  "A full-body success beat: anticipation squash, 82-pixel launch, tucked legs and raised paws, joyful open mouth and sparkles at apex, delayed tail and satchel follow-through, then a soft landing and rebound.",
  {
    ...conditionalTracks(JUMP_END, {
      rig_fx_sparkles: {
        opacity: keys([0, 0], [24, 0], [34, 1], [70, 1], [82, 0], [120, 0]),
        dx: keys([0, 0], [34, 0], [52, 8], [70, -3], [120, 0]),
        dy: keys([0, 0], [34, -8], [52, -18], [70, -10], [120, 0]),
        rotationDeg: keys([0, 0], [34, -15], [52, 12], [70, -6], [120, 0]),
        scaleX: keys([0, 0.6], [34, 0.6], [48, 1.25], [70, 1], [120, 0.6]),
        scaleY: keys([0, 0.6], [34, 0.6], [48, 1.25], [70, 1], [120, 0.6]),
      },
      rig_mouth_smile: {
        opacity: keys([0, 1], [20, 1], [28, 0], [78, 0], [88, 1], [120, 1]),
      },
      rig_mouth_open: {
        opacity: keys([0, 0], [20, 0], [28, 1], [78, 1], [88, 0], [120, 0]),
        scaleX: keys([0, 0.8], [28, 0.8], [48, 1.15], [64, 1.05], [88, 0.8], [120, 0.8]),
        scaleY: keys([0, 0.7], [28, 0.7], [48, 1.22], [64, 1.05], [88, 0.7], [120, 0.7]),
      },
    }),
    rig_root: {
      dx: keys([0, 0], [14, -2], [28, 2], [48, 0], [64, 0], [82, 1], [92, -2], [106, 1], [120, 0]),
      dy: keys([0, 0], [14, 8], [28, -34], [44, -76], [52, -82], [62, -82], [76, -58], [88, 8], [98, -10], [108, 2], [120, 0]),
      rotationDeg: keys([0, 0], [14, -2], [28, 3], [52, -2], [76, 2], [88, -2], [98, 1.5], [120, 0]),
      scaleX: keys([0, 1], [14, 1.12], [28, 0.92], [44, 0.96], [62, 1], [76, 0.98], [88, 1.14], [98, 0.95], [108, 1.025], [120, 1]),
      scaleY: keys([0, 1], [14, 0.83], [28, 1.12], [44, 1.05], [62, 1], [76, 1.04], [88, 0.82], [98, 1.08], [108, 0.98], [120, 1]),
    },
    rig_head: {
      dx: keys([0, 0], [14, -1], [30, 2], [46, -1], [64, 1], [84, 0], [92, -1], [120, 0]),
      dy: keys([0, 0], [14, 4], [30, 6], [46, 0], [62, -4], [78, 3], [88, -5], [98, 3], [120, 0]),
      rotationDeg: keys([0, 0], [14, -4], [30, 6], [48, -4], [64, 3], [80, -3], [90, 5], [102, -2], [120, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [14, -10], [30, 10], [46, -12], [62, 7], [78, -8], [90, 11], [104, -4], [120, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [14, 10], [30, -10], [46, 12], [62, -7], [78, 8], [90, -11], [104, 4], [120, 0]),
    },
    rig_eye_l: {
      scaleX: keys([0, 1], [24, 1], [42, 1.16], [68, 1.12], [84, 1], [120, 1]),
      scaleY: keys([0, 1], [24, 1], [42, 1.22], [68, 1.14], [84, 1], [90, 1], [94, 0.08], [98, 1], [120, 1]),
    },
    rig_eye_r: {
      scaleX: keys([0, 1], [24, 1], [42, 1.16], [68, 1.12], [84, 1], [120, 1]),
      scaleY: keys([0, 1], [24, 1], [42, 1.22], [68, 1.14], [84, 1], [90, 1], [94, 0.08], [98, 1], [120, 1]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [14, -12], [28, 70], [44, 122], [66, 116], [80, 76], [90, 18], [102, -8], [120, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [14, 18], [28, 38], [44, 12], [66, 22], [80, 36], [90, 10], [104, -5], [120, 0]),
    },
    rig_paw_l: {
      rotationDeg: keys([0, 0], [28, -12], [44, 12], [56, -8], [68, 10], [82, -4], [94, 5], [120, 0]),
      scaleX: keys([0, 1], [44, 1.12], [68, 1.06], [88, 0.98], [120, 1]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [14, 12], [28, -70], [44, -122], [66, -116], [80, -76], [90, -18], [102, 8], [120, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [14, -18], [28, -38], [44, -12], [66, -22], [80, -36], [90, -10], [104, 5], [120, 0]),
    },
    rig_paw_r: {
      rotationDeg: keys([0, 0], [28, 12], [44, -12], [56, 8], [68, -10], [82, 4], [94, -5], [120, 0]),
      scaleX: keys([0, 1], [44, 1.12], [68, 1.06], [88, 0.98], [120, 1]),
    },
    rig_leg_l: {
      rotationDeg: keys([0, 0], [14, -10], [28, 28], [44, 48], [66, 42], [80, 24], [88, -12], [100, 6], [120, 0]),
      scaleY: keys([0, 1], [14, 0.82], [28, 0.9], [52, 0.76], [72, 0.82], [88, 0.8], [100, 1.07], [120, 1]),
    },
    rig_leg_r: {
      rotationDeg: keys([0, 0], [14, 10], [28, -28], [44, -48], [66, -42], [80, -24], [88, 12], [100, -6], [120, 0]),
      scaleY: keys([0, 1], [14, 0.82], [28, 0.9], [52, 0.76], [72, 0.82], [88, 0.8], [100, 1.07], [120, 1]),
    },
    rig_foot_l: {
      dx: keys([0, 0], [14, -3], [44, -8], [66, -5], [88, -4], [100, 2], [120, 0]),
      dy: keys([0, 0], [14, 4], [44, -8], [66, -6], [88, 5], [100, -2], [120, 0]),
      rotationDeg: keys([0, 0], [14, -12], [44, 34], [66, 28], [88, -18], [100, 8], [120, 0]),
    },
    rig_foot_r: {
      dx: keys([0, 0], [14, 3], [44, 8], [66, 5], [88, 4], [100, -2], [120, 0]),
      dy: keys([0, 0], [14, 4], [44, -8], [66, -6], [88, 5], [100, -2], [120, 0]),
      rotationDeg: keys([0, 0], [14, 12], [44, -34], [66, -28], [88, 18], [100, -8], [120, 0]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [14, -16], [30, 28], [48, -18], [66, 22], [82, -20], [94, 24], [108, -8], [120, 0]),
      scaleX: keys([0, 1], [30, 1.06], [54, 0.96], [82, 1.04], [120, 1]),
    },
    rig_satchel: {
      dx: keys([0, 0], [14, -2], [30, 7], [48, -6], [66, 5], [82, -4], [94, 5], [108, -2], [120, 0]),
      dy: keys([0, 0], [14, 5], [30, 14], [48, 22], [66, 8], [82, 18], [94, -4], [108, 3], [120, 0]),
      rotationDeg: keys([0, 0], [14, -8], [30, 18], [48, -24], [66, 16], [82, -18], [94, 14], [108, -5], [120, 0]),
    },
  },
);

const catchCoin = performance(
  "06_payment_error__catch_rolling_coin",
  "06 Payment Error — Catch Rolling Coin",
  2.6,
  false,
  "A recoverable-error performance: a coin rolls across more than 200 pixels, Tally notices it, shifts weight, reaches with the right shoulder-elbow-paw chain, catches it with a compressed contact beat, and resets reassuringly.",
  {
    ...conditionalTracks(CATCH_END, {
      rig_rolling_coin: {
        opacity: keys([0, 0], [8, 0], [12, 1], [112, 1], [116, 0], [156, 0]),
        dx: keys([0, 0], [12, 0], [36, 48], [64, 112], [88, 176], [108, 226], [116, 236], [156, 0]),
        dy: keys([0, 0], [12, 0], [32, -4], [50, 1], [70, -3], [88, 1], [108, -6], [116, -4], [156, 0]),
        rotationDeg: keys([0, 0], [12, 0], [36, 120], [64, 290], [88, 450], [108, 600], [116, 660], [156, 0]),
        scaleX: keys([0, 1], [12, 1], [36, 0.92], [64, 1.04], [88, 0.94], [108, 1.1], [116, 0.85], [156, 1]),
        scaleY: keys([0, 1], [12, 1], [36, 1.08], [64, 0.96], [88, 1.06], [108, 0.9], [116, 1.15], [156, 1]),
      },
      rig_mouth_smile: {
        opacity: keys([0, 1], [28, 1], [34, 0], [116, 0], [124, 1], [156, 1]),
      },
      rig_mouth_open: {
        opacity: keys([0, 0], [28, 0], [34, 1], [116, 1], [124, 0], [156, 0]),
        scaleX: keys([0, 0.8], [34, 0.8], [60, 1.08], [92, 0.92], [112, 1.15], [124, 0.8], [156, 0.8]),
        scaleY: keys([0, 0.72], [34, 0.72], [60, 1.14], [92, 0.86], [112, 1.2], [124, 0.72], [156, 0.72]),
      },
      rig_fx_sparkles: {
        opacity: keys([0, 0], [106, 0], [112, 1], [126, 1], [136, 0], [156, 0]),
        dx: keys([0, 0], [112, -18], [126, -8], [156, 0]),
        dy: keys([0, 0], [112, 32], [126, 20], [156, 0]),
        scaleX: keys([0, 0.65], [112, 0.65], [122, 1.12], [136, 0.8], [156, 0.65]),
        scaleY: keys([0, 0.65], [112, 0.65], [122, 1.12], [136, 0.8], [156, 0.65]),
      },
    }),
    rig_root: {
      dx: keys([0, 0], [20, -3], [36, 3], [56, 8], [76, 14], [96, 22], [108, 26], [116, 18], [128, -4], [142, 2], [156, 0]),
      dy: keys([0, 0], [20, 2], [36, 5], [56, 8], [76, 12], [96, 16], [108, 20], [116, 14], [128, 5], [142, -1], [156, 0]),
      rotationDeg: keys([0, 0], [20, -2], [36, 2], [56, 5], [76, 8], [96, 12], [108, 15], [116, 10], [128, -3], [142, 2], [156, 0]),
      scaleX: keys([0, 1], [36, 1.02], [76, 1.06], [108, 1.11], [116, 1.05], [128, 0.98], [142, 1.02], [156, 1]),
      scaleY: keys([0, 1], [36, 0.98], [76, 0.93], [108, 0.86], [116, 0.93], [128, 1.05], [142, 0.99], [156, 1]),
    },
    rig_head: {
      dx: keys([0, 0], [18, -5], [34, -9], [52, -2], [72, 4], [92, 10], [108, 14], [118, 8], [132, -2], [156, 0]),
      dy: keys([0, 0], [18, 2], [34, 4], [72, 7], [108, 10], [118, 5], [132, 1], [156, 0]),
      rotationDeg: keys([0, 0], [18, -6], [34, -9], [52, -3], [72, 5], [92, 10], [108, 14], [118, 7], [132, -3], [144, 2], [156, 0]),
    },
    rig_ear_l: {
      rotationDeg: keys([0, 0], [24, -12], [42, 5], [62, -5], [82, 4], [104, -7], [118, 9], [136, -3], [156, 0]),
    },
    rig_ear_r: {
      rotationDeg: keys([0, 0], [24, 8], [42, -4], [62, 6], [82, -4], [104, 7], [118, -9], [136, 3], [156, 0]),
    },
    rig_eye_l: {
      dx: keys([0, 0], [16, -4], [36, -3], [56, 0], [76, 3], [96, 5], [112, 5], [124, 0], [156, 0]),
      dy: keys([0, 0], [20, 3], [112, 4], [124, 0], [156, 0]),
      scaleY: keys([0, 1], [18, 1], [22, 0.1], [26, 1], [104, 1], [108, 1.18], [116, 0.16], [122, 1], [156, 1]),
    },
    rig_eye_r: {
      dx: keys([0, 0], [16, -4], [36, -3], [56, 0], [76, 3], [96, 5], [112, 5], [124, 0], [156, 0]),
      dy: keys([0, 0], [20, 3], [112, 4], [124, 0], [156, 0]),
      scaleY: keys([0, 1], [18, 1], [22, 0.1], [26, 1], [104, 1], [108, 1.18], [116, 0.16], [122, 1], [156, 1]),
    },
    rig_arm_r_upper: {
      rotationDeg: keys([0, 0], [28, -8], [48, -30], [68, -52], [88, -72], [104, -92], [112, -102], [120, -64], [134, -20], [156, 0]),
    },
    rig_arm_r_fore: {
      rotationDeg: keys([0, 0], [34, 12], [54, 24], [74, 38], [92, 52], [106, 66], [112, 74], [120, 42], [134, 8], [156, 0]),
    },
    rig_paw_r: {
      dx: keys([0, 0], [54, 3], [74, 7], [92, 12], [106, 18], [112, 24], [118, 16], [134, 2], [156, 0]),
      dy: keys([0, 0], [54, 2], [74, 5], [92, 8], [106, 10], [112, 14], [118, 8], [134, 1], [156, 0]),
      rotationDeg: keys([0, 0], [54, -8], [74, -18], [92, -28], [106, -38], [112, -48], [118, -22], [134, 4], [156, 0]),
      scaleX: keys([0, 1], [92, 1.05], [112, 1.18], [118, 0.9], [134, 1.03], [156, 1]),
      scaleY: keys([0, 1], [92, 1.05], [112, 0.88], [118, 1.12], [134, 0.98], [156, 1]),
    },
    rig_arm_l_upper: {
      rotationDeg: keys([0, 0], [28, 10], [52, 26], [76, 42], [100, 54], [112, 60], [124, 30], [140, -5], [156, 0]),
    },
    rig_arm_l_fore: {
      rotationDeg: keys([0, 0], [32, -10], [56, -24], [80, -34], [104, -42], [112, -48], [124, -20], [140, 5], [156, 0]),
    },
    rig_paw_l: {
      rotationDeg: keys([0, 0], [48, 5], [76, 12], [104, 20], [112, 24], [124, 8], [140, -3], [156, 0]),
    },
    rig_leg_l: {
      rotationDeg: keys([0, 0], [36, -4], [64, -10], [88, -16], [108, -22], [118, -12], [132, 5], [156, 0]),
      scaleY: keys([0, 1], [36, 0.97], [64, 0.93], [88, 0.88], [108, 0.82], [118, 0.9], [132, 1.04], [156, 1]),
    },
    rig_leg_r: {
      rotationDeg: keys([0, 0], [36, 4], [64, 10], [88, 16], [108, 22], [118, 12], [132, -5], [156, 0]),
      scaleY: keys([0, 1], [36, 0.97], [64, 0.93], [88, 0.88], [108, 0.82], [118, 0.9], [132, 1.04], [156, 1]),
    },
    rig_foot_l: {
      dx: keys([0, 0], [64, -3], [88, -5], [108, -8], [118, -3], [132, 2], [156, 0]),
      rotationDeg: keys([0, 0], [64, -5], [88, -10], [108, -16], [118, -8], [132, 4], [156, 0]),
    },
    rig_foot_r: {
      dx: keys([0, 0], [64, 3], [88, 6], [108, 10], [118, 4], [132, -2], [156, 0]),
      rotationDeg: keys([0, 0], [64, 5], [88, 10], [108, 18], [118, 8], [132, -4], [156, 0]),
    },
    rig_tail: {
      rotationDeg: keys([0, 0], [24, -16], [46, 12], [70, -10], [92, 8], [108, -18], [120, 20], [138, -6], [156, 0]),
      scaleX: keys([0, 1], [70, 1.04], [108, 1.1], [120, 0.95], [138, 1.03], [156, 1]),
    },
    rig_satchel: {
      dx: keys([0, 0], [36, -2], [60, 4], [84, -3], [108, 7], [120, -4], [138, 2], [156, 0]),
      dy: keys([0, 0], [36, 2], [60, 5], [84, 8], [108, 13], [120, 4], [138, -2], [156, 0]),
      rotationDeg: keys([0, 0], [36, -7], [60, 10], [84, -8], [108, 16], [120, -12], [138, 5], [156, 0]),
    },
  },
);

export const PERFORMANCE_SPECS = [idle, wave, salute, diary, split, jump, catchCoin];

export const PERFORMANCE_BY_SLUG = Object.fromEntries(
  PERFORMANCE_SPECS.map((spec) => [spec.slug, spec]),
);

export const MOTION_RANGE_BY_SLUG = Object.freeze(
  Object.fromEntries(PERFORMANCE_SPECS.map((spec) => [spec.slug, spec.motionRange])),
);

function range(values) {
  return Math.max(...values) - Math.min(...values);
}

function propertyMoves(keyframes) {
  return new Set(keyframes.map(([, value]) => value)).size > 1;
}

function summarizeMotionRange(tracks) {
  const byPivot = {};
  const aggregate = {};
  const movingPivots = [];
  const semanticMovingPivots = [];

  for (const [pivotName, properties] of Object.entries(tracks)) {
    const pivotRanges = {};
    const movingProperties = [];
    for (const [property, keyframes] of Object.entries(properties)) {
      const values = keyframes.map(([, value]) => value);
      const min = Math.min(...values);
      const max = Math.max(...values);
      const span = max - min;
      pivotRanges[property] = { min, max, span };
      if (span > 0) movingProperties.push(property);

      const current = aggregate[property];
      aggregate[property] = current
        ? { min: Math.min(current.min, min), max: Math.max(current.max, max) }
        : { min, max };
    }
    byPivot[pivotName] = pivotRanges;
    if (movingProperties.length > 0) {
      movingPivots.push(pivotName);
      if (
        !CONDITIONAL_PIVOTS.includes(pivotName) ||
        movingProperties.some((property) => property !== "opacity")
      ) {
        semanticMovingPivots.push(pivotName);
      }
    }
  }

  for (const value of Object.values(aggregate)) value.span = value.max - value.min;
  return {
    movingPivots,
    semanticMovingPivots,
    semanticPivotCount: semanticMovingPivots.length,
    byProperty: aggregate,
    byPivot,
  };
}

function countMovingPivots(spec) {
  return Object.entries(spec.tracks).filter(([name, properties]) => {
    const movingProperties = Object.entries(properties).filter(([, keyframes]) =>
      propertyMoves(keyframes),
    );
    if (movingProperties.length === 0) return false;
    if (
      CONDITIONAL_PIVOTS.includes(name) &&
      movingProperties.every(([property]) => property === "opacity")
    ) {
      return false;
    }
    return true;
  }).length;
}

export function validatePerformanceSpecs(specs = PERFORMANCE_SPECS, { throwOnError = false } = {}) {
  const errors = [];
  const expectedSlugs = [
    "00_idle__breathe_blink",
    "01_welcome__full_wave",
    "02_welcome_back__happy_salute",
    "03_add_expense__write_in_diary",
    "04_split_bill__balance_and_present",
    "05_bills_settled__joy_jump",
    "06_payment_error__catch_rolling_coin",
  ];

  if (specs.length !== expectedSlugs.length) {
    errors.push(`Expected ${expectedSlugs.length} performances, found ${specs.length}.`);
  }

  const seenSlugs = new Set();
  const specsBySlug = Object.fromEntries(specs.map((spec) => [spec.slug, spec]));
  for (const [index, spec] of specs.entries()) {
    const end = terminalFrame(spec);
    if (spec.slug !== expectedSlugs[index]) {
      errors.push(`Performance ${index} should be ${expectedSlugs[index]}, found ${spec.slug}.`);
    }
    if (seenSlugs.has(spec.slug)) errors.push(`Duplicate slug: ${spec.slug}.`);
    seenSlugs.add(spec.slug);
    if (!Number.isFinite(spec.durationSeconds) || spec.durationSeconds <= 0) {
      errors.push(`${spec.slug}: durationSeconds must be positive.`);
    }
    if (typeof spec.loop !== "boolean") errors.push(`${spec.slug}: loop must be boolean.`);
    if (!spec.description) errors.push(`${spec.slug}: description is required.`);
    const expectedEndpointMode = spec.loop ? "seamless_loop" : "return_to_bind_pose";
    if (
      spec.endpointPolicy?.mode !== expectedEndpointMode ||
      spec.endpointPolicy?.startFrame !== 0 ||
      spec.endpointPolicy?.endFrame !== end ||
      spec.endpointPolicy?.requiresMatchingValues !== true
    ) {
      errors.push(`${spec.slug}: endpointPolicy does not match its authored timeline.`);
    }

    const requiredArticulation = REQUIRED_ARTICULATION_BY_SLUG[spec.slug] ?? [];
    if (
      !Array.isArray(spec.requiredArticulation) ||
      spec.requiredArticulation.length !== requiredArticulation.length ||
      requiredArticulation.some((pivotName) => !spec.requiredArticulation.includes(pivotName))
    ) {
      errors.push(`${spec.slug}: requiredArticulation metadata is missing or inconsistent.`);
    }

    for (const conditionalName of CONDITIONAL_PIVOTS) {
      const opacityKeys = spec.tracks[conditionalName]?.opacity;
      if (!opacityKeys || opacityKeys[0]?.[0] !== 0) {
        errors.push(`${spec.slug}: ${conditionalName} must set opacity at frame 0.`);
      }
    }

    for (const [pivotName, properties] of Object.entries(spec.tracks)) {
      if (!BASE_BY_NAME[pivotName]) {
        errors.push(`${spec.slug}: unknown pivot ${pivotName}.`);
      }
      for (const [property, keyframes] of Object.entries(properties)) {
        if (!ALLOWED_PROPERTIES.has(property)) {
          errors.push(`${spec.slug}/${pivotName}: unsupported property ${property}.`);
        }
        if (!Array.isArray(keyframes) || keyframes.length < 2) {
          errors.push(`${spec.slug}/${pivotName}/${property}: needs at least two keyframes.`);
          continue;
        }
        if (keyframes[0][0] !== 0) {
          errors.push(`${spec.slug}/${pivotName}/${property}: first key must be frame 0.`);
        }
        if (keyframes.at(-1)[0] !== end) {
          errors.push(
            `${spec.slug}/${pivotName}/${property}: terminal key must be frame ${end}.`,
          );
        }
        let priorFrame = -1;
        for (const keyframe of keyframes) {
          if (
            !Array.isArray(keyframe) ||
            keyframe.length !== 2 ||
            !Number.isFinite(keyframe[0]) ||
            !Number.isFinite(keyframe[1])
          ) {
            errors.push(`${spec.slug}/${pivotName}/${property}: malformed keyframe.`);
            continue;
          }
          const [frame, value] = keyframe;
          if (!Number.isInteger(frame) || frame < 0 || frame > end) {
            errors.push(`${spec.slug}/${pivotName}/${property}: invalid frame ${frame}.`);
          }
          if (frame <= priorFrame) {
            errors.push(`${spec.slug}/${pivotName}/${property}: frames must strictly increase.`);
          }
          priorFrame = frame;
          if (property === "opacity" && (value < 0 || value > 1)) {
            errors.push(`${spec.slug}/${pivotName}/${property}: opacity ${value} is out of range.`);
          }
          if ((property === "scaleX" || property === "scaleY") && value < 0) {
            errors.push(`${spec.slug}/${pivotName}/${property}: scale ${value} is negative.`);
          }
        }
        if (keyframes[0][1] !== keyframes.at(-1)[1]) {
          errors.push(
            `${spec.slug}/${pivotName}/${property}: endpoints must match exactly for ${expectedEndpointMode}.`,
          );
        }
      }
    }

    const movingPivotCount = countMovingPivots(spec);
    const minimumMovingPivots = 5;
    if (movingPivotCount < minimumMovingPivots) {
      errors.push(
        `${spec.slug}: only ${movingPivotCount} moving semantic pivots; at least ${minimumMovingPivots} are required.`,
      );
    }
    if (
      !spec.motionRange ||
      spec.motionRange.semanticPivotCount !== movingPivotCount ||
      spec.motionRange.semanticMovingPivots.length !== movingPivotCount
    ) {
      errors.push(`${spec.slug}: motionRange metadata is missing or inconsistent.`);
    }
    for (const pivotName of requiredArticulation) {
      const properties = spec.tracks[pivotName];
      if (!properties || !Object.values(properties).some(propertyMoves)) {
        errors.push(`${spec.slug}: required articulated pivot ${pivotName} does not move.`);
      }
    }
  }

  const waveSpec = specsBySlug["01_welcome__full_wave"];
  if (
    !propertyMoves(waveSpec.tracks.rig_arm_l_upper.rotationDeg) ||
    !propertyMoves(waveSpec.tracks.rig_arm_l_fore.rotationDeg) ||
    range(waveSpec.tracks.rig_paw_l.rotationDeg.map(([, value]) => value)) < 30
  ) {
    errors.push("Wave must articulate shoulder, elbow, and a clearly oscillating paw.");
  }

  const diarySpec = specsBySlug["03_add_expense__write_in_diary"];
  if (
    diarySpec.tracks.rig_diary.opacity[0][1] !== 1 ||
    diarySpec.tracks.rig_pen.opacity[0][1] !== 1 ||
    !propertyMoves(diarySpec.tracks.rig_arm_r_upper.rotationDeg) ||
    !propertyMoves(diarySpec.tracks.rig_arm_r_fore.rotationDeg) ||
    !propertyMoves(diarySpec.tracks.rig_paw_r.rotationDeg) ||
    !propertyMoves(diarySpec.tracks.rig_diary.rotationDeg) ||
    !propertyMoves(diarySpec.tracks.rig_pen.rotationDeg) ||
    diarySpec.tracks.rig_fx_writing.opacity.filter(([, value]) => value > 0).length < 3
  ) {
    errors.push(
      "Diary performance must articulate shoulder, elbow, wrist, diary, and pen across multiple writing strokes.",
    );
  }

  const splitSpec = specsBySlug["04_split_bill__balance_and_present"];
  const splitLeftScales = splitSpec.tracks.rig_coin_stack_l.scaleX.map(([, value]) => value);
  const splitRightScales = splitSpec.tracks.rig_coin_stack_r.scaleX.map(([, value]) => value);
  if (
    Math.max(...splitLeftScales) <= 1 ||
    Math.min(...splitRightScales) >= 1 ||
    !splitLeftScales.includes(1) ||
    !splitRightScales.includes(1) ||
    splitSpec.tracks.rig_coin_stack_l.opacity.every(([, value]) => value === 0) ||
    splitSpec.tracks.rig_coin_stack_r.opacity.every(([, value]) => value === 0)
  ) {
    errors.push("Split must show both stacks moving from asymmetric to equal presentation.");
  }

  const jumpSpec = specsBySlug["05_bills_settled__joy_jump"];
  if (Math.min(...jumpSpec.tracks.rig_root.dy.map(([, value]) => value)) > -70) {
    errors.push("Joy jump root must rise by at least 70 pixels.");
  }
  if (
    !propertyMoves(jumpSpec.tracks.rig_arm_l_upper.rotationDeg) ||
    !propertyMoves(jumpSpec.tracks.rig_arm_r_upper.rotationDeg) ||
    !propertyMoves(jumpSpec.tracks.rig_leg_l.rotationDeg) ||
    !propertyMoves(jumpSpec.tracks.rig_leg_r.rotationDeg)
  ) {
    errors.push("Joy jump must articulate both arms and both legs.");
  }
  for (const pivotName of [
    "rig_root",
    "rig_leg_l",
    "rig_leg_r",
    "rig_foot_l",
    "rig_foot_r",
    "rig_tail",
    "rig_satchel",
  ]) {
    if (!Object.values(jumpSpec.tracks[pivotName] ?? {}).some(propertyMoves)) {
      errors.push(`Joy jump must move ${pivotName}.`);
    }
  }

  const catchSpec = specsBySlug["06_payment_error__catch_rolling_coin"];
  if (range(catchSpec.tracks.rig_rolling_coin.dx.map(([, value]) => value)) < 180) {
    errors.push("Catch performance coin must traverse at least 180 pixels.");
  }
  if (
    range(catchSpec.tracks.rig_paw_r.dx.map(([, value]) => value)) < 12 ||
    !propertyMoves(catchSpec.tracks.rig_arm_r_upper.rotationDeg) ||
    !propertyMoves(catchSpec.tracks.rig_arm_r_fore.rotationDeg)
  ) {
    errors.push("Catch performance must visibly reach with shoulder, elbow, and paw.");
  }

  const result = {
    valid: errors.length === 0,
    errors,
    performanceCount: specs.length,
    frameRate: FPS,
    movingPivotCounts: Object.fromEntries(
      specs.map((spec) => [spec.slug, countMovingPivots(spec)]),
    ),
    motionRanges: Object.fromEntries(
      specs.map((spec) => [spec.slug, spec.motionRange]),
    ),
  };

  if (throwOnError && errors.length > 0) {
    throw new Error(`Performance spec validation failed:\n${errors.join("\n")}`);
  }
  return result;
}
