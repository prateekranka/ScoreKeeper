#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadApprovedArtwork, SEMANTIC_PARTS, APPROVED_SHA256 } from "./artwork-scanlines.mjs";
import { FPS, PERFORMANCES, PIVOTS, validateMotionSpec } from "./motion-spec-v2.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const MAIN_ID = "0-16469";
const MAIN_NAME = "__BUILDING__ ScoreKeeper Cup Hybrid A - Production Rig v2 20260715T1449IST";
const FINAL_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v2";
const HAIR_NAME = "__COMPONENT__ ScoreKeeper Hair v2 20260715T1510IST";
const LIVE_EXPORT = path.join(ROOT, "live-keyframes.json");
const SUMMARY_PATH = path.join(ROOT, "live-build-summary.json");
const PROTECTED = Object.freeze({ "0-2": 3946, "0-3956": 4092 });
const PROPERTY = Object.freeze({ dx: 13, dy: 14, rotationDeg: 15, scaleX: 16, scaleY: 17, opacity: 18 });
const ANIMATION_PROPERTY = Object.freeze({ fps: 56, durationFrames: 57, loop: 59 });
const CURVE = Object.freeze({ x1: 0.42, y1: 0, x2: 0.58, y2: 1 });
const SHAPE_CHUNK = 22;
const KEYFRAME_CHUNK = 100;
let rpcId = 1;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) result.push(items.slice(index, index + size));
  return result;
}

async function request(payload) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify(payload),
  });
  if (response.status === 202) return {};
  if (!response.ok) throw new Error(`Rive MCP HTTP ${response.status} ${response.statusText}`);
  const result = await response.json();
  if (result.error) throw new Error(result.error.message ?? JSON.stringify(result.error));
  return result;
}

async function rpc(method, params = {}) {
  return (await request({ jsonrpc: "2.0", id: rpcId++, method, params })).result;
}

async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  let parsed = result;
  if (text) {
    try { parsed = JSON.parse(text); } catch { parsed = text; }
  }
  if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}

async function initialize() {
  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-production-rig-v2", version: "1.0" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
}

async function focusLock(artboardId) {
  await tool("open_file_editor", { command: "focusArtboard", data: { focusArtboard: { artboardId, fitToViewport: true } } });
  await new Promise((resolve) => setTimeout(resolve, 180));
  const selected = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  assert(selected.artboard?.id === artboardId, `Focus lock expected ${artboardId}, found ${selected.artboard?.id ?? "none"}`);
}

async function hierarchy(artboardId, depth = 8) {
  return tool("get_artboard_hierarchy", { artboardId, depth });
}

async function verifyProtected() {
  const results = {};
  for (const [artboardId, expectedCount] of Object.entries(PROTECTED)) {
    const result = await hierarchy(artboardId, 8);
    const count = result.objects?.length ?? 0;
    assert(count === expectedCount, `Protected artboard ${artboardId} changed: expected ${expectedCount}, found ${count}`);
    results[artboardId] = count;
  }
  return results;
}

async function setTransparentBackground(artboardId) {
  const query = await tool("query_objects", { objectIds: [artboardId], depth: 2 });
  const objects = query.objects ?? [];
  const color = objects.find((object) => object.types?.includes("SolidColor"));
  assert(color?.id, `${artboardId}: missing default SolidColor`);
  await tool("set_property_values", { propertyValues: { [color.id]: { 37: "#00000000" } } });
  const check = await tool("query_property_values", { propertyKeys: { [color.id]: [37] } });
  assert(String(check.values?.[color.id]?.[37]).toLowerCase() === "#00000000", `${artboardId}: background is not transparent`);
  return color.id;
}

function transparentPivotDefinition(parentId, name, x, y) {
  return {
    parentId,
    name,
    x,
    y,
    paints: [{ paintType: "fill", color: "#00000000" }],
    paths: [{ name: `${name}__marker`, commands: [
      { commandType: "moveTo", x: 0, y: 0 },
      { commandType: "lineTo", x: 0.01, y: 0 },
      { commandType: "lineTo", x: 0, y: 0.01 },
      { commandType: "close" },
    ] }],
  };
}

async function createShapes(artboardId, shapes) {
  for (const batch of chunks(shapes, SHAPE_CHUNK)) {
    await focusLock(artboardId);
    await tool("path_editor", { command: "createShapes", data: { createShapes: { shapes: batch } } });
  }
}

async function uniqueNamedObject(artboardId, name, depth = 8) {
  const result = await hierarchy(artboardId, depth);
  const matches = (result.objects ?? []).filter((object) => object.name === name);
  assert(matches.length === 1, `${artboardId}: expected one ${name}, found ${matches.length}`);
  return matches[0];
}

