#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CURVES, FPS, PERFORMANCES, PIVOTS, motionSpecHash, validateMotionSpec } from "./motion-spec-v3.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const V7_ROOT = path.dirname(ROOT);
const STATUS_PATH = path.join(V7_ROOT, "evidence/opencode/opencode-status.md");
const SOURCE_PATH = path.resolve(V7_ROOT, "../production-v5-vector-master/canonical-dimensional-pixel.svg");
const SOURCE_SHA256 = "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75";
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const RUN_ID = process.env.OPENCODE_RUN_ID ?? `root-recovery-${new Date().toISOString().replaceAll(/[-:.]/g, "")}`;
const TEMP_NAME = process.env.RIVE_V3_TEMP_NAME ?? `__V3_TEMP__ ScoreKeeper Cup Hybrid A ${RUN_ID}`;
const MACHINE_NAME = process.env.RIVE_V3_MACHINE_NAME ?? `__V3_TEMP__ ScoreKeeper Cup Behaviors ${RUN_ID}`;
const RESUME_TEMP_ID = process.env.RIVE_RESUME_TEMP_ID ?? "";
const V2_ID = "0-16469";
const V2_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v2";
const HAIR_ID = "0-17790";
const V2_MACHINE_ID = "0-32339";
const FINAL_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v3";
const PROPERTY = Object.freeze({ dx: 13, dy: 14, rotationDeg: 15, scaleX: 16, scaleY: 17, opacity: 18 });
const ANIMATION_PROPERTY = Object.freeze({ fps: 56, durationFrames: 57, loop: 59 });
const KEYFRAME_CHUNK = 90;
let rpcId = 1;

function assert(condition, message) { if (!condition) throw new Error(message); }
function sha(value) { return crypto.createHash("sha256").update(Buffer.isBuffer(value) || typeof value === "string" ? value : JSON.stringify(value)).digest("hex"); }
function writeJson(name, value) { fs.writeFileSync(path.join(ROOT, name), `${JSON.stringify(value, null, 2)}\n`); }
function appendStatus(step, details) { fs.appendFileSync(STATUS_PATH, `\n- ${new Date().toISOString()} — ${step}; ${details}`); }
function chunks(items, size) { const result = []; for (let i = 0; i < items.length; i += size) result.push(items.slice(i, i + size)); return result; }

async function request(payload) {
  const response = await fetch(MCP_URL, { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" }, body: JSON.stringify(payload) });
  if (response.status === 202) return {};
  if (!response.ok) throw new Error(`Rive MCP HTTP ${response.status} ${response.statusText}`);
  const result = await response.json();
  if (result.error) throw new Error(result.error.message ?? JSON.stringify(result.error));
  return result;
}
async function rpc(method, params = {}) { return (await request({ jsonrpc: "2.0", id: rpcId++, method, params })).result; }
async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  let parsed = result;
  if (text) { try { parsed = JSON.parse(text); } catch { parsed = text; } }
  if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}
async function initialize() {
  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-production-rig-v3-root-recovery", version: "1" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
}
async function focus(artboardId) {
  await tool("open_file_editor", { command: "focusArtboard", data: { focusArtboard: { artboardId, fitToViewport: true } } });
  await new Promise((resolve) => setTimeout(resolve, 160));
  const selected = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  assert(selected.artboard?.id === artboardId, `focus expected ${artboardId}, found ${selected.artboard?.id ?? "none"}`);
}
async function hierarchy(artboardId) { return tool("get_artboard_hierarchy", { artboardId, depth: 8 }); }

function treeProjection(hierarchyResult) {
  const objects = hierarchyResult.objects ?? [];
  const byId = new Map(objects.map((object) => [object.id, object]));
  const referenced = new Set(objects.flatMap((object) => object.children ?? []));
  const fingerprint = (objectId, stack = new Set()) => {
    if (stack.has(objectId)) return { cycle: true };
    const object = byId.get(objectId);
    if (!object) return { missing: true };
    const next = new Set(stack).add(objectId);
    const types = [...(object.types ?? [])].sort();
    return { name: types.includes("Artboard") ? "__ARTBOARD__" : object.name, types, children: (object.children ?? []).map((childId) => fingerprint(childId, next)) };
  };
  return objects.filter((object) => !referenced.has(object.id)).map((object) => fingerprint(object.id));
}

async function snapshotActive(artboardId) {
  await focus(artboardId);
  const h = await hierarchy(artboardId);
  const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const animationIds = (animations.linearAnimations ?? []).map((item) => item.id);
  const settings = animationIds.length ? await tool("query_property_values", { propertyKeys: Object.fromEntries(animationIds.map((id) => [id, [56, 57, 59]])) }) : { values: {} };
  const keyframes = animationIds.length ? await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds } } }) : { keyframes: {} };
  const machines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const machineDetails = [];
  for (const machine of machines.stateMachines ?? []) machineDetails.push(await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machine.id } } }));
  return { artboardId, hierarchy: h, animations, settings, keyframes, machines, machineDetails };
}

