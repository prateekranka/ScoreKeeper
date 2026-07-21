#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_PATH = path.resolve(ROOT, "../production-v5-vector-master/canonical-dimensional-pixel.svg");
const SOURCE_SHA256 = "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75";
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const SOURCE_ARTBOARD_ID = "0-32354";
const SOURCE_ARTBOARD_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v3";
const TEMP_NAME = "__PROOF__ ScoreKeeper Mascot 20260716T085439Z";
const KEEP = new Map([
  ["idle_breathe_blink", "idle"],
  ["celebrate_shimmy", "celebrate"],
]);
const EXPECTED_ANIMATIONS = new Set([
  "idle_breathe_blink",
  "celebrate_shimmy",
  "hair_bounce",
  "victory_pop",
  "curious_tilt",
]);
const ANIMATION_PROPERTY = Object.freeze({ fps: 56, durationFrames: 57, loop: 59 });
let rpcId = 1;
let focusFailures = 0;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha(value) {
  return crypto.createHash("sha256").update(Buffer.isBuffer(value) ? value : JSON.stringify(value)).digest("hex");
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
  if (parsed?.success === false || parsed?.errors?.length) {
    throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function initialize() {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "scorekeeper-codex-rive-proof-phase1", version: "1" },
  });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
}

async function focus(artboardId) {
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId, fitToViewport: true } },
  });
  await new Promise((resolve) => setTimeout(resolve, 180));
  const selected = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  if (selected.artboard?.id !== artboardId) {
    focusFailures += 1;
    if (focusFailures >= 2) {
      throw new Error(`cumulative focus-lock failure: expected ${artboardId}, found ${selected.artboard?.id ?? "none"}`);
    }
    return focus(artboardId);
  }
  return selected.artboard;
}

async function protectedSnapshot(artboards) {
  const result = [];
  for (const artboard of [...artboards].sort((a, b) => a.id.localeCompare(b.id))) {
    await focus(artboard.id);
    const hierarchy = await tool("get_artboard_hierarchy", { artboardId: artboard.id, depth: 8 });
    const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
    const animationIds = (animations.linearAnimations ?? []).map((item) => item.id);
    const settings = animationIds.length
      ? await tool("query_property_values", { propertyKeys: Object.fromEntries(animationIds.map((id) => [id, [56, 57, 59]])) })
      : { values: {} };
    const keyframes = animationIds.length
      ? await tool("animation_editor", { command: "queryKeyFrames", data: { queryKeyFrames: { animationIds } } })
      : { keyframes: {} };
    const machines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
    const machineDetails = [];
    for (const machine of machines.stateMachines ?? []) {
      machineDetails.push(await tool("animation_editor", {
        command: "queryStateMachine",
        data: { queryStateMachine: { stateMachineId: machine.id } },
      }));
    }
    result.push({
      artboard: { id: artboard.id, name: artboard.name },
      hierarchyHash: sha(hierarchy),
      objectCount: hierarchy.objects?.length ?? 0,
      animations,
      settings,
      keyframesHash: sha(keyframes),
      machines,
      machineDetails,
    });
  }
  return result;
}

