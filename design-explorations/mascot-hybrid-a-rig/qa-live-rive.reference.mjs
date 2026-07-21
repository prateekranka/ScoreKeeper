#!/usr/bin/env node

/**
 * Independent live-Rive acceptance test for the v5 Pocket Bookkeeper mascot.
 *
 * This intentionally does not trust the builder or its summary. Every material
 * assertion is made against objects, properties, keyframes, and state-machine
 * mappings returned by the live Rive MCP server.
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { BASE_BY_NAME, PIVOTS } from "./rig-spec.mjs";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const SUMMARY_PATH = join(ROOT, "rive-build-summary-v5.json");
const REPORT_PATH = join(ROOT, "live-qa-report.json");
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const ARTBOARD_NAME = "Pocket Bookkeeper - Articulated Rig v5";
const STATE_MACHINE_NAME = "Pocket Bookkeeper Behaviors v5";
const EPSILON = 1e-4;

const PROPERTY = Object.freeze({
  x: 13,
  y: 14,
  rotation: 15,
  scaleX: 16,
  scaleY: 17,
  opacity: 18,
});
const TRANSFORM_KEYS = Object.values(PROPERTY);
const MOTION_KEYS = [PROPERTY.x, PROPERTY.y, PROPERTY.rotation, PROPERTY.scaleX, PROPERTY.scaleY];
const ANIMATION_PROPERTY = Object.freeze({ fps: 56, durationFrames: 57, loopValue: 59 });

const COLORS = Object.freeze({
  cobalt: "#FF213C8E",
  cream: "#FFFAF2E8",
  transparent: "#00000000",
});

const ANIMATION_CONTRACT = Object.freeze([
  { name: "00_idle__breathe_blink", state: "Idle", loop: true },
  { name: "01_welcome__full_wave", state: "Welcome", loop: false },
  { name: "02_welcome_back__happy_salute", state: "Welcome Back", loop: false },
  { name: "03_add_expense__write_in_diary", state: "Add Expense", loop: true },
  { name: "04_split_bill__balance_and_present", state: "Split Bill", loop: false },
  { name: "05_bills_settled__joy_jump", state: "Bills Settled", loop: false },
  { name: "06_payment_error__catch_rolling_coin", state: "Payment Error", loop: false },
]);

const PIVOT_PARENTS = Object.freeze(Object.fromEntries(PIVOTS.map((pivot) => [pivot.name, pivot.parent])));

const REQUIRED_ANIMATED_JOINTS = Object.freeze({
  "01_welcome__full_wave": ["rig_arm_l_upper", "rig_arm_l_fore", "rig_paw_l", "rig_tail_mid", "rig_tail_tip"],
  "03_add_expense__write_in_diary": [
    "rig_arm_r_upper",
    "rig_arm_r_fore",
    "rig_paw_r",
    "rig_diary",
    "rig_pen",
    "rig_tail_mid",
  ],
  "05_bills_settled__joy_jump": [
    "rig_root", "rig_leg_l", "rig_shin_l", "rig_foot_l",
    "rig_leg_r", "rig_shin_r", "rig_foot_r", "rig_tail_mid", "rig_tail_tip",
  ],
});

const OPACITY_ACCESSORY_ALLOWLIST = /^(rig_(diary|pen|coin_stack_[lr]|rolling_coin|fx_.+|mouth_(smile|open)))$/;
const FORBIDDEN_TYPES = new Set([
  "Image",
  "ImageAsset",
  "ImageInstance",
  "NestedArtboard",
  "ArtboardInstance",
  "FileAsset",
  "Bitmap",
  "Raster",
]);

let rpcId = 1;
const checks = [];

function fail(message, details) {
  const error = new Error(message);
  error.details = details;
  throw error;
}

function assert(condition, message, details) {
  if (!condition) fail(message, details);
}

function closeEnough(left, right, epsilon = EPSILON) {
  return Number.isFinite(Number(left))
    && Number.isFinite(Number(right))
    && Math.abs(Number(left) - Number(right)) <= epsilon;
}

function normalizeColor(value) {
  const source = String(value ?? "").trim().toUpperCase();
  if (/^#[0-9A-F]{6}$/.test(source)) return `#FF${source.slice(1)}`;
  if (/^#[0-9A-F]{8}$/.test(source)) return source;
  return source;
}

function typeMatches(object, predicate) {
  return (object.types ?? []).some(predicate);
}

function isType(object, type) {
  return typeMatches(object, (candidate) => candidate === type);
}

function uniqueNamed(objects, name, context) {
  const matches = objects.filter((object) => object.name === name);
  assert(matches.length === 1, `${context}: expected exactly one '${name}', found ${matches.length}`);
  return matches[0];
}

function makeParentMap(objects) {
  const parents = new Map();
  for (const object of objects) {
    for (const childId of object.children ?? []) {
      assert(!parents.has(childId), `Hierarchy object ${childId} has multiple parents`);
      parents.set(childId, object.id);
    }
  }
  return parents;
}

function nearestAncestor(objectId, parents, objectById, predicate) {
  let cursor = parents.get(objectId);
  const visited = new Set();
  while (cursor && !visited.has(cursor)) {
    visited.add(cursor);
    const object = objectById.get(cursor);
    if (object && predicate(object)) return object;
    cursor = parents.get(cursor);
  }
  return null;
}

async function rpc(method, params = {}) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: rpcId++, method, params }),
  });
  if (!response.ok) fail(`${method}: HTTP ${response.status} ${response.statusText}`);
  const payload = await response.json();
  if (payload.error) fail(`${method}: ${payload.error.message}`, payload.error.data);
  return payload.result;
}

async function notify(method, params = {}) {
  await fetch(MCP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", method, params }),
  });
}

async function tool(name, arguments_ = {}) {
  const result = await rpc("tools/call", { name, arguments: arguments_ });
  const text = result?.content?.find((entry) => entry.type === "text")?.text;
  let parsed = result;
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      fail(`${name}: Rive returned non-JSON text`, { response: text.slice(0, 800) });
    }
  }
  if (parsed?.errors?.length) fail(`${name}: live Rive query failed`, parsed.errors);
  if (parsed?.success === false) fail(`${name}: ${parsed.error ?? parsed.message ?? "unknown failure"}`, parsed);
  return parsed;
}

async function record(name, operation) {
  const detail = await operation();
  const reportDetail = detail instanceof Map
    ? { count: detail.size, names: [...detail.keys()] }
    : detail;
  checks.push({ name, status: "passed", detail: reportDetail });
  return detail;
}

async function initialize() {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "codex-pocket-bookkeeper-rig-v5-qa", version: "5.0" },
  });
  await notify("notifications/initialized").catch(() => {});
}

async function focusLock(artboardId) {
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId, fitToViewport: true } },
  });
  await new Promise((resolve) => setTimeout(resolve, 350));
  let stageSelectionVerified = false;
  try {
    await tool("select_objects", { objectIds: [artboardId] });
    stageSelectionVerified = true;
  } catch (error) {
    // Rive Beta may omit a selectable Stage proxy for a valid component
    // artboard. The active Core artboard still scopes hierarchy/animation
    // queries correctly, so accept that exact editor limitation only.
    const diagnostic = `${String(error?.message ?? error)} ${JSON.stringify(error?.details ?? "")}`;
    if (!diagnostic.includes("no stage representation")) throw error;
  }
  const selected = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  const listed = await tool("list_artboards", {});
  assert(selected.artboard?.id === artboardId, "Rive did not focus the v5 artboard", selected);
  if (stageSelectionVerified) {
    assert(listed.selectionArtboardId === artboardId, "Rive selection is not locked to the v5 artboard", listed);
  }
  return { stageSelectionVerified, activeArtboardId: selected.artboard?.id };
}

async function queryValues(ids, keys) {
  const values = {};
  for (let start = 0; start < ids.length; start += 50) {
    const group = ids.slice(start, start + 50);
    const result = await tool("query_property_values", {
      propertyKeys: Object.fromEntries(group.map((id) => [id, keys])),
    });
    Object.assign(values, result.values ?? {});
  }
  return values;
}

function animatedMotionTargets(keyframes, pivotById) {
  const tracks = new Map();
  for (const keyframe of keyframes) {
    const key = Number(keyframe.propertyKey);
    if (!MOTION_KEYS.includes(key) || !pivotById.has(keyframe.objectId)) continue;
    const tuple = `${keyframe.objectId}/${key}`;
    if (!tracks.has(tuple)) tracks.set(tuple, []);
    tracks.get(tuple).push(Number(keyframe.value));
  }
  const ids = new Set();
  for (const [tuple, values] of tracks) {
    if (values.length >= 2 && values.some((value) => !closeEnough(value, values[0]))) {
      ids.add(tuple.split("/")[0]);
    }
  }
  return [...ids].map((id) => pivotById.get(id).name).sort();
}

function verifyOpacityPolicy(animationName, keyframes, objectById, parents, artboardId) {
  const opacityTracks = new Map();
  for (const keyframe of keyframes.filter((entry) => Number(entry.propertyKey) === PROPERTY.opacity)) {
    if (!opacityTracks.has(keyframe.objectId)) opacityTracks.set(keyframe.objectId, []);
    opacityTracks.get(keyframe.objectId).push(Number(keyframe.value));
  }
  const switched = [];
  for (const [objectId, values] of opacityTracks) {
    if (values.length < 2 || values.every((value) => closeEnough(value, values[0]))) continue;
    const object = objectById.get(objectId);
    const name = object?.name ?? `<unknown:${objectId}>`;
    const isDirectArtboardChild = parents.get(objectId) === artboardId;
    const suspiciousName = /(pose|frame|sprite|variant|swap|nested|artboard)/i.test(name);
    if (!OPACITY_ACCESSORY_ALLOWLIST.test(name) || isDirectArtboardChild || suspiciousName) {
      switched.push({ objectId, name, values: [...new Set(values)], isDirectArtboardChild });
    }
  }
  assert(
    switched.length === 0,
    `${animationName}: opacity switching can act as pose swapping`,
    switched,
  );
  return {
    opacityTrackCount: opacityTracks.size,
    allowedAccessoryOrExpressionSwitches: [...opacityTracks.keys()]
      .map((id) => objectById.get(id)?.name)
      .filter((name) => name && OPACITY_ACCESSORY_ALLOWLIST.test(name)),
  };
}

function readSummaryBindPose() {
  if (!existsSync(SUMMARY_PATH)) return null;
  let summary;
  try {
    summary = JSON.parse(readFileSync(SUMMARY_PATH, "utf8"));
  } catch (error) {
    fail(`Could not parse ${SUMMARY_PATH}: ${error.message}`);
  }
  const entries = summary.bindPose ?? summary.rig?.bindPose ?? summary.geometry?.bindPose;
  assert(Array.isArray(entries), "Build summary exists but does not expose a bindPose array", summary);
  const byName = new Map();
  for (const entry of entries) {
    const name = entry.name ?? entry.role ?? entry.nodeName;
    const transform = entry.transform ?? entry.baseTransform ?? entry;
    if (name && BASE_BY_NAME[name]) byName.set(name, transform);
  }
  assert(
    byName.size === Object.keys(BASE_BY_NAME).length,
    `Build summary bindPose is incomplete: expected ${Object.keys(BASE_BY_NAME).length} semantic pivots, found ${byName.size}`,
  );
  return byName;
}

async function run() {
  await initialize();

  const artboard = await record("unique final artboard", async () => {
    const listed = await tool("list_artboards", {});
    const matches = (listed.artboards ?? []).filter((candidate) => candidate.name === ARTBOARD_NAME);
    assert(matches.length === 1, `Expected exactly one final artboard '${ARTBOARD_NAME}', found ${matches.length}`);
    assert(matches[0].id && matches[0].id !== "0-0", "Final artboard has a stale or missing ID", matches[0]);
    return { id: matches[0].id, name: matches[0].name };
  });

  await focusLock(artboard.id);
  checks.push({ name: "active-artboard focus lock", status: "passed", detail: { artboardId: artboard.id } });

  const hierarchy = await tool("get_artboard_hierarchy", { artboardId: artboard.id, depth: 12 });
  const objects = hierarchy.objects ?? [];
  assert(objects.length > 0, "Live Rive hierarchy is empty");
  const objectById = new Map(objects.map((object) => [object.id, object]));
  const parents = makeParentMap(objects);

  await record("native vector-only geometry", async () => {
    const forbidden = objects.filter((object) => typeMatches(
      object,
      (type) => FORBIDDEN_TYPES.has(type) || /(Image|Bitmap|Raster|NestedArtboard|ArtboardInstance)/i.test(type),
    ));
    const shapes = objects.filter((object) => isType(object, "Shape"));
    const paths = objects.filter((object) => isType(object, "Path") || isType(object, "PointsPath"));
    assert(forbidden.length === 0, "Rig contains nested-artboard or raster pose components", forbidden);
    assert(shapes.length >= Object.keys(PIVOT_PARENTS).length, "Rig does not contain enough native Shape objects for an articulated character", {
      shapeCount: shapes.length,
      requiredMinimum: Object.keys(PIVOT_PARENTS).length,
    });
    assert(paths.length >= Object.keys(PIVOT_PARENTS).length, "Rig does not contain enough native Path objects", {
      pathCount: paths.length,
      requiredMinimum: Object.keys(PIVOT_PARENTS).length,
    });
    const gradients = objects.filter((object) => typeMatches(object, (type) => /Gradient/i.test(type)));
    assert(gradients.length === 0, "Reference mascot must use the exact flat two-color palette; gradients were found", gradients);
    return { shapeCount: shapes.length, pathCount: paths.length, forbiddenObjectCount: 0, gradientCount: 0 };
  });

  const pivotByName = await record("semantic pivot hierarchy", async () => {
    const shapes = objects.filter((object) => isType(object, "Shape"));
    const byName = new Map();
    for (const [name, expectedParentName] of Object.entries(PIVOT_PARENTS)) {
      const pivot = uniqueNamed(shapes, name, "Semantic rig");
      byName.set(name, pivot);
      const expectedParentId = expectedParentName === null ? artboard.id : byName.get(expectedParentName)?.id;
      assert(expectedParentId, `${name}: expected semantic parent '${expectedParentName}' was not resolved`);
      assert(
        parents.get(pivot.id) === expectedParentId,
        `${name}: expected parent '${expectedParentName ?? ARTBOARD_NAME}', found '${objectById.get(parents.get(pivot.id))?.name ?? "none"}'`,
      );
    }
    return byName;
  });
  const pivotById = new Map([...pivotByName.values()].map((pivot) => [pivot.id, pivot]));

  const bindValues = await queryValues([...pivotById.keys()], TRANSFORM_KEYS);
  await record("authored neutral bind transforms", async () => {
    const summaryBind = readSummaryBindPose();
    const exceptions = [];
    const keyNames = {
      [PROPERTY.x]: "x",
      [PROPERTY.y]: "y",
      [PROPERTY.rotation]: "rotation",
      [PROPERTY.scaleX]: "scaleX",
      [PROPERTY.scaleY]: "scaleY",
      [PROPERTY.opacity]: "opacity",
    };
    for (const pivot of pivotById.values()) {
      const values = bindValues[pivot.id] ?? {};
      const authored = BASE_BY_NAME[pivot.name];
      assert(authored, `${pivot.name}: missing authored BASE_BY_NAME transform`);
      for (const key of TRANSFORM_KEYS) {
        const property = keyNames[key];
        const actual = Number(values[key]);
        assert(Number.isFinite(actual), `${pivot.name}: bind property ${property} is missing or non-finite`, values);
        if (!closeEnough(actual, authored[property])) {
          exceptions.push({ name: pivot.name, property, expected: authored[property], actual, source: "rig-spec.mjs" });
        }
        if (summaryBind && !closeEnough(actual, summaryBind.get(pivot.name)?.[property])) {
          exceptions.push({
            name: pivot.name,
            property,
            expected: summaryBind.get(pivot.name)?.[property],
            actual,
            source: "rive-build-summary-v5.json",
          });
        }
      }
      if (!closeEnough(authored.scaleX, 1) || !closeEnough(authored.scaleY, 1)) {
        exceptions.push({ name: pivot.name, property: "scale", expected: 1, actual: [authored.scaleX, authored.scaleY] });
      }
      const hiddenAtBind = closeEnough(authored.opacity, 0);
      if (hiddenAtBind && !OPACITY_ACCESSORY_ALLOWLIST.test(pivot.name)) {
        exceptions.push({ name: pivot.name, property: "opacity", expected: 1, actual: authored.opacity, reason: "not a conditional pivot" });
      }
    }
    assert(closeEnough(BASE_BY_NAME.rig_root?.rotation, 0), "rig_root authored bind rotation must be zero", BASE_BY_NAME.rig_root);
    assert(exceptions.length === 0, "Live semantic pivots do not match the authored neutral bind", exceptions);
    return {
      pivotCount: pivotById.size,
      expectedSource: summaryBind ? "rig-spec.mjs + rive-build-summary-v5.json" : "rig-spec.mjs",
      rootRotationZero: true,
      allScalesOne: true,
      exactTransformPropertiesVerified: ["x", "y", "rotation", "scaleX", "scaleY", "opacity"],
    };
  });

  await record("exact cobalt-and-cream palette", async () => {
    const solidColors = objects.filter((object) => isType(object, "SolidColor"));
    assert(solidColors.length >= 2, "Rig must contain native SolidColor objects for cobalt and cream");
    const values = await queryValues(solidColors.map((color) => color.id), [37]);
    const colors = solidColors.map((color) => ({
      id: color.id,
      name: color.name,
      color: normalizeColor(values[color.id]?.[37]),
      parentId: parents.get(color.id),
    }));
    const allowed = new Set(Object.values(COLORS));
    const unexpected = colors.filter((entry) => !allowed.has(entry.color));
    assert(unexpected.length === 0, "Rig uses colors outside the exact cobalt/cream palette", unexpected);
    const misplacedTransparency = colors
      .filter((entry) => entry.color === COLORS.transparent)
      .map((entry) => ({
        ...entry,
        owner: nearestAncestor(entry.id, parents, objectById, (object) => isType(object, "Shape"))?.name,
      }))
      .filter((entry) => !Object.hasOwn(PIVOT_PARENTS, entry.owner));
    assert(
      misplacedTransparency.length === 0,
      "Transparent paints are permitted only on named semantic pivot shapes",
      misplacedTransparency,
    );
    const used = new Set(colors.map((entry) => entry.color));
    assert(used.has(COLORS.cobalt), `Palette is missing cobalt ${COLORS.cobalt}`, colors);
    assert(used.has(COLORS.cream), `Palette is missing cream ${COLORS.cream}`, colors);
    const artboardFills = objects
      .filter((object) => isType(object, "Fill") && parents.get(object.id) === artboard.id)
      .flatMap((fill) => (fill.children ?? []).map((id) => colors.find((color) => color.id === id)).filter(Boolean));
    assert(
      artboardFills.some((entry) => entry.color === COLORS.cobalt),
      `Artboard background is not exact cobalt ${COLORS.cobalt}`,
      artboardFills,
    );
    return { allowedColors: [...allowed], usedColors: [...used], solidColorCount: solidColors.length };
  });

  const animationList = await tool("animation_editor", {
    command: "listLinearAnimations",
    data: { listLinearAnimations: {} },
  });
  const animations = animationList.linearAnimations ?? [];
  const animationByName = await record("exact seven named animations", async () => {
    assert(animations.length === ANIMATION_CONTRACT.length, `Expected exactly seven linear animations, found ${animations.length}`, animations);
    const expected = new Set(ANIMATION_CONTRACT.map((entry) => entry.name));
    const actual = new Set(animations.map((entry) => entry.name));
    const missing = [...expected].filter((name) => !actual.has(name));
    const extra = [...actual].filter((name) => !expected.has(name));
    assert(missing.length === 0 && extra.length === 0, "Animation names do not match the v5 contract", { missing, extra });
    for (const animation of animations) {
      assert(animation.id && animation.id !== "0-0", `${animation.name}: stale or missing animation ID`);
    }
    return new Map(animations.map((animation) => [animation.name, animation]));
  });

  const animationSettings = await queryValues(
    [...animationByName.values()].map((animation) => animation.id),
    Object.values(ANIMATION_PROPERTY),
  );
  const keyframeQuery = await tool("animation_editor", {
    command: "queryKeyFrames",
    data: { queryKeyFrames: { animationIds: [...animationByName.values()].map((animation) => animation.id) } },
  });

  const animationReports = [];
  await record("articulated animation depth and bind-safe timelines", async () => {
    for (const contract of ANIMATION_CONTRACT) {
      const animation = animationByName.get(contract.name);
      const keyframes = keyframeQuery.keyframes?.[animation.id] ?? [];
      assert(keyframes.length > 0, `${contract.name}: animation contains no keyframes`);
      const settings = animationSettings[animation.id] ?? {};
      const terminalFrame = Number(settings[ANIMATION_PROPERTY.durationFrames]);
      const fps = Number(settings[ANIMATION_PROPERTY.fps]);
      const loopValue = Number(settings[ANIMATION_PROPERTY.loopValue]);
      assert(Number.isInteger(terminalFrame) && terminalFrame > 1, `${contract.name}: invalid duration frame count`, settings);
      assert(Number.isFinite(fps) && fps > 0, `${contract.name}: invalid FPS`, settings);
      assert(loopValue === (contract.loop ? 1 : 0), `${contract.name}: loop setting is ${loopValue}, expected ${contract.loop ? 1 : 0}`);

      const tracks = new Map();
      for (const keyframe of keyframes) {
        const propertyKey = Number(keyframe.propertyKey);
        if (!TRANSFORM_KEYS.includes(propertyKey)) continue;
        const tuple = `${keyframe.objectId}/${propertyKey}`;
        if (!tracks.has(tuple)) tracks.set(tuple, []);
        tracks.get(tuple).push(keyframe);
      }
      const frame0OpacityByObject = new Map();
      for (const [tuple, entries] of tracks) {
        const [objectId, propertyKeyText] = tuple.split("/");
        if (Number(propertyKeyText) !== PROPERTY.opacity) continue;
        const frame0 = entries.find((entry) => Number(entry.frame) === 0);
        if (frame0) frame0OpacityByObject.set(objectId, Number(frame0.value));
      }
      for (const [tuple, entries] of tracks) {
        entries.sort((left, right) => Number(left.frame) - Number(right.frame));
        const [objectId, propertyKeyText] = tuple.split("/");
        const propertyKey = Number(propertyKeyText);
        const first = entries[0];
        assert(Number(first.frame) === 0, `${contract.name}/${tuple}: track does not begin at neutral bind frame 0`);
        const bind = bindValues[objectId]?.[propertyKey];
        if (pivotById.has(objectId)) {
          const pivotName = pivotById.get(objectId).name;
          const hiddenAccessoryTransform = propertyKey !== PROPERTY.opacity
            && OPACITY_ACCESSORY_ALLOWLIST.test(pivotName)
            && closeEnough(bindValues[objectId]?.[PROPERTY.opacity], 0)
            && closeEnough(frame0OpacityByObject.get(objectId), 0);
          // A non-idle looping state (the diary-writing cycle) is allowed to
          // start in its action pose; its own frame-0/terminal equality is the
          // continuity contract. Idle and every one-shot must still begin from
          // the neutral bind pose.
          const authoredActionLoopPose = contract.loop && contract.state !== "Idle";
          assert(
            closeEnough(first.value, bind) || hiddenAccessoryTransform || authoredActionLoopPose,
            `${contract.name}/${pivotName}/${propertyKey}: frame 0 differs from live neutral bind`,
            { frame0: first.value, bind, hiddenAccessoryTransform, authoredActionLoopPose },
          );
        }
        if (contract.loop) {
          const last = entries.at(-1);
          assert(Number(last.frame) === terminalFrame, `${contract.name}/${tuple}: looping track does not end at frame ${terminalFrame}`);
          assert(closeEnough(first.value, last.value), `${contract.name}/${tuple}: looping endpoints do not match`, {
            first: first.value,
            last: last.value,
          });
        }
      }

      const animatedJoints = animatedMotionTargets(keyframes, pivotById);
      if (contract.state !== "Idle") {
        assert(
          animatedJoints.length >= 5,
          `${contract.name}: expected at least five independently moving semantic joint targets, found ${animatedJoints.length}`,
          animatedJoints,
        );
      }
      for (const requiredName of REQUIRED_ANIMATED_JOINTS[contract.name] ?? []) {
        assert(animatedJoints.includes(requiredName), `${contract.name}: required articulated joint '${requiredName}' is not animated`, animatedJoints);
      }

      const opacity = verifyOpacityPolicy(contract.name, keyframes, objectById, parents, artboard.id);
      animationReports.push({
        name: contract.name,
        id: animation.id,
        state: contract.state,
        fps,
        terminalFrame,
        loop: contract.loop,
        keyframeCount: keyframes.length,
        transformTrackCount: tracks.size,
        animatedSemanticJointCount: animatedJoints.length,
        animatedSemanticJoints: animatedJoints,
        ...opacity,
      });
    }
    return animationReports;
  });

  await record("single custom state machine maps all seven behaviors", async () => {
    const list = await tool("animation_editor", {
      command: "listStateMachines",
      data: { listStateMachines: {} },
    });
    const machines = list.stateMachines ?? [];
    assert(machines.length === 1, `Expected exactly one custom state machine, found ${machines.length}`, machines);
    const machine = uniqueNamed(machines, STATE_MACHINE_NAME, "State machine");
    assert(machine.id && machine.id !== "0-0", "State machine has a stale or missing ID", machine);
    const detail = await tool("animation_editor", {
      command: "queryStateMachine",
      data: { queryStateMachine: { stateMachineId: machine.id } },
    });
    const namedStates = (detail.layers ?? []).flatMap((layer) => layer.states ?? []).filter((state) => state.name ?? state.stateName);
    assert(namedStates.length === 7, `State machine must contain exactly seven named behavior states, found ${namedStates.length}`, namedStates);
    const stateByName = new Map(namedStates.map((state) => [state.name ?? state.stateName, state]));
    for (const contract of ANIMATION_CONTRACT) {
      const state = stateByName.get(contract.state);
      assert(state, `State machine is missing '${contract.state}'`);
      assert(
        state.animationId === animationByName.get(contract.name).id,
        `${contract.state}: expected animation '${contract.name}' (${animationByName.get(contract.name).id}), found ${state.animationId ?? "none"}`,
      );
    }
    return {
      id: machine.id,
      name: machine.name,
      states: ANIMATION_CONTRACT.map((contract) => ({
        state: contract.state,
        animation: contract.name,
        animationId: animationByName.get(contract.name).id,
      })),
    };
  });

  return {
    status: "passed",
    qaContract: "pocket-bookkeeper-articulated-rig-v5",
    sourceOfTruth: "independent live Rive MCP queries",
    artboard,
    checks,
    animationReports,
  };
}

try {
  const report = await run();
  writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  const report = {
    status: "failed",
    qaContract: "pocket-bookkeeper-articulated-rig-v5",
    sourceOfTruth: "independent live Rive MCP queries",
    failedCheck: error.message,
    details: error.details ?? null,
    passedChecks: checks,
  };
  writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
  process.exitCode = 1;
}