function stableProtected(snapshot) {
  return {
    artboardId: snapshot.artboardId,
    hierarchy: snapshot.hierarchy,
    animations: snapshot.animations,
    settings: snapshot.settings,
    keyframes: snapshot.keyframes,
    machines: snapshot.machines,
    machineDetails: snapshot.machineDetails,
  };
}

async function protectedSnapshot() {
  const v2 = await snapshotActive(V2_ID);
  const hairHierarchy = await hierarchy(HAIR_ID);
  return { v2: stableProtected(v2), hair: hairHierarchy };
}

function namedIds(hierarchyResult) {
  const map = new Map();
  for (const name of Object.keys(PIVOTS)) {
    const matches = (hierarchyResult.objects ?? []).filter((object) => object.name === name);
    assert(matches.length === 1, `expected one ${name}, found ${matches.length}`);
    map.set(name, matches[0].id);
  }
  return map;
}

async function bindValues(idsByName) {
  const values = await tool("query_property_values", { propertyKeys: Object.fromEntries([...idsByName.values()].map((id) => [id, [13, 14, 15, 16, 17, 18, 808, 809]])) });
  return Object.fromEntries([...idsByName].map(([name, id]) => [name, values.values?.[id] ?? {}]));
}

function compareBind(v2Values, v3Values) {
  const errors = [];
  for (const name of Object.keys(PIVOTS)) {
    for (const key of [13, 14, 15, 16, 17, 18, 808, 809]) {
      const left = v2Values[name]?.[key];
      const right = v3Values[name]?.[key];
      if (left === undefined && right === undefined) continue;
      if (Number.isFinite(Number(left)) && Number.isFinite(Number(right))) {
        if (Math.abs(Number(left) - Number(right)) > 1e-6) errors.push(`${name}/${key}: ${left} != ${right}`);
      } else if (String(left) !== String(right)) errors.push(`${name}/${key}: ${left} != ${right}`);
    }
  }
  return errors;
}

function absoluteValue(nodeName, property, value) {
  if (property === "dx") return PIVOTS[nodeName].x + value;
  if (property === "dy") return PIVOTS[nodeName].y + value;
  if (property === "rotationDeg") return value * Math.PI / 180;
  return value;
}

function authoredKeys(performance, idsByName) {
  const result = [];
  for (const [nodeName, properties] of Object.entries(performance.tracks)) {
    const objectId = idsByName.get(nodeName);
    assert(objectId, `${performance.slug}: missing ${nodeName}`);
    for (const [property, keys] of Object.entries(properties)) {
      const propertyKey = PROPERTY[property];
      assert(propertyKey, `${performance.slug}: unsupported property ${property}`);
      for (const [frame, value, curveName] of keys) {
        const [x1, y1, x2, y2] = CURVES[curveName];
        result.push({ objectId, propertyKey, frame, value: absoluteValue(nodeName, property, value), interpolationType: "cubic", cubicParams: { x1, y1, x2, y2 } });
      }
    }
  }
  return result;
}

async function replaceAnimationKeys(tempId, animationsBySlug, idsByName) {
  const animationIds = [...animationsBySlug.values()].map((animation) => animation.id);
  const old = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds } } });
  for (const [slug, animation] of animationsBySlug) {
    const oldIds = (old.keyframes?.[animation.id] ?? []).map((keyframe) => keyframe.keyframeId ?? keyframe.id).filter(Boolean);
    for (const batch of chunks(oldIds, KEYFRAME_CHUNK)) {
      await focus(tempId);
      await tool("animation_editor", { command: "modifyKeyFrames", data: { modifyKeyFrames: { animationId: animation.id, delete: batch } } });
    }
    const performance = PERFORMANCES.find((item) => item.slug === slug);
    for (const batch of chunks(authoredKeys(performance, idsByName), KEYFRAME_CHUNK)) {
      await focus(tempId);
      await tool("animation_editor", { command: "modifyKeyFrames", data: { modifyKeyFrames: { animationId: animation.id, add: batch } } });
    }
  }
}

