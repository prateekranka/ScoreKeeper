export const CONTROL_PIVOTS = Object.freeze({
  cup: [255, 245],
  handle_l: [88, 150],
  handle_r: [422, 150],
  stem: [255, 325],
  base: [256, 401],
});

const gradients = {
  goldBody: { y1: 49, y2: 244, stops: [[0, "#F8D65A"], [.48, "#EFB842"], [1, "#D19128"]] },
  goldLight: { y1: 264, y2: 403, stops: [[0, "#FFE477"], [1, "#E2A832"]] },
  goldShadow: { y1: 264, y2: 403, stops: [[0, "#BC8120"], [1, "#805511"]] },
  edgeDark: { y1: 14, y2: 403, stops: [[0, "#94691E"], [1, "#60400D"]] },
};

const hex = (value) => [1, 3, 5].map((index) => Number.parseInt(value.slice(index, index + 2), 16));
const mix = (a, b, t) => `#${a.map((value, index) => Math.round(value + (b[index] - value) * t).toString(16).padStart(2, "0")).join("").toUpperCase()}`;
export function sampledGradientColor(name, y) {
  const gradient = gradients[name];
  const t = Math.max(0, Math.min(1, (y - gradient.y1) / (gradient.y2 - gradient.y1)));
  let left = gradient.stops[0], right = gradient.stops.at(-1);
  for (let index = 1; index < gradient.stops.length; index += 1) if (t <= gradient.stops[index][0]) { left = gradient.stops[index - 1]; right = gradient.stops[index]; break; }
  return mix(hex(left[1]), hex(right[1]), (t - left[0]) / (right[0] - left[0] || 1));
}

const rect = (sourceIndex, semantic, x, y, width, height, fill) => Object.freeze({ sourceIndex, semantic, x, y, width, height, fill, color: sampledGradientColor(fill, y + height / 2) });

export const UNDERLAPS = Object.freeze([
  rect(2, "cup", 70, 30, 414, 43, "edgeDark"),
  rect(3, "cup", 88, 49, 336, 23, "goldBody"),
  rect(4, "handle_l", 9, 73, 84, 56, "edgeDark"),
  rect(5, "handle_l", 9, 169, 84, 55, "edgeDark"),
  rect(6, "handle_l", 9, 129, 40, 40, "edgeDark"),
  rect(7, "handle_l", 72, 129, 21, 40, "edgeDark"),
  rect(8, "handle_l", 29, 92, 63, 20, "goldBody"),
  rect(9, "handle_l", 29, 169, 63, 37, "goldBody"),
  rect(10, "handle_l", 29, 112, 20, 57, "goldBody"),
  rect(11, "handle_l", 72, 112, 20, 57, "goldBody"),
  rect(12, "handle_r", 420, 73, 83, 56, "edgeDark"),
  rect(13, "handle_r", 420, 169, 83, 55, "edgeDark"),
  rect(14, "handle_r", 420, 129, 21, 40, "edgeDark"),
  rect(15, "handle_r", 465, 129, 38, 40, "edgeDark"),
  rect(16, "handle_r", 421, 92, 61, 20, "goldBody"),
  rect(17, "handle_r", 421, 169, 61, 37, "goldBody"),
  rect(18, "handle_r", 421, 112, 20, 57, "goldBody"),
  rect(19, "handle_r", 465, 112, 20, 57, "goldBody"),
  rect(20, "cup", 69, 72, 372, 56, "edgeDark"),
  rect(21, "cup", 72, 128, 369, 42, "edgeDark"),
  rect(22, "cup", 69, 170, 372, 74, "edgeDark"),
  rect(23, "cup", 88, 92, 335, 36, "goldBody"),
  rect(24, "cup", 91, 128, 329, 42, "goldBody"),
  rect(25, "cup", 88, 170, 335, 54, "goldBody"),
  rect(29, "cup", 69, 224, 372, 20, "edgeDark"),
  rect(30, "cup", 88, 225, 332, 19, "goldBody"),
  rect(31, "cup", 88, 244, 334, 20, "edgeDark"),
  rect(32, "cup", 109, 244, 290, 19, "goldShadow"),
  rect(38, "stem", 215, 264, 79, 20, "edgeDark"),
  rect(39, "stem", 235, 265, 39, 19, "goldLight"),
  rect(40, "stem", 196, 284, 117, 20, "edgeDark"),
  rect(41, "stem", 215, 284, 77, 19, "goldLight"),
  rect(42, "base", 158, 304, 193, 20, "edgeDark"),
  rect(43, "base", 177, 304, 153, 19, "goldLight"),
  rect(44, "base", 138, 324, 234, 39, "edgeDark"),
  rect(45, "base", 158, 344, 194, 19, "goldLight"),
  rect(46, "base", 118, 363, 274, 40, "goldShadow"),
  rect(47, "base", 138, 363, 232, 20, "goldLight"),
]);

