#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CURVES, FPS, PERFORMANCES, PIVOTS, motionSpecHash } from "./motion-spec-v3.mjs";
import { BRIDGES } from "./underlap-spec-v3.mjs";
import { SEMANTIC_PARTS } from "../../production-v6-rive-rig/artwork-scanlines.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const ARTBOARD_ID = process.env.RIVE_V3_ARTBOARD_ID ?? "0-32354";
const ARTBOARD_NAME = process.env.RIVE_V3_TEMP_NAME ?? "__V3_TEMP__ ScoreKeeper Cup Hybrid A 20260715T1415Z-root-recovery";
const MACHINE_ID = process.env.RIVE_V3_MACHINE_ID ?? "0-48286";
const SOURCE_SHA256 = "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75";
const PROPERTY = new Map([[13, "dx"], [14, "dy"], [15, "rotationDeg"], [16, "scaleX"], [17, "scaleY"], [18, "opacity"]]);
let rpcId = 1;

function assert(condition, message) { if (!condition) throw new Error(message); }
function sha(value) { return crypto.createHash("sha256").update(typeof value === "string" ? value : JSON.stringify(value)).digest("hex"); }
function writeJson(name, value) { fs.writeFileSync(path.join(ROOT, name), `${JSON.stringify(value, null, 2)}\n`); }
async function request(payload) {
  const response = await fetch(URL, { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" }, body: JSON.stringify(payload) });
  if (response.status === 202) return {};
  if (!response.ok) throw new Error(`Rive MCP HTTP ${response.status}`);
  const body = await response.json();
  if (body.error) throw new Error(body.error.message ?? JSON.stringify(body.error));
  return body;
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
async function focus() {
  await tool("open_file_editor", { command: "focusArtboard", data: { focusArtboard: { artboardId: ARTBOARD_ID, fitToViewport: true } } });
  const selected = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  assert(selected.artboard?.id === ARTBOARD_ID, `focus mismatch ${selected.artboard?.id}`);
}
function absoluteValue(nodeName, property, value) {
  if (property === "dx") return PIVOTS[nodeName].x + value;
  if (property === "dy") return PIVOTS[nodeName].y + value;
  if (property === "rotationDeg") return value * Math.PI / 180;
  return value;
}
function expectedTuples(performance, idsByName) {
  const tuples = new Map();
  for (const [nodeName, properties] of Object.entries(performance.tracks)) {
    for (const [property, keys] of Object.entries(properties)) {
      const propertyKey = [...PROPERTY].find(([, name]) => name === property)?.[0];
      for (const [frame, value, curveName] of keys) tuples.set(`${idsByName.get(nodeName)}/${propertyKey}/${frame}`, { nodeName, property, frame, value: absoluteValue(nodeName, property, value), curveName, curve: CURVES[curveName] });
    }
  }
  return tuples;
}
function expectedBridgeTuples(performance, bridgeIdsByName) {
  if (!["victory_pop", "curious_tilt", "celebrate_shimmy"].includes(performance.slug)) return new Map();
  const tuples = new Map();
  for (const [name, id] of bridgeIdsByName) for (const [frame, value] of [[0, 0], [1, 1], [performance.durationFrames - 1, 1], [performance.durationFrames, 0]]) {
    tuples.set(`${id}/18/${frame}`, { name, frame, value });
  }
  return tuples;
}

async function main() {
  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-v3-independent-live-query", version: "1" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
  const artboards = await tool("list_artboards", {});
  assert((artboards.artboards ?? []).length === 7, "expected seven artboards");
  assert((artboards.artboards ?? []).some((item) => item.id === ARTBOARD_ID && item.name === ARTBOARD_NAME), "candidate identity mismatch");
  await focus();
  const hierarchy = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
  const idsByName = new Map();
  for (const name of Object.keys(PIVOTS)) {
    const matches = (hierarchy.objects ?? []).filter((object) => object.name === name);
    assert(matches.length === 1, `${name}: expected one live object`);
    idsByName.set(name, matches[0].id);
  }
  const bridgeIdsByName = new Map();
  for (const bridge of BRIDGES) {
    const matches = (hierarchy.objects ?? []).filter((object) => object.name === bridge.name);
    assert(matches.length === 1, `${bridge.name}: expected one motion bridge`);
    bridgeIdsByName.set(bridge.name, matches[0].id);
  }
  const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  assert((animations.linearAnimations ?? []).length === 5, "candidate must have five timelines");
  const animationsBySlug = new Map();
  for (const performance of PERFORMANCES) {
    const matches = (animations.linearAnimations ?? []).filter((item) => item.name === performance.slug);
    assert(matches.length === 1, `${performance.slug}: timeline mismatch`);
    animationsBySlug.set(performance.slug, matches[0]);
  }
  const animationIds = [...animationsBySlug.values()].map((item) => item.id);
  const settings = await tool("query_property_values", { propertyKeys: Object.fromEntries(animationIds.map((id) => [id, [56, 57, 59]])) });
  const keyframes = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds } } });
  const interpolatorIds = [...new Set(Object.values(keyframes.keyframes ?? {}).flat().map((keyframe) => keyframe.interpolatorId).filter(Boolean))];
  const interpolators = await tool("query_property_values", { propertyKeys: Object.fromEntries(interpolatorIds.map((id) => [id, [63, 64, 65, 66]])) });
  const allowedSignatures = new Set(Object.values(CURVES).map((curve) => curve.map((value) => Number(value).toFixed(2)).join(",")));
  const curveSignatureCounts = {};
  const errors = [];
  const bridgeBaseOpacity = await tool("query_property_values", { propertyKeys: Object.fromEntries([...bridgeIdsByName.values()].map((id) => [id, [18]])) });
  for (const [name, id] of bridgeIdsByName) if (Number(bridgeBaseOpacity.values?.[id]?.[18]) !== 0) errors.push(`${name}: base opacity must be zero`);
  const normalizedAnimations = {};
  const nameById = new Map([...idsByName].map(([name, id]) => [id, name]));
  for (const performance of PERFORMANCES) {
    const animation = animationsBySlug.get(performance.slug);
    const values = settings.values?.[animation.id] ?? {};
    if (Number(values[56]) !== FPS || Number(values[57]) !== performance.durationFrames || Number(values[59]) !== (performance.loop ? 1 : 0)) errors.push(`${performance.slug}: settings mismatch`);
    const expected = expectedTuples(performance, idsByName);
    const expectedBridges = expectedBridgeTuples(performance, bridgeIdsByName);
    const actual = keyframes.keyframes?.[animation.id] ?? [];
    const tracks = {};
    const bridgeOpacityTracks = {};
    for (const keyframe of actual) {
      const tuple = `${keyframe.objectId}/${Number(keyframe.propertyKey)}/${Number(keyframe.frame)}`;
      const bridgeContract = expectedBridges.get(tuple);
      if (bridgeContract) {
        if (Number(keyframe.propertyKey) !== 18 || Math.abs(Number(keyframe.value) - bridgeContract.value) > 1e-4 || keyframe.interpolationType !== "hold") errors.push(`${performance.slug}: bridge opacity mismatch ${tuple}`);
        ((bridgeOpacityTracks[bridgeContract.name] ??= [])).push({ keyframeId: keyframe.keyframeId, frame: Number(keyframe.frame), value: Number(keyframe.value), interpolation: keyframe.interpolationType });
        continue;
      }
      const contract = expected.get(tuple);
      if (!contract) { errors.push(`${performance.slug}: unexpected tuple ${tuple}`); continue; }
      if (Math.abs(Number(keyframe.value) - contract.value) > 1e-4) errors.push(`${performance.slug}: value mismatch ${tuple}`);
      const cubic = interpolators.values?.[keyframe.interpolatorId] ?? {};
      const curve = [63, 64, 65, 66].map((key) => Number(cubic[key]));
      if (!curve.every(Number.isFinite)) errors.push(`${performance.slug}: non-finite curve ${keyframe.keyframeId}`);
      const signature = curve.map((value) => value.toFixed(2)).join(",");
      curveSignatureCounts[signature] = (curveSignatureCounts[signature] ?? 0) + 1;
      if (!allowedSignatures.has(signature)) errors.push(`${performance.slug}: unapproved curve ${signature}`);
      if (curve.some((value, index) => Math.abs(value - contract.curve[index]) > 1e-6)) errors.push(`${performance.slug}: curve mismatch ${tuple}`);
      const nodeName = nameById.get(keyframe.objectId);
      const property = PROPERTY.get(Number(keyframe.propertyKey));
      let normalizedValue = Number(keyframe.value);
      if (property === "dx") normalizedValue -= PIVOTS[nodeName].x;
      if (property === "dy") normalizedValue -= PIVOTS[nodeName].y;
      if (property === "rotationDeg") normalizedValue = normalizedValue * 180 / Math.PI;
      (((tracks[nodeName] ??= {})[property] ??= [])).push({ keyframeId: keyframe.keyframeId, interpolatorId: keyframe.interpolatorId, frame: Number(keyframe.frame), value: Math.abs(normalizedValue) < 1e-10 ? 0 : normalizedValue, interpolation: keyframe.interpolationType ?? "cubic", curve });
    }
    if (actual.length !== expected.size + expectedBridges.size) errors.push(`${performance.slug}: expected ${expected.size + expectedBridges.size} keys, found ${actual.length}`);
    for (const properties of Object.values(tracks)) for (const keys of Object.values(properties)) keys.sort((a, b) => a.frame - b.frame);
    for (const keys of Object.values(bridgeOpacityTracks)) keys.sort((a, b) => a.frame - b.frame);
    normalizedAnimations[performance.slug] = { id: animation.id, label: performance.label, durationFrames: performance.durationFrames, loop: performance.loop, contactFrames: performance.contactFrames, tracks, bridgeOpacityTracks };
  }
  const machine = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: MACHINE_ID } } });
  const layers = machine.layers ?? [];
  const authoredStates = layers.flatMap((layer) => layer.states ?? []).filter((state) => state.type === "animation");
  const transitions = layers.flatMap((layer) => layer.transitions ?? []);
  if (layers.length !== 1 || authoredStates.length !== 5 || transitions.length !== 1) errors.push("machine inventory mismatch");
  if ((machine.inputs ?? []).length || (machine.listeners ?? []).length || transitions.some((transition) => (transition.conditions ?? []).length)) errors.push("machine is not mapping-only");
  const mappedIds = new Set(authoredStates.map((state) => state.animationId));
  for (const id of animationIds) if (!mappedIds.has(id)) errors.push(`machine missing ${id}`);
  const nodes = Object.entries(PIVOTS).map(([name, spec]) => ({ name, parent: spec.parent, kind: spec.kind ?? "pivot", transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: spec.pivot } }));
  for (const [part, spec] of Object.entries(SEMANTIC_PARTS)) nodes.push({ name: `asset_${part}`, parent: spec.rig, kind: "asset", source: "canonical-svg", semanticPart: part, sourceElementIndices: spec.indices, transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: { x: 0, y: 0 } } });
  for (const bridge of BRIDGES) nodes.push({ name: bridge.name, parent: `asset_${bridge.semantic}`, kind: "motion-gated-underlap", sourceElementIndex: bridge.sourceIndex, transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 0, pivot: { x: 0, y: 0 } } });
  const liveExport = { schema: "scorekeeper.rive-live-keyframes/v1", source: { path: "../production-v5-vector-master/canonical-dimensional-pixel.svg", sha256: SOURCE_SHA256 }, canvas: { width: 512, height: 416 }, fps: FPS, artboard: ARTBOARD_NAME, liveArtboardId: ARTBOARD_ID, stateMachineId: MACHINE_ID, specHash: motionSpecHash(), nodes, animations: normalizedAnimations };
  writeJson("live-keyframes-v3.json", liveExport);
  writeJson("live-hierarchy-v3.json", hierarchy);
  writeJson("live-state-machine-v3.json", machine);
  const report = { passed: errors.length === 0, errors, queriedAt: new Date().toISOString(), targetFileId: "2434585", artboardId: ARTBOARD_ID, artboardName: ARTBOARD_NAME, animationIds: Object.fromEntries([...animationsBySlug].map(([slug, item]) => [slug, item.id])), stateMachineId: MACHINE_ID, objectCount: hierarchy.objects?.length ?? 0, specHash: motionSpecHash(), keyframeCount: Object.values(keyframes.keyframes ?? {}).flat().length, interpolatorCount: interpolatorIds.length, curveSignatureCounts, liveExportSha256: sha(liveExport), hierarchySha256: sha(hierarchy), stateMachineSha256: sha(machine) };
  writeJson("independent-live-query.json", report);
  if (errors.length) throw new Error(errors.join("\n"));
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

main().catch((error) => { console.error(error.stack ?? String(error)); process.exitCode = 1; });