function normalizeLiveExport(idsByName, animationsBySlug, keyframeQuery) {
  const nameById = new Map([...idsByName].map(([name, id]) => [id, name]));
  const propertyByKey = new Map([[13, "dx"], [14, "dy"], [15, "rotationDeg"], [16, "scaleX"], [17, "scaleY"], [18, "opacity"]]);
  const animations = {};
  for (const performance of PERFORMANCES) {
    const animation = animationsBySlug.get(performance.slug);
    const tracks = {};
    for (const keyframe of keyframeQuery.keyframes?.[animation.id] ?? []) {
      const nodeName = nameById.get(keyframe.objectId);
      const property = propertyByKey.get(Number(keyframe.propertyKey));
      assert(nodeName && property, `${performance.slug}: unknown queried key ${keyframe.objectId}/${keyframe.propertyKey}`);
      let value = Number(keyframe.value);
      if (property === "dx") value -= PIVOTS[nodeName].x;
      if (property === "dy") value -= PIVOTS[nodeName].y;
      if (property === "rotationDeg") value = value * 180 / Math.PI;
      const cubic = keyframe.cubicParams ?? {};
      (((tracks[nodeName] ??= {})[property] ??= [])).push({ id: keyframe.id, frame: Number(keyframe.frame), value: Math.abs(value) < 1e-10 ? 0 : value, interpolation: keyframe.interpolationType ?? "cubic", curve: [Number(cubic.x1), Number(cubic.y1), Number(cubic.x2), Number(cubic.y2)] });
    }
    for (const properties of Object.values(tracks)) for (const keys of Object.values(properties)) keys.sort((a, b) => a.frame - b.frame);
    animations[performance.slug] = { id: animation.id, durationFrames: performance.durationFrames, loop: performance.loop, tracks };
  }
  return { schema: "scorekeeper.rive-live-keyframes/v3", source: { path: SOURCE_PATH, sha256: SOURCE_SHA256 }, canvas: { width: 512, height: 416 }, fps: FPS, artboard: { id: [...animationsBySlug.values()][0]?.artboardId, name: TEMP_NAME }, specHash: motionSpecHash(), animations };
}

