#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { BRIDGES, BRIDGE_PREFIX, CONTROL_PIVOTS, SOURCE_LAYER_BY_INDEX } from "./underlap-spec-v3.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const V7 = path.dirname(HERE);
const URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const ARTBOARD_ID = "0-32354";
const ARTBOARD_NAME = "__V3_TEMP__ ScoreKeeper Cup Hybrid A 20260715T1415Z-root-recovery";
const RIG_NAMES = Object.freeze({ cup: "rig_cup", handle_l: "rig_handle_l", handle_r: "rig_handle_r", stem: "rig_stem", base: "rig_base" });
const MOTION_ANIMATIONS = Object.freeze([
  { id: "0-45148", name: "victory_pop", terminal: 72 },
  { id: "0-45726", name: "curious_tilt", terminal: 84 },
  { id: "0-45405", name: "celebrate_shimmy", terminal: 96 },
]);
let rpcId = 1;

function assert(condition, message) { if (!condition) throw new Error(message); }
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
const shapePayload = (item, parentId) => {
  const [pivotX, pivotY] = CONTROL_PIVOTS[item.semantic];
  const rect = item;
  const left = rect.x - pivotX;
  const top = rect.y - pivotY;
  const right = left + rect.width;
  const bottom = top + rect.height;
  return {
    parentId,
    name: item.name,
    x: 0,
    y: 0,
    paints: [{ paintType: "fill", color: `#FF${item.color.slice(1)}` }],
    paths: [{ name: `${item.name}_path`, commands: [
      { commandType: "moveTo", x: left, y: top },
      { commandType: "lineTo", x: right, y: top },
      { commandType: "lineTo", x: right, y: bottom },
      { commandType: "lineTo", x: left, y: bottom },
      { commandType: "close" },
    ] }],
  };
};