async function createPivot(artboardId, parentId, name, x, y) {
  await createShapes(artboardId, [transparentPivotDefinition(parentId, name, x, y)]);
  return uniqueNamedObject(artboardId, name);
}

function liveShape(parentId, shape) {
  return { parentId, name: shape.name, x: 0, y: 0, paints: [{ paintType: "fill", color: shape.color }], paths: shape.paths };
}

async function createHairComponent(artwork, artboardsBefore) {
  assert(!artboardsBefore.some((artboard) => artboard.name === HAIR_NAME), `Hair component collision: ${HAIR_NAME}`);
  await tool("open_file_editor", { command: "createArtboard", data: { createArtboard: [{ name: HAIR_NAME, x: 2200, y: 560, width: 1, height: 1, isComponent: true }] } });
  const list = await tool("list_artboards", {});
  const matches = (list.artboards ?? []).filter((artboard) => artboard.name === HAIR_NAME);
  assert(matches.length === 1, `Expected one hair component artboard, found ${matches.length}`);
  const hairArtboardId = matches[0].id;
  await focusLock(hairArtboardId);
  await setTransparentBackground(hairArtboardId);
  const hairShapes = artwork.byPart.hair.map((shape) => liveShape(hairArtboardId, shape));
  await createShapes(hairArtboardId, hairShapes);
  const result = await hierarchy(hairArtboardId, 6);
  const authored = (result.objects ?? []).filter((object) => object.types?.includes("Shape")).length;
  assert(authored === hairShapes.length, `Hair component expected ${hairShapes.length} shapes, found ${authored}`);
  return { hairArtboardId, hairShapeCount: authored };
}

async function buildMainArtwork(artwork, hairArtboardId) {
  await focusLock(MAIN_ID);
  await setTransparentBackground(MAIN_ID);
  const ids = new Map();
  const root = await createPivot(MAIN_ID, MAIN_ID, "rig_root", PIVOTS.rig_root.x, PIVOTS.rig_root.y);
  ids.set("rig_root", root.id);
  for (const name of ["rig_base", "rig_stem", "rig_handle_l", "rig_handle_r", "rig_tab", "rig_cup", "rig_badge", "rig_eye_l", "rig_eye_r", "rig_mouth"]) {
    const spec = PIVOTS[name];
    const pivot = await createPivot(MAIN_ID, root.id, name, spec.x, spec.y);
    ids.set(name, pivot.id);
  }

  await focusLock(MAIN_ID);
  const added = await tool("component_editor", {
    command: "addComponents",
    data: { addComponents: [{ artboardId: MAIN_ID, parentId: root.id, componentId: hairArtboardId, mode: "node", x: PIVOTS.rig_hair.x, y: PIVOTS.rig_hair.y }] },
  });
  assert(added.components?.length === 1 && !added.errors?.length, `Hair component placement failed: ${JSON.stringify(added)}`);
  const hairInstanceId = added.components[0].id;
  await tool("rename_objects", { renames: [{ id: hairInstanceId, name: "rig_hair" }] });
  ids.set("rig_hair", hairInstanceId);

  for (const [part, shapes] of Object.entries(artwork.byPart)) {
    if (part === "hair") continue;
    const rigName = SEMANTIC_PARTS[part].rig;
    const parentId = ids.get(rigName);
    assert(parentId, `${part}: missing parent ${rigName}`);
    await createShapes(MAIN_ID, shapes.map((shape) => liveShape(parentId, shape)));
  }

  const backToFront = ["rig_base", "rig_stem", "rig_handle_l", "rig_handle_r", "rig_tab", "rig_cup", "rig_hair", "rig_badge", "rig_eye_l", "rig_eye_r", "rig_mouth"];
  await tool("reorder_objects", { operations: backToFront.map((name) => ({ objectId: ids.get(name), order: "sendToFront" })) });

  const values = await tool("query_property_values", { propertyKeys: Object.fromEntries([...ids.values()].map((id) => [id, [13, 14, 15, 16, 17, 18, 808, 809]])) });
  for (const [name, id] of ids) {
    const actual = values.values?.[id] ?? {};
    const expected = PIVOTS[name];
    assert(Math.abs(Number(actual[13]) - expected.x) < 1e-5, `${name}: x mismatch`);
    assert(Math.abs(Number(actual[14]) - expected.y) < 1e-5, `${name}: y mismatch`);
    assert(Math.abs(Number(actual[15])) < 1e-5 && Number(actual[16]) === 1 && Number(actual[17]) === 1 && Number(actual[18]) === 1, `${name}: neutral transform mismatch`);
  }
  return { ids, values };
}

function absoluteValue(nodeName, property, value) {
  const base = PIVOTS[nodeName];
  if (property === "dx") return base.x + value;
  if (property === "dy") return base.y + value;
  if (property === "rotationDeg") return (value * Math.PI) / 180;
  return value;
}

