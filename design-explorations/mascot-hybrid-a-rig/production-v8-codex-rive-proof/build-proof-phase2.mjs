#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const TEMP_ID = "0-49117";
const TEMP_NAME = "__PROOF__ ScoreKeeper Mascot 20260716T085439Z";
const MACHINE_NAME = "ScoreKeeperMascot";
const VIEW_MODEL_ID = "0-62939";
const VIEW_MODEL_PROPERTY_ID = "0-62941";
const VIEW_MODEL_INSTANCE_ID = "0-62943";
const PROTECTED_IDS = new Set(["0-12189", "0-16469", "0-17790", "0-2", "0-32354", "0-3956", "0-8243"]);
const ARTBOARD_PROPERTY = Object.freeze({ defaultStateMachineId: 236, exportName: 544, viewModelId: 583, viewModelInstanceId: 584, includeInExport: 802 });
const TRANSITION_PROPERTY = Object.freeze({ flags: 152, duration: 158, exitTime: 160 });
let rpcId = 1;
let focusFailures = 0;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
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
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "scorekeeper-codex-rive-proof-phase2", version: "1" },
  });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
}

async function focus(artboardId) {
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId, fitToViewport: true } },
  });
  await new Promise((resolve) => setTimeout(resolve, 180));
  const selected = await tool("open_file_editor", { command: "getSelectedArtboard", data: { getSelectedArtboard: {} } });
  if (selected.artboard?.id !== artboardId) {
    focusFailures += 1;
    if (focusFailures >= 2) throw new Error(`cumulative focus-lock failure: expected ${artboardId}, found ${selected.artboard?.id ?? "none"}`);
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
      machineDetails.push(await tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machine.id } } }));
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

function transitionFor(machine, fromId, toId) {
  return (machine.layers ?? []).flatMap((layer) => layer.transitions ?? []).find((transition) => transition.fromStateId === fromId && transition.toStateId === toId);
}

async function queryMachine(machineId) {
  return tool("animation_editor", { command: "queryStateMachine", data: { queryStateMachine: { stateMachineId: machineId } } });
}

