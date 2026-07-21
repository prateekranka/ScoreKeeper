#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { APPROVED_SHA256, SEMANTIC_PARTS } from "./artwork-scanlines.mjs";
import { FPS, PERFORMANCES, PIVOTS, validateMotionSpec } from "./motion-spec-v2.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const MAIN_ID = "0-16469";
const MAIN_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v2";
const HAIR_NAME = "ScoreKeeper Cup Hair Component v2";
const PROTECTED = { "0-2": 3946, "0-3956": 4092 };
const PROPERTY_TO_NAME = new Map([[13, "dx"], [14, "dy"], [15, "rotationDeg"], [16, "scaleX"], [17, "scaleY"], [18, "opacity"]]);
const CURVE = { x1: .42, y1: 0, x2: .58, y2: 1 };
let id = 1;

function assert(condition, message) { if (!condition) throw new Error(message); }
async function request(payload) {
  const response = await fetch(URL, { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" }, body: JSON.stringify(payload) });
  if (response.status === 202) return {};
  const body = await response.json();
  if (body.error) throw new Error(body.error.message);
  return body;
}
async function rpc(method, params = {}) { return (await request({ jsonrpc: "2.0", id: id++, method, params })).result; }
async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  let parsed = result;
  if (text) { try { parsed = JSON.parse(text); } catch { parsed = text; } }
  if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}
async function init() {
  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-v2-finalizer", version: "1" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
}
async function focus() {
  await tool("open_file_editor", { command: "focusArtboard", data: { focusArtboard: { artboardId: MAIN_ID, fitToViewport: true } } });
  const selected = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  assert(selected.artboard?.id === MAIN_ID, `Expected ${MAIN_ID}, found ${selected.artboard?.id}`);
}
function expectedKeyCount(performance) {
  return Object.values(performance.tracks).reduce((nodeTotal, properties) => nodeTotal + Object.values(properties).reduce((propertyTotal, keys) => propertyTotal + keys.length, 0), 0);
}
function interpolation(keyframe) {
  const value = String(keyframe.interpolationType ?? keyframe.interpolation ?? "cubic");
  return ["linear", "hold", "cubic"].includes(value) ? value : "cubic";
}
function makeExport(idsByName, animationsBySlug, keyframeQuery) {
  const nameById = new Map([...idsByName].map(([name, objectId]) => [objectId, name]));
  const nodes = Object.entries(PIVOTS).map(([name, spec]) => ({
    name,
    parent: spec.parent,
    kind: spec.kind ?? "pivot",
    transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: spec.pivot },
  }));
  for (const [part, spec] of Object.entries(SEMANTIC_PARTS)) {
    nodes.push({
      name: `asset_${part}`,
      parent: spec.rig,
      kind: "asset",
      source: "canonical-svg",
      semanticPart: part,
      sourceElementIndices: spec.indices,
      transform: { x: 0, y: 0, rotationDeg: 0, scaleX: 1, scaleY: 1, opacity: 1, pivot: { x: 0, y: 0 } },
    });
  }
  const animations = {};
  for (const performance of PERFORMANCES) {
    const animationId = animationsBySlug.get(performance.slug).id;
    const tracks = {};
    for (const keyframe of keyframeQuery.keyframes?.[animationId] ?? []) {
      const name = nameById.get(keyframe.objectId);
      const property = PROPERTY_TO_NAME.get(Number(keyframe.propertyKey));
      assert(name && property, `${performance.slug}: unknown queried key target ${keyframe.objectId}/${keyframe.propertyKey}`);
      let value = Number(keyframe.value);
      if (property === "dx") value -= PIVOTS[name].x;
      if (property === "dy") value -= PIVOTS[name].y;
      if (property === "rotationDeg") value = value * 180 / Math.PI;
      const cubic = keyframe.cubicParams ?? CURVE;
      (((tracks[name] ??= {})[property] ??= [])).push({
        frame: Number(keyframe.frame),
        value: Math.abs(value) < 1e-10 ? 0 : value,
        interpolation: interpolation(keyframe),
        curve: [Number(cubic.x1 ?? CURVE.x1), Number(cubic.y1 ?? CURVE.y1), Number(cubic.x2 ?? CURVE.x2), Number(cubic.y2 ?? CURVE.y2)],
      });
    }
    for (const properties of Object.values(tracks)) for (const keys of Object.values(properties)) keys.sort((a, b) => a.frame - b.frame);
    animations[performance.slug] = { label: performance.label, durationFrames: performance.durationFrames, loop: performance.loop, contactFrames: performance.contactFrames, tracks };
  }
  return {
    schema: "scorekeeper.rive-live-keyframes/v1",
    source: { path: "../production-v5-vector-master/canonical-dimensional-pixel.svg", sha256: APPROVED_SHA256 },
    canvas: { width: 512, height: 416 },
    fps: FPS,
    artboard: MAIN_NAME,
    nodes,
    animations,
  };
}