async function main() {
  const specValidation = validateMotionSpec();
  assert(sha(fs.readFileSync(SOURCE_PATH)) === SOURCE_SHA256, "approved source hash mismatch");
  appendStatus("root recovery builder start", `run ${RUN_ID}; temp ${TEMP_NAME}; no live writes yet.`);
  await initialize();
  const tools = await rpc("tools/list");
  const toolNames = new Set((tools.tools ?? []).map((item) => item.name));
  for (const required of ["list_artboards", "duplicate_objects", "rename_objects", "delete_objects", "animation_editor", "get_artboard_hierarchy", "query_property_values", "set_property_values"]) assert(toolNames.has(required), `missing MCP tool ${required}`);

  const currentList = await tool("list_artboards", {});
  const currentArtboards = currentList.artboards ?? [];
  assert(currentArtboards.some((item) => item.id === V2_ID && item.name === V2_NAME), "exact v2 target mismatch");
  assert(currentArtboards.some((item) => item.id === HAIR_ID), "protected hair component missing");
  assert(!currentArtboards.some((item) => item.name === FINAL_NAME), "final name collision");

  let protectedBefore;
  let protectedBeforeHash;
  let transaction;
  let tempId;
  if (RESUME_TEMP_ID) {
    assert(currentArtboards.length === 7, `resume expected seven artboards, found ${currentArtboards.length}`);
    assert(currentArtboards.some((item) => item.id === RESUME_TEMP_ID && item.name === TEMP_NAME), "resume temp identity mismatch");
    const saved = JSON.parse(fs.readFileSync(path.join(ROOT, "protected-before.json"), "utf8"));
    protectedBefore = saved.snapshot;
    protectedBeforeHash = saved.hash;
    const currentProtected = await protectedSnapshot();
    assert(sha(currentProtected) === protectedBeforeHash, "protected state changed before resume");
    transaction = JSON.parse(fs.readFileSync(path.join(ROOT, "transaction.json"), "utf8"));
    assert(transaction.phase === "duplicated" && transaction.tempArtboardId === RESUME_TEMP_ID && transaction.specHash === motionSpecHash(), "resume transaction mismatch");
    tempId = RESUME_TEMP_ID;
    appendStatus("resume verified", `temp ${tempId}; protected hash unchanged; resuming after neutral parity.`);
  } else {
    assert(currentArtboards.length === 6, `expected six original artboards, found ${currentArtboards.length}`);
    assert(currentArtboards.some((item) => item.id === V2_ID && item.isActive), "v2 must be active before first write");
    assert(!currentArtboards.some((item) => item.name === TEMP_NAME), "temp name collision");
    protectedBefore = await protectedSnapshot();
    protectedBeforeHash = sha(protectedBefore);
    writeJson("protected-before.json", { hash: protectedBeforeHash, snapshot: protectedBefore });
    transaction = { runId: RUN_ID, phase: "preflight-passed", targetFileId: "2434585", sourceSha256: SOURCE_SHA256, specHash: motionSpecHash(), protected: { v2ArtboardId: V2_ID, hairComponentId: HAIR_ID, stateMachineId: V2_MACHINE_ID, beforeHash: protectedBeforeHash }, intendedTempName: TEMP_NAME, intendedMachineName: MACHINE_NAME, artboardsBefore: currentArtboards.map(({ id, name }) => ({ id, name })), publishPerformed: false };
    writeJson("transaction.json", transaction);
    appendStatus("preflight passed", `six artboards; protected hash ${protectedBeforeHash}; source/spec validated.`);
    await focus(V2_ID);
    await tool("duplicate_objects", { objectIds: [V2_ID] });
    const afterDuplicateList = await tool("list_artboards", {});
    const afterArtboards = afterDuplicateList.artboards ?? [];
    const beforeIds = new Set(currentArtboards.map((item) => item.id));
    const created = afterArtboards.filter((item) => !beforeIds.has(item.id));
    assert(afterArtboards.length === 7 && created.length === 1, `ambiguous duplicate: total ${afterArtboards.length}, created ${created.length}`);
    tempId = created[0].id;
    await tool("rename_objects", { renames: [{ id: tempId, name: TEMP_NAME }] });
    await focus(tempId);
    const namedTemp = await tool("list_artboards", {});
    assert((namedTemp.artboards ?? []).filter((item) => item.id === tempId && item.name === TEMP_NAME).length === 1, "temp rename verification failed");
    transaction.phase = "duplicated";
    transaction.tempArtboardId = tempId;
    writeJson("transaction.json", transaction);
    appendStatus("duplicate verified", `temp artboard ${tempId} ${TEMP_NAME}; exactly seven artboards.`);
  }

  const v2Hierarchy = await hierarchy(V2_ID);
  const tempHierarchy = await hierarchy(tempId);
  const v2Descendants = new Set((v2Hierarchy.objects ?? []).map((item) => item.id));
  assert(!(tempHierarchy.objects ?? []).some((item) => v2Descendants.has(item.id)), "duplicate descendant IDs overlap protected v2");
  const v2Tree = treeProjection(v2Hierarchy);
  const tempTree = treeProjection(tempHierarchy);
  const v2Ids = namedIds(v2Hierarchy);
  const tempIds = namedIds(tempHierarchy);
  const v2Bind = await bindValues(v2Ids);
  const tempBind = await bindValues(tempIds);
  const bindErrors = compareBind(v2Bind, tempBind);
  assert(bindErrors.length === 0, `neutral bind parity failed: ${bindErrors.join("; ")}`);
  let parity;
  if (RESUME_TEMP_ID) {
    const savedParity = JSON.parse(fs.readFileSync(path.join(ROOT, "bind-parity.json"), "utf8"));
    assert(savedParity.passed && savedParity.v2ObjectCount === 12786 && savedParity.v3ObjectCount === 12786, "saved pre-cleanup parity checkpoint invalid");
    parity = { ...savedParity, resumeBindErrors: bindErrors, resumedAfterOwnedMetadataCleanup: true };
  } else {
    assert(sha(v2Tree) === sha(tempTree), "neutral hierarchy/tree parity failed");
    parity = { passed: true, v2ObjectCount: v2Hierarchy.objects?.length ?? 0, v3ObjectCount: tempHierarchy.objects?.length ?? 0, treeHash: sha(v2Tree), bindErrors };
  }
  writeJson("bind-parity.json", parity);
  appendStatus("neutral parity passed", `object count ${parity.v3ObjectCount}; tree ${parity.treeHash}.`);

  await focus(tempId);
  const listedAnimations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const animationsBySlug = new Map();
  for (const performance of PERFORMANCES) {
    const matches = (listedAnimations.linearAnimations ?? []).filter((item) => item.name === performance.slug);
    assert(matches.length === 1, `${performance.slug}: expected one duplicated timeline, found ${matches.length}`);
    animationsBySlug.set(performance.slug, matches[0]);
  }
  const disposableAnimationIds = (listedAnimations.linearAnimations ?? []).filter((item) => item.name === "Timeline 1").map((item) => item.id);
  const listedMachines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const disposableMachineIds = (listedMachines.stateMachines ?? []).map((item) => item.id);
  const deleteIds = [...disposableAnimationIds, ...disposableMachineIds];
  assert(deleteIds.every((id) => ![V2_ID, HAIR_ID, V2_MACHINE_ID].includes(id)), "cleanup allowlist contains protected ID");
  if (deleteIds.length) await tool("delete_objects", { objectIds: deleteIds });

  await focus(tempId);
  await tool("set_property_values", { propertyValues: Object.fromEntries(PERFORMANCES.map((performance) => [animationsBySlug.get(performance.slug).id, { [ANIMATION_PROPERTY.fps]: FPS, [ANIMATION_PROPERTY.durationFrames]: performance.durationFrames, [ANIMATION_PROPERTY.loop]: performance.loop ? 1 : 0 }])) });
  await replaceAnimationKeys(tempId, animationsBySlug, tempIds);
  appendStatus("five timelines rewritten", `spec ${motionSpecHash()}; per-beat cubic curves authored.`);

  await focus(tempId);
  const states = PERFORMANCES.map((performance, index) => ({ name: performance.slug === "idle_breathe_blink" ? "Idle" : performance.label, x: 160 + index * 210, y: 140, linearAnimationName: performance.slug }));
  await tool("animation_editor", { command: "createStateMachine", data: { createStateMachine: { name: MACHINE_NAME, layers: [{ name: "Performances", states, otherTransitions: [{ from: "{Entry State}", to: "Idle" }] }] } } });
  let machineList = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const machineMatches = (machineList.stateMachines ?? []).filter((item) => item.name === MACHINE_NAME);
  assert(machineMatches.length === 1, `expected one v3 machine, found ${machineMatches.length}`);
  const machineId = machineMatches[0].id;
  let machineQuery = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machineId } } });
  const emptyLayerIds = (machineQuery.layers ?? []).filter((layer) => !(layer.states ?? []).some((state) => state.type === "animation")).map((layer) => layer.layerId ?? layer.id).filter(Boolean);
  if (emptyLayerIds.length) {
    await tool("delete_objects", { objectIds: emptyLayerIds });
    machineQuery = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machineId } } });
  }
  const performanceLayer = (machineQuery.layers ?? []).find((layer) => layer.layerName === "Performances");
  assert(performanceLayer, "Performances layer missing");
  const animationStates = (performanceLayer.states ?? []).filter((state) => state.type === "animation");
  const animationIdByStateName = new Map(PERFORMANCES.map((performance) => [performance.slug === "idle_breathe_blink" ? "Idle" : performance.label, animationsBySlug.get(performance.slug).id]));
  assert(animationStates.length === 5 && animationStates.every((state) => animationIdByStateName.has(state.stateName ?? state.name)), "v3 machine state inventory mismatch");
  await tool("animation_editor", { command: "updateStates", data: { updateStates: { states: animationStates.map((state) => ({ id: state.id, animationId: animationIdByStateName.get(state.stateName ?? state.name) })) } } });
  machineQuery = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machineId } } });

  await focus(tempId);
  const finalAnimations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const finalAnimationIds = [...animationsBySlug.values()].map((item) => item.id);
  const finalSettings = await tool("query_property_values", { propertyKeys: Object.fromEntries(finalAnimationIds.map((id) => [id, [56, 57, 59]])) });
  const finalKeys = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds: finalAnimationIds } } });
  const qaErrors = [];
  if ((finalAnimations.linearAnimations ?? []).length !== 5 || (finalAnimations.linearAnimations ?? []).some((item) => item.name === "Timeline 1")) qaErrors.push("timeline inventory mismatch");
  for (const performance of PERFORMANCES) {
    const animation = animationsBySlug.get(performance.slug);
    const values = finalSettings.values?.[animation.id] ?? {};
    if (Number(values[56]) !== FPS || Number(values[57]) !== performance.durationFrames || Number(values[59]) !== (performance.loop ? 1 : 0)) qaErrors.push(`${performance.slug}: settings mismatch`);
    const expectedCount = authoredKeys(performance, tempIds).length;
    if ((finalKeys.keyframes?.[animation.id] ?? []).length !== expectedCount) qaErrors.push(`${performance.slug}: key count mismatch`);
  }
  const layers = machineQuery.layers ?? [];
  const authoredStates = layers.flatMap((layer) => layer.states ?? []).filter((state) => state.type === "animation");
  const transitions = layers.flatMap((layer) => layer.transitions ?? []);
  if (layers.length !== 1 || authoredStates.length !== 5 || transitions.length !== 1 || (transitions[0]?.conditions ?? []).length !== 0) qaErrors.push("state machine layer/state/transition mismatch");
  if ((machineQuery.inputs ?? []).length || (machineQuery.listeners ?? []).length) qaErrors.push("state machine is not mapping-only");
  const mappedIds = new Set(authoredStates.map((state) => state.animationId).filter((value) => value && value !== "0-0"));
  for (const id of finalAnimationIds) if (!mappedIds.has(id)) qaErrors.push(`machine missing animation ${id}`);

  const protectedAfter = await protectedSnapshot();
  const protectedAfterHash = sha(protectedAfter);
  writeJson("protected-after.json", { hash: protectedAfterHash, snapshot: protectedAfter });
  if (protectedAfterHash !== protectedBeforeHash) qaErrors.push("protected state hash changed");
  const finalHierarchy = await hierarchy(tempId);
  const liveExport = normalizeLiveExport(tempIds, animationsBySlug, finalKeys);
  liveExport.artboard = { id: tempId, name: TEMP_NAME };
  writeJson("live-keyframes-v3.json", liveExport);
  writeJson("live-hierarchy-v3.json", finalHierarchy);
  writeJson("live-state-machine-v3.json", machineQuery);
  const builderQa = { passed: qaErrors.length === 0, errors: qaErrors, bindParity: parity, protectedBeforeHash, protectedAfterHash, specValidation, artboardCount: (await tool("list_artboards", {})).artboards?.length ?? 0, timelineCount: (finalAnimations.linearAnimations ?? []).length, machine: { id: machineId, name: MACHINE_NAME, layerCount: layers.length, stateCount: authoredStates.length, transitionCount: transitions.length, inputCount: (machineQuery.inputs ?? []).length, listenerCount: (machineQuery.listeners ?? []).length } };
  writeJson("builder-local-qa.json", builderQa);
  assert(builderQa.passed, `builder-local QA failed: ${qaErrors.join("; ")}`);

  transaction.phase = "built-temp-awaiting-independent-qa";
  transaction.tempArtboardId = tempId;
  transaction.tempMachineId = machineId;
  transaction.animationIds = Object.fromEntries([...animationsBySlug].map(([slug, item]) => [slug, item.id]));
  transaction.protectedAfterHash = protectedAfterHash;
  writeJson("transaction.json", transaction);
  const summary = { status: transaction.phase, targetFileId: "2434585", sourceSha256: SOURCE_SHA256, specHash: motionSpecHash(), mainArtboardId: tempId, mainArtboardName: TEMP_NAME, animationIds: transaction.animationIds, stateMachineId: machineId, stateMachineName: MACHINE_NAME, mainObjectCount: finalHierarchy.objects?.length ?? 0, protectedHash: protectedAfterHash, finalRenamePerformed: false, publishPerformed: false };
  writeJson("live-build-summary.json", summary);
  fs.writeFileSync(path.join(ROOT, "implementation-report.md"), `# V3 live implementation\n\n- Status: built temporary awaiting independent QA\n- Target file: 2434585\n- Artboard: ${TEMP_NAME} (${tempId})\n- Machine: ${MACHINE_NAME} (${machineId})\n- Source SHA-256: ${SOURCE_SHA256}\n- Spec SHA-256: ${motionSpecHash()}\n- Protected before/after: ${protectedBeforeHash} / ${protectedAfterHash}\n- Publish performed: false\n- Builder-local QA: passed\n- Caveat: OpenCode GLM Max exhausted its response before tool emission; root recovery authored and ran this transaction.\n`);
  appendStatus("live temp built", `artboard ${tempId}; machine ${machineId}; five timelines; builder QA passed; publish false.`);
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
}

main().catch((error) => {
  appendStatus("builder stopped", `run ${RUN_ID}; ${String(error.message ?? error).replaceAll("\n", " ")}`);
  console.error(error.stack ?? String(error));
  process.exitCode = 1;
});