function authoredKeyframes(performance, ids) {
  const output = [];
  for (const [nodeName, properties] of Object.entries(performance.tracks)) {
    const objectId = ids.get(nodeName);
    assert(objectId, `${performance.slug}: missing ${nodeName}`);
    for (const [property, keys] of Object.entries(properties)) {
      const propertyKey = PROPERTY[property];
      assert(propertyKey, `${performance.slug}: unsupported ${property}`);
      for (const [frame, value] of keys) output.push({ objectId, propertyKey, frame, value: absoluteValue(nodeName, property, value), interpolationType: "cubic", cubicParams: CURVE });
    }
  }
  return output;
}

async function createAnimations(ids) {
  await focusLock(MAIN_ID);
  await tool("animation_editor", { command: "createLinearAnimations", data: { createLinearAnimations: { linearAnimations: PERFORMANCES.map((performance) => ({ name: performance.slug, duration: performance.durationFrames / FPS })) } } });
  const list = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const animations = new Map();
  for (const performance of PERFORMANCES) {
    const matches = (list.linearAnimations ?? []).filter((animation) => animation.name === performance.slug);
    assert(matches.length === 1, `${performance.slug}: expected one animation, found ${matches.length}`);
    animations.set(performance.slug, matches[0]);
  }
  await tool("set_property_values", { propertyValues: Object.fromEntries(PERFORMANCES.map((performance) => [animations.get(performance.slug).id, { [ANIMATION_PROPERTY.fps]: FPS, [ANIMATION_PROPERTY.durationFrames]: performance.durationFrames, [ANIMATION_PROPERTY.loop]: performance.loop ? 1 : 0 }])) });

  const expectedById = new Map();
  for (const performance of PERFORMANCES) {
    const animation = animations.get(performance.slug);
    const keyframes = authoredKeyframes(performance, ids);
    expectedById.set(animation.id, { performance, keyframes });
    for (const batch of chunks(keyframes, KEYFRAME_CHUNK)) {
      await focusLock(MAIN_ID);
      await tool("animation_editor", { command: "modifyKeyFrames", data: { modifyKeyFrames: { animationId: animation.id, add: batch } } });
    }
  }
  const query = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds: [...animations.values()].map((animation) => animation.id) } } });
  for (const [animationId, expected] of expectedById) {
    const actual = query.keyframes?.[animationId] ?? [];
    assert(actual.length === expected.keyframes.length, `${expected.performance.slug}: expected ${expected.keyframes.length} queried keys, found ${actual.length}`);
    const byTuple = new Map(actual.map((keyframe) => [`${keyframe.objectId}/${Number(keyframe.propertyKey)}/${Number(keyframe.frame)}`, keyframe]));
    for (const keyframe of expected.keyframes) {
      const tuple = `${keyframe.objectId}/${keyframe.propertyKey}/${keyframe.frame}`;
      const found = byTuple.get(tuple);
      assert(found && Math.abs(Number(found.value) - keyframe.value) < 1e-4, `${expected.performance.slug}: queried key mismatch ${tuple}`);
    }
  }
  return { animations, query };
}

async function createStateMachine(animations) {
  await focusLock(MAIN_ID);
  const states = PERFORMANCES.map((performance, index) => ({ name: performance.label, x: 160 + index * 215, y: 140, linearAnimationName: performance.slug }));
  await tool("animation_editor", { command: "createStateMachine", data: { createStateMachine: { name: "ScoreKeeper Cup Hybrid A Behaviors v2", layers: [{ name: "Performances", states, otherTransitions: [{ from: "{Entry State}", to: PERFORMANCES[0].label }] }] } } });
  const list = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const matches = (list.stateMachines ?? []).filter((machine) => machine.name === "ScoreKeeper Cup Hybrid A Behaviors v2");
  assert(matches.length === 1, `Expected one v2 state machine, found ${matches.length}`);
  const queried = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: matches[0].id } } });
  const serialized = JSON.stringify(queried);
  for (const animation of animations.values()) assert(serialized.includes(animation.id), `State machine is not mapped to ${animation.name}`);
  return { id: matches[0].id, query: queried };
}

function normalizeInterpolation(keyframe) {
  const interpolation = String(keyframe.interpolationType ?? keyframe.interpolation ?? "cubic");
  return ["linear", "hold", "cubic"].includes(interpolation) ? interpolation : "cubic";
}

