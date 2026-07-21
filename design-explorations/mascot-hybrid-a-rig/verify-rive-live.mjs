#!/usr/bin/env node

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { BASE_BY_NAME, HAIR_PART_NAMES, NODES, PARTS, PIVOTS } from "./rig-spec.mjs";
import { PERFORMANCE_SPECS, terminalFrame } from "./performance-spec.mjs";
import { STATE_MACHINE_SPEC } from "./state-machine-spec.mjs";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const REPORT = join(ROOT, "reports", "rive-live-qa.json");
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const FINAL_NAME = "ScoreKeeper Cup Hybrid A - Articulated Rig v1";
const TRANSFORM_KEYS = [13, 14, 15, 16, 17, 18];
const ANIMATION_KEYS = [56, 57, 59];
let rpcId = 1;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function send(payload) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify(payload),
  });
  if (response.status === 202) return {};
  if (!response.ok) throw new Error(`HTTP ${response.status} ${response.statusText}`);
  const result = await response.json();
  if (result.error) throw new Error(result.error.message ?? JSON.stringify(result.error));
  return result.result;
}

const rpc = (method, params = {}) => send({ jsonrpc: "2.0", id: rpcId++, method, params });
const notify = (method, params = {}) => send({ jsonrpc: "2.0", method, params });

async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  const parsed = text ? JSON.parse(text) : result;
  if (parsed?.errors?.length || parsed?.success === false) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}

function oneByName(objects, name) {
  const matches = objects.filter((object) => object.name === name);
  assert(matches.length === 1, `Expected one ${name}, found ${matches.length}`);
  return matches[0];
}

function parentMap(objects) {
  const parents = new Map();
  for (const object of objects) {
    for (const child of object.children ?? []) parents.set(child, object.id);
  }
  return parents;
}