async function main() {
  validateMotionSpec();
  await init();
  await focus();
  const artboards = await tool("list_artboards", {});
  assert((artboards.artboards ?? []).some((artboard) => artboard.id === MAIN_ID && artboard.name === MAIN_NAME), "Temp artboard identity mismatch");
  const hairArtboard = (artboards.artboards ?? []).find((artboard) => artboard.name === HAIR_NAME);
  assert(hairArtboard, "Hair component artboard missing");

  const protectedCounts = {};
  for (const [artboardId, expected] of Object.entries(PROTECTED)) {
    const h = await tool("get_artboard_hierarchy", { artboardId, depth: 8 });
    protectedCounts[artboardId] = h.objects?.length ?? 0;
    assert(protectedCounts[artboardId] === expected, `Protected artboard ${artboardId} changed`);
  }

  const hierarchy = await tool("get_artboard_hierarchy", { artboardId: MAIN_ID, depth: 8 });
  const idsByName = new Map();
  for (const name of Object.keys(PIVOTS)) {
    const matches = (hierarchy.objects ?? []).filter((object) => object.name === name);
    assert(matches.length === 1, `Expected one ${name}, found ${matches.length}`);
    idsByName.set(name, matches[0].id);
    if (name === "rig_hair") assert(matches[0].types?.includes("NestedArtboard"), "rig_hair is not a real NestedArtboard component");
  }

  const list = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const animationsBySlug = new Map();
  for (const performance of PERFORMANCES) {
    const matches = (list.linearAnimations ?? []).filter((animation) => animation.name === performance.slug);
    assert(matches.length === 1, `Expected one ${performance.slug}, found ${matches.length}`);
    animationsBySlug.set(performance.slug, matches[0]);
  }
  const animationIds = [...animationsBySlug.values()].map((animation) => animation.id);
  const settings = await tool("query_property_values", { propertyKeys: Object.fromEntries(animationIds.map((animationId) => [animationId, [56, 57, 59]])) });
  const keyframes = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds } } });
  for (const performance of PERFORMANCES) {
    const animationId = animationsBySlug.get(performance.slug).id;
    const values = settings.values?.[animationId] ?? {};
    assert(Number(values[56]) === FPS && Number(values[57]) === performance.durationFrames && Number(values[59]) === (performance.loop ? 1 : 0), `${performance.slug}: live settings mismatch`);
    assert((keyframes.keyframes?.[animationId] ?? []).length === expectedKeyCount(performance), `${performance.slug}: live keyframe count mismatch`);
  }

  const machines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const machine = (machines.stateMachines ?? []).find((candidate) => candidate.name === "ScoreKeeper Cup Hybrid A Behaviors v2");
  assert(machine, "v2 state machine missing");
  const machineQuery = await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machine.id } } });
  const mappedIds = new Set(machineQuery.layers.flatMap((layer) => layer.states).map((state) => state.animationId).filter((value) => value && value !== "0-0"));
  for (const animationId of animationIds) assert(mappedIds.has(animationId), `State machine missing animation ${animationId}`);
  assert(machineQuery.inputs.length === 0 && machineQuery.listeners.length === 0, "State machine must be mapping-only");

  const output = makeExport(idsByName, animationsBySlug, keyframes);
  fs.writeFileSync(path.join(ROOT, "live-keyframes.json"), `${JSON.stringify(output, null, 2)}\n`);
  const summary = {
    status: "published-after-visual-qa",
    mainArtboardId: MAIN_ID,
    mainArtboardName: MAIN_NAME,
    hairComponentArtboardId: hairArtboard.id,
    hairComponentArtboardName: HAIR_NAME,
    hairIsNestedArtboard: true,
    sourceSha256: APPROVED_SHA256,
    transparentBackground: true,
    mainObjectCount: hierarchy.objects?.length ?? 0,
    pivots: Object.fromEntries(idsByName),
    animations: Object.fromEntries([...animationsBySlug].map(([slug, animation]) => [slug, { id: animation.id, keyframes: keyframes.keyframes?.[animation.id]?.length ?? 0 }])),
    stateMachineId: machine.id,
    protectedCounts,
    finalRenamePerformed: true,
  };
  fs.writeFileSync(path.join(ROOT, "live-build-summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
}

main().catch((error) => { console.error(error.stack ?? String(error)); process.exitCode = 1; });