function queriedExport(ids, animations, query) {
  const nameById = new Map([...ids].map(([name, id]) => [id, name]));
  const propertyByKey = new Map([[13, "dx"], [14, "dy"], [15, "rotationDeg"], [16, "scaleX"], [17, "scaleY"], [18, "opacity"]]);
  const nodes = [];
  for (const [name, spec] of Object.entries(PIVOTS)) {
    nodes.push({ name, parent: spec.parent, kind: spec.kind ?? "pivot", transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: spec.pivot } });
  }
  for (const [part, spec] of Object.entries(SEMANTIC_PARTS)) {
    nodes.push({ name: `asset_${part}`, parent: spec.rig, kind: "asset", source: "canonical-svg", semanticPart: part, sourceElementIndices: spec.indices, transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: { x: 0, y: 0 } } });
  }

  const normalizedAnimations = {};
  for (const performance of PERFORMANCES) {
    const animation = animations.get(performance.slug);
    const tracks = {};
    for (const keyframe of query.keyframes?.[animation.id] ?? []) {
      const nodeName = nameById.get(keyframe.objectId);
      const property = propertyByKey.get(Number(keyframe.propertyKey));
      assert(nodeName && property, `${performance.slug}: queried unknown target/property`);
      let value = Number(keyframe.value);
      if (property === "dx") value -= PIVOTS[nodeName].x;
      if (property === "dy") value -= PIVOTS[nodeName].y;
      if (property === "rotationDeg") value = (value * 180) / Math.PI;
      const cubic = keyframe.cubicParams ?? CURVE;
      (((tracks[nodeName] ??= {})[property] ??= [])).push({ frame: Number(keyframe.frame), value, interpolation: normalizeInterpolation(keyframe), curve: [Number(cubic.x1 ?? CURVE.x1), Number(cubic.y1 ?? CURVE.y1), Number(cubic.x2 ?? CURVE.x2), Number(cubic.y2 ?? CURVE.y2)] });
    }
    for (const properties of Object.values(tracks)) for (const keys of Object.values(properties)) keys.sort((left, right) => left.frame - right.frame);
    normalizedAnimations[performance.slug] = { label: performance.label, durationFrames: performance.durationFrames, loop: performance.loop, contactFrames: performance.contactFrames, tracks };
  }
  return {
    schema: "scorekeeper.rive-live-keyframes/v1",
    source: { path: "../production-v5-vector-master/canonical-dimensional-pixel.svg", sha256: APPROVED_SHA256 },
    canvas: { width: 512, height: 416 },
    fps: FPS,
    artboard: MAIN_NAME,
    nodes,
    animations: normalizedAnimations,
  };
}

async function main() {
  validateMotionSpec();
  const artwork = loadApprovedArtwork();
  await initialize();
  const before = await tool("list_artboards", {});
  assert((before.artboards ?? []).some((artboard) => artboard.id === MAIN_ID && artboard.name === MAIN_NAME), "Exact temp artboard is not open");
  assert(!(before.artboards ?? []).some((artboard) => artboard.name === FINAL_NAME), `Final-name collision: ${FINAL_NAME}`);
  const protectedBefore = await verifyProtected();
  const mainBefore = await hierarchy(MAIN_ID, 8);
  assert((mainBefore.objects ?? []).length === 4, `Temp artboard is not pristine: expected 4 default objects, found ${(mainBefore.objects ?? []).length}`);

  const hair = await createHairComponent(artwork, before.artboards ?? []);
  const main = await buildMainArtwork(artwork, hair.hairArtboardId);
  const authored = await createAnimations(main.ids);
  const stateMachine = await createStateMachine(authored.animations);
  const liveExport = queriedExport(main.ids, authored.animations, authored.query);
  fs.writeFileSync(LIVE_EXPORT, `${JSON.stringify(liveExport, null, 2)}\n`);
  const protectedAfter = await verifyProtected();
  const finalHierarchy = await hierarchy(MAIN_ID, 8);
  const summary = {
    status: "built-temp-awaiting-qa",
    sourceSha256: artwork.sha256,
    mainArtboardId: MAIN_ID,
    mainArtboardName: MAIN_NAME,
    hairComponentArtboardId: hair.hairArtboardId,
    hairComponentArtboardName: HAIR_NAME,
    hairIsNestedArtboard: true,
    transparentBackgrounds: true,
    scanlineShapeCount: artwork.shapes.length,
    mainObjectCount: finalHierarchy.objects?.length ?? 0,
    pivots: Object.fromEntries(main.ids),
    animations: Object.fromEntries([...authored.animations].map(([slug, animation]) => [slug, animation.id])),
    stateMachineId: stateMachine.id,
    protectedBefore,
    protectedAfter,
    liveExport: LIVE_EXPORT,
    finalRenamePerformed: false,
  };
  fs.writeFileSync(SUMMARY_PATH, `${JSON.stringify(summary, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? error.message ?? String(error));
  process.exitCode = 1;
});