export const SOURCE_LAYER_BY_INDEX = Object.freeze({
  2: "l00", 3: "l01", 4: "l00", 5: "l00", 6: "l00", 7: "l00", 8: "l01", 9: "l01", 10: "l01", 11: "l01",
  12: "l00", 13: "l00", 14: "l00", 15: "l00", 16: "l01", 17: "l01", 18: "l01", 19: "l01",
  20: "l02", 21: "l02", 22: "l02", 23: "l03", 24: "l03", 25: "l03", 29: "l04", 30: "l05", 31: "l06", 32: "l07",
  38: "l00", 39: "l01", 40: "l02", 41: "l03", 42: "l00", 43: "l01", 44: "l02", 45: "l03", 46: "l04", 47: "l05",
});

export function underlapRect(item) {
  return { x: item.x, y: item.y, width: item.width, height: item.height };
}

export const UNDERLAP_PREFIX = "__V3_UNDERLAP__";
export const BRIDGE_PREFIX = "__V3_BRIDGE__";
export const BRIDGES = Object.freeze([
  Object.freeze({ name: `${BRIDGE_PREFIX}cup_edgeDark_y128`, semantic: "cup", sourceIndex: 21, x: 72.5, y: 125, width: 368, height: 6, fill: "edgeDark", color: "#855D19" }),
  Object.freeze({ name: `${BRIDGE_PREFIX}cup_goldBody_y128`, semantic: "cup", sourceIndex: 24, x: 91.5, y: 125, width: 328, height: 6, fill: "goldBody", color: "#F1BD46" }),
  Object.freeze({ name: `${BRIDGE_PREFIX}cup_edgeDark_y170`, semantic: "cup", sourceIndex: 22, x: 72.5, y: 167, width: 368, height: 6, fill: "edgeDark", color: "#805917" }),
  Object.freeze({ name: `${BRIDGE_PREFIX}cup_goldBody_y170`, semantic: "cup", sourceIndex: 25, x: 91.5, y: 167, width: 328, height: 6, fill: "goldBody", color: "#E7AE3B" }),
]);
const hasVerticalNeighbor = (item, edge) => UNDERLAPS.some((other) => {
  if (other === item || other.semantic !== item.semantic || other.fill !== item.fill) return false;
  const touches = edge === "top" ? other.y + other.height === item.y : item.y + item.height === other.y;
  const overlapsX = Math.min(item.x + item.width, other.x + other.width) > Math.max(item.x, other.x);
  return touches && overlapsX;
});
export const UNDERLAP_BANDS = Object.freeze(UNDERLAPS.flatMap((item) => {
  const bands = [];
  for (let offset = 0; offset < item.height; offset += 2) {
    const bandHeight = Math.min(2, item.height - offset);
    const first = offset === 0;
    const last = offset + bandHeight === item.height;
    const overlapTop = first ? (hasVerticalNeighbor(item, "top") ? 1 : -0.5) : 1;
    const overlapBottom = last ? (hasVerticalNeighbor(item, "bottom") ? 1 : -0.5) : 1;
    bands.push(Object.freeze({
      ...item,
      band: bands.length,
      x: item.x + 0.5,
      width: item.width - 1,
      y: item.y + offset - overlapTop,
      height: bandHeight + overlapTop + overlapBottom,
      color: sampledGradientColor(item.fill, item.y + offset + bandHeight / 2),
    }));
  }
  return bands;
}));
export const underlapName = (item) => `${UNDERLAP_PREFIX}${item.semantic}_${String(item.sourceIndex).padStart(3, "0")}_${String(item.band ?? 0).padStart(2, "0")}`;