async function main() {
  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-v3-underlaps", version: "1" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
  const artboardsBefore = await tool("list_artboards", {});
  assert((artboardsBefore.artboards ?? []).length === 7, "expected exactly seven artboards");
  assert((artboardsBefore.artboards ?? []).some((item) => item.id === ARTBOARD_ID && item.name === ARTBOARD_NAME), "candidate identity mismatch");
  assert((artboardsBefore.artboards ?? []).some((item) => item.id === "0-16469" && item.name === "ScoreKeeper Cup Hybrid A - Production Rig v2"), "protected v2 identity mismatch");
  assert((artboardsBefore.artboards ?? []).some((item) => item.id === "0-17790" && item.name === "ScoreKeeper Cup Hair Component v2"), "protected hair identity mismatch");
  await focus();

  const beforeHierarchy = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
  const beforeObjects = beforeHierarchy.objects ?? [];
  const existing = beforeObjects.filter((object) => object.name?.startsWith(BRIDGE_PREFIX));
  const expectedNames = new Set(BRIDGES.map((item) => item.name));
  assert(existing.every((object) => expectedNames.has(object.name)), "unexpected owned underlap collision");
  if (existing.length) {
    assert(existing.length === BRIDGES.length && new Set(existing.map((object) => object.name)).size === BRIDGES.length, "partial bridge pass detected; stop for root recovery");
    process.stdout.write(`${JSON.stringify({ status: "already_complete", artboardId: ARTBOARD_ID, underlaps: existing.length }, null, 2)}\n`);
    return;
  }

  const byId = new Map(beforeObjects.map((object) => [object.id, object]));
  const rigBySemantic = new Map();
  for (const [semantic, rigName] of Object.entries(RIG_NAMES)) {
    const matches = beforeObjects.filter((object) => object.name === rigName);
    assert(matches.length === 1, `${rigName}: expected one rig control`);
    rigBySemantic.set(semantic, matches[0]);
  }
  const parentByLayer = new Map();
  for (const item of BRIDGES) {
    const layer = SOURCE_LAYER_BY_INDEX[item.sourceIndex];
    assert(layer, `missing live layer mapping for source ${item.sourceIndex}`);
    const key = `${item.semantic}/${layer}`;
    if (parentByLayer.has(key)) continue;
    const rig = rigBySemantic.get(item.semantic);
    const candidates = (rig.children ?? []).map((id) => byId.get(id)).filter((object) => object?.name?.includes(`__${layer}__y`));
    assert(candidates.length > 0, `${key}: no scanline parents`);
    parentByLayer.set(key, candidates.at(-1));
  }
  const parentIds = [...new Set([...parentByLayer.values()].map((object) => object.id))];
  const transforms = await tool("query_property_values", { propertyKeys: Object.fromEntries(parentIds.map((id) => [id, [13, 14, 15, 16, 17, 18]])) });
  for (const id of parentIds) {
    const value = transforms.values?.[id] ?? {};
    assert(Number(value[13]) === 0 && Number(value[14]) === 0 && Number(value[15]) === 0 && Number(value[16]) === 1 && Number(value[17]) === 1 && Number(value[18]) === 1, `scanline parent ${id} is not neutral`);
  }

  const payloads = BRIDGES.map((item) => {
    const layer = SOURCE_LAYER_BY_INDEX[item.sourceIndex];
    return shapePayload(item, parentByLayer.get(`${item.semantic}/${layer}`).id);
  });
  await tool("path_editor", { command: "createShapes", data: { createShapes: { shapes: payloads } } });
  const createdHierarchy = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
  const created = (createdHierarchy.objects ?? []).filter((object) => expectedNames.has(object.name));
  assert(created.length === BRIDGES.length && new Set(created.map((object) => object.name)).size === BRIDGES.length, `expected ${BRIDGES.length} created bridges, found ${created.length}`);
  await tool("reorder_objects", { operations: created.map((object) => ({ objectId: object.id, order: "sendToBack" })) });
  await tool("set_property_values", { propertyValues: Object.fromEntries(created.map((object) => [object.id, { 18: 0 }])) });
  const staticOpacity = await tool("query_property_values", { propertyKeys: Object.fromEntries(created.map((object) => [object.id, [18]])) });
  for (const object of created) assert(Number(staticOpacity.values?.[object.id]?.[18]) === 0, `${object.name}: base opacity is not zero`);
  const listedAnimations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  for (const animation of MOTION_ANIMATIONS) {
    const live = (listedAnimations.linearAnimations ?? []).find((item) => item.id === animation.id);
    assert(live?.name === animation.name, `${animation.id}: animation identity mismatch`);
    const add = created.flatMap((object) => [
      { objectId: object.id, propertyKey: 18, frame: 0, value: 0, interpolationType: "hold" },
      { objectId: object.id, propertyKey: 18, frame: 1, value: 1, interpolationType: "hold" },
      { objectId: object.id, propertyKey: 18, frame: animation.terminal - 1, value: 1, interpolationType: "hold" },
      { objectId: object.id, propertyKey: 18, frame: animation.terminal, value: 0, interpolationType: "hold" },
    ]);
    await tool("animation_editor", { command: "modifyKeyFrames", data: { modifyKeyFrames: { animationId: animation.id, add } } });
  }
  const bridgeKeys = await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds: MOTION_ANIMATIONS.map((item) => item.id) } } });
  const expectedBridgeKeyCount = BRIDGES.length * 4;
  for (const animation of MOTION_ANIMATIONS) {
    const keys = (bridgeKeys.keyframes?.[animation.id] ?? []).filter((key) => expectedNames.has(created.find((object) => object.id === key.objectId)?.name));
    assert(keys.length === expectedBridgeKeyCount, `${animation.name}: expected ${expectedBridgeKeyCount} bridge opacity keys, found ${keys.length}`);
  }

  const finalHierarchy = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
  const finalById = new Map((finalHierarchy.objects ?? []).map((object) => [object.id, object]));
  const rows = [];
  for (const item of BRIDGES) {
    const object = (finalHierarchy.objects ?? []).find((candidate) => candidate.name === item.name);
    assert(object, `missing ${item.name} after reorder`);
    const layer = SOURCE_LAYER_BY_INDEX[item.sourceIndex];
    const parent = parentByLayer.get(`${item.semantic}/${layer}`);
    assert(finalById.get(parent.id)?.children?.includes(object.id), `${object.name}: parent mismatch`);
    rows.push({ id: object.id, name: object.name, parentId: parent.id, parentName: parent.name, semantic: item.semantic, sourceIndex: item.sourceIndex, layer, rect: { x: item.x, y: item.y, width: item.width, height: item.height }, color: item.color, baseOpacity: 0 });
  }
  const artboardsAfter = await tool("list_artboards", {});
  assert(JSON.stringify((artboardsAfter.artboards ?? []).map(({ id, name }) => ({ id, name }))) === JSON.stringify((artboardsBefore.artboards ?? []).map(({ id, name }) => ({ id, name }))), "artboard identities changed during underlap pass");
  const result = { status: "live_motion_gated_bridges_added", targetFileId: "2434585", artboardId: ARTBOARD_ID, artboardName: ARTBOARD_NAME, underlapCount: rows.length, bridgeCount: rows.length, motionGated: true, opacityKeyframeCount: BRIDGES.length * 4 * MOTION_ANIMATIONS.length, objectCountBefore: beforeObjects.length, objectCountAfter: (finalHierarchy.objects ?? []).length, objects: rows, protectedArtboardsUnchanged: true, publishPerformed: false };
  fs.writeFileSync(path.join(HERE, "live-underlaps-v3.json"), `${JSON.stringify(result, null, 2)}\n`);
  fs.appendFileSync(path.join(V7, "evidence/opencode/opencode-status.md"), `\n- ${new Date().toISOString()} — RIVE-VIS-004 underlap pass; ${rows.length} owned fill-only underlaps added under matching scanline layers on artboard ${ARTBOARD_ID}; protected artboard identities unchanged; publish false.\n`);
  process.stdout.write(`${JSON.stringify({ status: result.status, underlapCount: result.underlapCount, objectCountBefore: result.objectCountBefore, objectCountAfter: result.objectCountAfter }, null, 2)}\n`);
}

main().catch((error) => { console.error(error instanceof Error ? error.message : String(error)); process.exit(2); });