async function main() {
  await initialize();
  const phase1 = JSON.parse(fs.readFileSync(path.join(ROOT, "phase1-report.json"), "utf8"));
  assert(phase1.tempArtboard.id === TEMP_ID && phase1.tempArtboard.name === TEMP_NAME, "phase 1 checkpoint mismatch");

  const artboards = (await tool("list_artboards")).artboards ?? [];
  assert(artboards.length === 8, `expected 8 artboards after phase 1, found ${artboards.length}`);
  assert(artboards.some((item) => item.id === TEMP_ID && item.name === TEMP_NAME), "temporary artboard identity mismatch");
  const protectedArtboards = artboards.filter((item) => PROTECTED_IDS.has(item.id));
  assert(protectedArtboards.length === 7, "protected artboard inventory mismatch");
  const before = await protectedSnapshot(protectedArtboards);
  assert(sha(before) === phase1.protectedHash, "protected artboards changed before phase 2");

  await focus(TEMP_ID);
  const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  const idle = (animations.linearAnimations ?? []).find((item) => item.name === "idle");
  const celebrate = (animations.linearAnimations ?? []).find((item) => item.name === "celebrate");
  assert((animations.linearAnimations ?? []).length === 2 && idle && celebrate, "phase 2 expected only idle and celebrate timelines");
  const existingMachines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const staleMachines = (existingMachines.stateMachines ?? []).filter((item) => item.name === MACHINE_NAME);
  assert((existingMachines.stateMachines ?? []).length === staleMachines.length, "phase 2 found an unrelated temp state machine");
  if (staleMachines.length) {
    await focus(TEMP_ID);
    await tool("delete_objects", { objectIds: staleMachines.map((item) => item.id) });
  }
  const instances = await tool("viewmodel_editor", { command: "listViewModelInstances", data: { listViewModelInstances: { viewModelId: VIEW_MODEL_ID } } });
  const boundInstance = (instances.instances ?? []).find((item) => item.id === VIEW_MODEL_INSTANCE_ID);
  assert(boundInstance, "bound temp view model instance missing");
  assert((boundInstance.viewModelProperties ?? []).filter((item) => item.name === "celebrate" && item.propertyType === "trigger").length === 1, "single celebrate trigger property missing");

  await focus(TEMP_ID);
  await tool("animation_editor", {
    command: "createStateMachine",
    data: {
      createStateMachine: {
        name: MACHINE_NAME,
        layers: [{
          name: "Mascot",
          states: [
            {
              name: "Idle",
              x: 160,
              y: 140,
              linearAnimationName: "idle",
              transitions: [{ from: "Idle", to: "Celebrate" }],
            },
            {
              name: "Celebrate",
              x: 440,
              y: 140,
              linearAnimationName: "celebrate",
              transitions: [{ from: "Celebrate", to: "Idle" }],
            },
          ],
          otherTransitions: [{ from: "{Entry State}", to: "Idle" }],
        }],
      },
    },
  });
  await focus(TEMP_ID);
  const machineList = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  const machineMatches = (machineList.stateMachines ?? []).filter((item) => item.name === MACHINE_NAME);
  assert(machineMatches.length === 1, "expected one ScoreKeeperMascot state machine");
  const machineId = machineMatches[0].id;
  let machine = await queryMachine(machineId);
  const emptyLayerIds = (machine.layers ?? [])
    .filter((layer) => !(layer.states ?? []).some((state) => state.type === "animation"))
    .map((layer) => layer.layerId ?? layer.id)
    .filter(Boolean);
  if (emptyLayerIds.length) {
    await focus(TEMP_ID);
    await tool("delete_objects", { objectIds: emptyLayerIds });
    machine = await queryMachine(machineId);
  }
  const mascotLayer = (machine.layers ?? []).find((layer) => layer.layerName === "Mascot");
  assert(mascotLayer, "Mascot state-machine layer missing");
  const idleState = (mascotLayer.states ?? []).find((state) => state.type === "animation" && state.stateName === "Idle");
  const celebrateState = (mascotLayer.states ?? []).find((state) => state.type === "animation" && state.stateName === "Celebrate");
  assert(idleState && celebrateState, "Idle/Celebrate states missing");

  await focus(TEMP_ID);
  await tool("animation_editor", {
    command: "updateStates",
    data: { updateStates: { states: [{ id: idleState.id, animationId: idle.id }, { id: celebrateState.id, animationId: celebrate.id }] } },
  });
  machine = await queryMachine(machineId);
  const idleToCelebrate = transitionFor(machine, idleState.id, celebrateState.id);
  const celebrateToIdle = transitionFor(machine, celebrateState.id, idleState.id);
  assert(idleToCelebrate && celebrateToIdle, "bidirectional state transitions missing");

  await focus(TEMP_ID);
  await tool("animation_editor", {
    command: "createConditions",
    data: {
      createConditions: {
        transitions: [{ id: idleToCelebrate.id, conditions: [{ leftComparator: { viewModelPropertyId: VIEW_MODEL_PROPERTY_ID } }] }],
      },
    },
  });

  const bitEffects = {};
  for (const bit of [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]) {
    await focus(TEMP_ID);
    await tool("set_property_values", { propertyValues: { [celebrateToIdle.id]: { [TRANSITION_PROPERTY.flags]: bit } } });
    const candidate = transitionFor(await queryMachine(machineId), celebrateState.id, idleState.id);
    bitEffects[bit] = {
      isDisabled: candidate.isDisabled,
      pauseOnExit: candidate.pauseOnExit,
      enableExitTime: candidate.enableExitTime,
      enableEarlyExit: candidate.enableEarlyExit,
      durationIsPercentage: candidate.durationIsPercentage,
      exitTimeIsPercentage: candidate.exitTimeIsPercentage,
    };
  }
  const bitsFor = (field) => Object.entries(bitEffects).filter(([, effect]) => effect[field] === true).map(([bit]) => Number(bit));
  const enableExitBits = bitsFor("enableExitTime");
  const percentageBits = bitsFor("exitTimeIsPercentage");
  assert(enableExitBits.length === 1, `could not isolate enableExitTime bit: ${JSON.stringify(bitEffects)}`);
  assert(percentageBits.length === 1, `could not isolate exitTimeIsPercentage bit: ${JSON.stringify(bitEffects)}`);
  const returnFlags = enableExitBits[0] | percentageBits[0];
  await focus(TEMP_ID);
  await tool("set_property_values", {
    propertyValues: {
      [idleToCelebrate.id]: { [TRANSITION_PROPERTY.flags]: 0, [TRANSITION_PROPERTY.duration]: 0 },
      [celebrateToIdle.id]: { [TRANSITION_PROPERTY.flags]: returnFlags, [TRANSITION_PROPERTY.duration]: 0, [TRANSITION_PROPERTY.exitTime]: 1 },
      [TEMP_ID]: {
        [ARTBOARD_PROPERTY.defaultStateMachineId]: machineId,
        [ARTBOARD_PROPERTY.exportName]: "ScoreKeeperMascot",
        [ARTBOARD_PROPERTY.viewModelId]: VIEW_MODEL_ID,
        [ARTBOARD_PROPERTY.viewModelInstanceId]: VIEW_MODEL_INSTANCE_ID,
        [ARTBOARD_PROPERTY.includeInExport]: true,
      },
    },
  });

  await focus(TEMP_ID);
  machine = await queryMachine(machineId);
  const finalIdleToCelebrate = transitionFor(machine, idleState.id, celebrateState.id);
  const finalCelebrateToIdle = transitionFor(machine, celebrateState.id, idleState.id);
  const entryTransitions = (machine.layers ?? []).flatMap((layer) => layer.transitions ?? []).filter((transition) => transition.fromStateId === mascotLayer.entryStateId);
  assert((machine.layers ?? []).length === 1, "state machine has more than one layer");
  assert((mascotLayer.states ?? []).filter((state) => state.type === "animation").length === 2, "state machine does not have exactly two animation states");
  assert(entryTransitions.length === 1 && entryTransitions[0].toStateId === idleState.id, "default entry does not target Idle");
  assert((finalIdleToCelebrate.conditions ?? []).length === 1, "Idle to Celebrate does not have exactly one condition");
  assert(finalCelebrateToIdle.enableExitTime === true && finalCelebrateToIdle.exitTimeIsPercentage === true && Number(finalCelebrateToIdle.exitTime) === 1, "Celebrate does not return after 100% exit time");
  assert((finalCelebrateToIdle.conditions ?? []).length === 0, "Celebrate return transition should be automatic");
  const artboardValues = await tool("query_property_values", { propertyKeys: { [TEMP_ID]: [236, 544, 583, 584, 802, 849] } });
  const av = artboardValues.values?.[TEMP_ID] ?? {};
  assert(av[236] === machineId, "default state machine was not assigned");
  assert(av[544] === "ScoreKeeperMascot", "runtime export name was not assigned");
  assert(av[583] === VIEW_MODEL_ID && av[584] === VIEW_MODEL_INSTANCE_ID, "view model binding IDs changed");
  assert(av[802] === true, "temporary proof artboard is excluded from export");

  const after = await protectedSnapshot(protectedArtboards);
  assert(sha(after) === phase1.protectedHash, "protected artboards changed during phase 2");
  await focus(TEMP_ID);

  const report = {
    status: "phase2-complete",
    targetFileId: "2434585",
    tempArtboard: { id: TEMP_ID, name: TEMP_NAME, exportName: "ScoreKeeperMascot", includeInExport: true },
    animations: {
      idle: { id: idle.id, fps: 60, durationFrames: 72, loop: true },
      celebrate: { id: celebrate.id, fps: 60, durationFrames: 96, loop: false },
    },
    stateMachine: { id: machineId, name: MACHINE_NAME, layer: "Mascot", defaultState: "Idle" },
    trigger: {
      name: "celebrate",
      type: "trigger",
      viewModelId: VIEW_MODEL_ID,
      viewModelPropertyId: VIEW_MODEL_PROPERTY_ID,
      viewModelInstanceId: VIEW_MODEL_INSTANCE_ID,
    },
    transitions: {
      idleToCelebrate: finalIdleToCelebrate,
      celebrateToIdle: finalCelebrateToIdle,
      returnSemantics: "automatic at 100% of one-shot celebrate timeline",
    },
    transitionFlagProof: { bitEffects, enableExitBit: enableExitBits[0], exitTimePercentageBit: percentageBits[0], finalReturnFlags: returnFlags },
    protectedHash: phase1.protectedHash,
    focusFailures,
    machineQuery: machine,
    artboardValues,
  };
  fs.writeFileSync(path.join(ROOT, "phase2-report.json"), `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? String(error));
  process.exitCode = 1;
});