async function main() {
  assert(sha(fs.readFileSync(SOURCE_PATH)) === SOURCE_SHA256, "approved SVG hash mismatch");
  await initialize();

  const first = await tool("list_artboards");
  const selected1 = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  const second = await tool("list_artboards");
  const selected2 = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  assert(JSON.stringify(first.artboards) === JSON.stringify(second.artboards), "two-pass artboard inventory mismatch");
  assert(selected1.artboard?.id === SOURCE_ARTBOARD_ID && selected2.artboard?.id === SOURCE_ARTBOARD_ID, "source artboard selection mismatch");
  const originalArtboards = first.artboards ?? [];
  assert(originalArtboards.length === 7, `expected 7 protected artboards, found ${originalArtboards.length}`);
  assert(originalArtboards.some((item) => item.id === SOURCE_ARTBOARD_ID && item.name === SOURCE_ARTBOARD_NAME), "exact v3 source artboard missing");
  assert(!originalArtboards.some((item) => item.name === TEMP_NAME), "temporary artboard name collision");

  const before = await protectedSnapshot(originalArtboards);
  const protectedHash = sha(before);
  await focus(SOURCE_ARTBOARD_ID);
  await tool("duplicate_objects", { objectIds: [SOURCE_ARTBOARD_ID] });
  const afterDuplicate = await tool("list_artboards");
  const beforeIds = new Set(originalArtboards.map((item) => item.id));
  const created = (afterDuplicate.artboards ?? []).filter((item) => !beforeIds.has(item.id));
  assert((afterDuplicate.artboards ?? []).length === 8 && created.length === 1, "artboard duplication was ambiguous");
  const tempId = created[0].id;

  await focus(tempId);
  await tool("rename_objects", { renames: [{ id: tempId, name: TEMP_NAME }] });
  await focus(tempId);
  const renamedList = await tool("list_artboards");
  assert((renamedList.artboards ?? []).filter((item) => item.id === tempId && item.name === TEMP_NAME).length === 1, "temporary artboard rename failed");

  const sourceHierarchy = await tool("get_artboard_hierarchy", { artboardId: SOURCE_ARTBOARD_ID, depth: 8 });
  const tempHierarchy = await tool("get_artboard_hierarchy", { artboardId: tempId, depth: 8 });
  assert((sourceHierarchy.objects?.length ?? 0) === (tempHierarchy.objects?.length ?? 0), "duplicate hierarchy count mismatch");
  const sourceIds = new Set((sourceHierarchy.objects ?? []).map((item) => item.id));
  assert(!(tempHierarchy.objects ?? []).some((item) => sourceIds.has(item.id)), "duplicate contains protected descendant IDs");

  await focus(tempId);
  const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const animationNames = new Set((animations.linearAnimations ?? []).map((item) => item.name));
  assert(animationNames.size === EXPECTED_ANIMATIONS.size && [...EXPECTED_ANIMATIONS].every((name) => animationNames.has(name)), "duplicated timeline inventory mismatch");
  const machines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  assert((machines.stateMachines ?? []).length === 1, "expected one duplicated state machine");

  const keepByOriginal = new Map((animations.linearAnimations ?? []).filter((item) => KEEP.has(item.name)).map((item) => [item.name, item]));
  assert(keepByOriginal.size === 2, "required idle/celebrate timelines missing");
  const deleteIds = [
    ...(animations.linearAnimations ?? []).filter((item) => !KEEP.has(item.name)).map((item) => item.id),
    ...(machines.stateMachines ?? []).map((item) => item.id),
  ];
  await focus(tempId);
  await tool("delete_objects", { objectIds: deleteIds });
  await focus(tempId);
  await tool("animation_editor", {
    command: "renameAnimations",
    data: {
      renameAnimations: {
        animations: [...keepByOriginal].map(([original, item]) => ({ animationId: item.id, name: KEEP.get(original) })),
      },
    },
  });
  const idleId = keepByOriginal.get("idle_breathe_blink").id;
  const celebrateId = keepByOriginal.get("celebrate_shimmy").id;
  await focus(tempId);
  await tool("set_property_values", {
    propertyValues: {
      [idleId]: { [ANIMATION_PROPERTY.fps]: 60, [ANIMATION_PROPERTY.durationFrames]: 72, [ANIMATION_PROPERTY.loop]: 1 },
      [celebrateId]: { [ANIMATION_PROPERTY.fps]: 60, [ANIMATION_PROPERTY.durationFrames]: 96, [ANIMATION_PROPERTY.loop]: 0 },
    },
  });

  await focus(tempId);
  const finalAnimations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const finalMachines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const finalSettings = await tool("query_property_values", { propertyKeys: { [idleId]: [56, 57, 59], [celebrateId]: [56, 57, 59] } });
  assert((finalAnimations.linearAnimations ?? []).length === 2, "phase 1 did not leave exactly two timelines");
  assert(new Set((finalAnimations.linearAnimations ?? []).map((item) => item.name)).size === 2, "phase 1 timeline names are not unique");
  assert((finalAnimations.linearAnimations ?? []).some((item) => item.name === "idle"), "idle timeline rename missing");
  assert((finalAnimations.linearAnimations ?? []).some((item) => item.name === "celebrate"), "celebrate timeline rename missing");
  assert((finalMachines.stateMachines ?? []).length === 0, "phase 1 left a stale state machine");
  assert(Number(finalSettings.values?.[idleId]?.[59]) === 1, "idle is not looping");
  assert(Number(finalSettings.values?.[celebrateId]?.[59]) === 0, "celebrate is still looping");

  const currentList = await tool("list_artboards");
  const protectedCurrent = (currentList.artboards ?? []).filter((item) => beforeIds.has(item.id));
  const after = await protectedSnapshot(protectedCurrent);
  assert(sha(after) === protectedHash, "protected artboards changed during phase 1");
  await focus(tempId);

  const report = {
    status: "phase1-complete",
    targetFileId: "2434585",
    approvedSource: { path: SOURCE_PATH, sha256: SOURCE_SHA256 },
    sourceArtboard: { id: SOURCE_ARTBOARD_ID, name: SOURCE_ARTBOARD_NAME },
    tempArtboard: { id: tempId, name: TEMP_NAME },
    protectedHash,
    protectedObjectCounts: before.map((item) => ({ ...item.artboard, objectCount: item.objectCount })),
    duplicateObjectCount: tempHierarchy.objects?.length ?? 0,
    animations: {
      idle: { id: idleId, fps: 60, durationFrames: 72, loop: true },
      celebrate: { id: celebrateId, fps: 60, durationFrames: 96, loop: false },
    },
    stateMachineCount: 0,
    deletedTempOnlyObjectIds: deleteIds,
    focusFailures,
  };
  fs.writeFileSync(path.join(ROOT, "phase1-report.json"), `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? String(error));
  process.exitCode = 1;
});