async function main() {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "codex-scorekeeper-rig-independent-qa", version: "1.0" },
  });
  await notify("notifications/initialized");

  const listed = await tool("list_artboards", {});
  const artboard = oneByName(listed.artboards ?? [], FINAL_NAME);
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId: artboard.id, fitToViewport: true } },
  });
  const selected = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  assert(selected.artboard?.id === artboard.id, "Published artboard focus lock failed");

  const hierarchy = await tool("get_artboard_hierarchy", { artboardId: artboard.id, depth: 8 });
  const objects = hierarchy.objects ?? [];
  const shapes = objects.filter((object) => object.types?.includes("Shape"));
  const shapeByName = new Map(NODES.map((node) => [node.name, oneByName(shapes, node.name)]));
  const parents = parentMap(objects);
  for (const node of NODES) {
    const expectedParent = node.parent === null ? artboard.id : shapeByName.get(node.parent).id;
    assert(parents.get(shapeByName.get(node.name).id) === expectedParent, `${node.name}: parent mismatch`);
  }
  const forbidden = objects.filter((object) => (object.types ?? []).some((type) =>
    ["Image", "ImageAsset", "ImageInstance", "NestedArtboard", "ArtboardInstance"].includes(type)));
  assert(forbidden.length === 0, `Forbidden raster/nested objects: ${forbidden.map((item) => item.name).join(", ")}`);

  const hairControl = shapeByName.get("rig_hair");
  const hairChildren = HAIR_PART_NAMES.map((name) => shapeByName.get(name));
  assert(hairChildren.every((child) => parents.get(child.id) === hairControl.id), "Hair vectors are not all owned by rig_hair");
  assert(parents.get(shapeByName.get("rig_body__hair_underlap").id) === shapeByName.get("rig_body").id, "Hair underlap must remain body-owned");

  const baseIds = [...PIVOTS.map((node) => shapeByName.get(node.name).id), shapeByName.get("rig_body__hair_underlap").id];
  const baseValues = await tool("query_property_values", {
    propertyKeys: Object.fromEntries(baseIds.map((id) => [id, TRANSFORM_KEYS])),
  });
  for (const name of [...PIVOTS.map((node) => node.name), "rig_body__hair_underlap"]) {
    const id = shapeByName.get(name).id;
    const actual = baseValues.values?.[id] ?? {};
    const expected = BASE_BY_NAME[name];
    assert(Math.abs(Number(actual[13]) - expected.x) < 1e-5, `${name}: base x mismatch`);
    assert(Math.abs(Number(actual[14]) - expected.y) < 1e-5, `${name}: base y mismatch`);
    assert(Math.abs(Number(actual[18]) - expected.opacity) < 1e-5, `${name}: base opacity mismatch`);
  }

  const animationList = await tool("animation_editor", {
    command: "listLinearAnimations",
    data: { listLinearAnimations: {} },
  });
  const animations = animationList.linearAnimations ?? [];
  assert(animations.length === 3, `Expected three linear animations, found ${animations.length}`);
  const animationBySlug = new Map(PERFORMANCE_SPECS.map((spec) => [spec.slug, oneByName(animations, spec.slug)]));
  const animationIds = [...animationBySlug.values()].map((animation) => animation.id);
  const animationValues = await tool("query_property_values", {
    propertyKeys: Object.fromEntries(animationIds.map((id) => [id, ANIMATION_KEYS])),
  });
  const queriedKeys = await tool("animation_editor", {
    command: "queryKeyFrames",
    data: { queryKeyFrames: { animationIds } },
  });
  const animationChecks = [];
  for (const spec of PERFORMANCE_SPECS) {
    const animation = animationBySlug.get(spec.slug);
    const values = animationValues.values?.[animation.id] ?? {};
    assert(Number(values[56]) === spec.fps, `${spec.slug}: fps mismatch`);
    assert(Number(values[57]) === terminalFrame(spec), `${spec.slug}: duration mismatch`);
    assert(Number(values[59]) === (spec.loop ? 1 : 0), `${spec.slug}: loop mismatch`);
    const actualKeys = queriedKeys.keyframes?.[animation.id] ?? [];
    const expectedCount = Object.values(spec.tracks).reduce((total, properties) =>
      total + Object.values(properties).reduce((count, keys) => count + keys.length, 0), 0);
    assert(actualKeys.length === expectedCount, `${spec.slug}: keyframe count mismatch`);
    animationChecks.push({
      slug: spec.slug,
      id: animation.id,
      fps: Number(values[56]),
      terminalFrame: Number(values[57]),
      loop: Number(values[59]) === 1,
      keyframeCount: actualKeys.length,
    });
  }

  const machineList = await tool("animation_editor", {
    command: "listStateMachines",
    data: { listStateMachines: {} },
  });
  const stateMachine = oneByName(machineList.stateMachines ?? [], STATE_MACHINE_SPEC.name);
  const machine = await tool("animation_editor", {
    command: "queryStateMachine",
    data: { queryStateMachine: { stateMachineId: stateMachine.id } },
  });
  assert((machine.inputs ?? []).length === 0, "Mapping-only state machine unexpectedly has inputs");
  const layer = oneByName((machine.layers ?? []).map((item) => ({ ...item, name: item.layerName ?? item.name })), STATE_MACHINE_SPEC.layerName);
  const states = (layer.states ?? []).map((state) => ({ ...state, name: state.stateName ?? state.name })).filter((state) => state.name);
  assert(states.length === 3, `Expected three mapped states, found ${states.length}`);
  for (const expected of STATE_MACHINE_SPEC.states) {
    const state = oneByName(states, expected.name);
    assert(state.animationId === animationBySlug.get(expected.animation).id, `${expected.name}: animation mapping mismatch`);
  }
  assert((layer.transitions ?? []).length === 1, "Expected exactly one Entry-to-Idle transition");

  const report = {
    schemaVersion: 1,
    status: "passed",
    auditedAt: new Date().toISOString(),
    artboard: { id: artboard.id, name: artboard.name, selected: true },
    inventory: { nodeCount: NODES.length, pivotCount: PIVOTS.length, partCount: PARTS.length },
    hairComponent: {
      control: { id: hairControl.id, name: hairControl.name },
      nativeVectorChildren: hairChildren.map((child) => ({ id: child.id, name: child.name })),
      nativeVectorChildCount: hairChildren.length,
      bodyOwnedSeamUnderlap: shapeByName.get("rig_body__hair_underlap").id,
      valid: hairChildren.length === 6,
    },
    animations: animationChecks,
    stateMachine: { id: stateMachine.id, name: stateMachine.name, inputCount: 0, mappedStateCount: 3 },
    checks: {
      hierarchyParentsCorrect: true,
      baseTransformsCorrect: true,
      forbiddenRasterOrNestedObjectCount: 0,
      animationSettingsAndKeyframeCountsCorrect: true,
      stateMappingsCorrect: true,
      publishedArtboardFocusLocked: true,
    },
  };
  writeFileSync(REPORT, `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? error.message ?? String(error));
  process.exitCode = 1;
});
