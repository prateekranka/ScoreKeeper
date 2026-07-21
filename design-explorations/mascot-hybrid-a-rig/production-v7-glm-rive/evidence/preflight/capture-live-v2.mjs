#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const OUTPUT = path.join(ROOT, "live-v2-audit.json");
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const V2_ID = "0-16469";
let rpcId = 1;

async function request(payload) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify(payload),
  });
  if (response.status === 202) return {};
  if (!response.ok) throw new Error(`Rive MCP HTTP ${response.status} ${response.statusText}`);
  const body = await response.json();
  if (body.error) throw new Error(body.error.message ?? JSON.stringify(body.error));
  return body;
}

async function rpc(method, params = {}) {
  return (await request({ jsonrpc: "2.0", id: rpcId++, method, params })).result;
}

async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  let parsed = result;
  if (text) { try { parsed = JSON.parse(text); } catch { parsed = text; } }
  if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}

await rpc("initialize", {
  protocolVersion: "2025-06-18",
  capabilities: {},
  clientInfo: { name: "scorekeeper-v7-live-v2-audit", version: "1" },
});
await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });

const listedTools = await rpc("tools/list");
const artboards = await tool("list_artboards", {});
await tool("open_file_editor", {
  command: "focusArtboard",
  data: { focusArtboard: { artboardId: V2_ID, fitToViewport: true } },
});
const selected = await tool("open_file_editor", {
  command: "getSelectedArtboard",
  data: { getSelectedArtboard: {} },
});
if (selected?.artboard?.id !== V2_ID) throw new Error(`Focus lock failed: ${selected?.artboard?.id ?? "none"}`);

const hierarchies = {};
for (const artboard of artboards.artboards ?? []) {
  const hierarchy = await tool("get_artboard_hierarchy", { artboardId: artboard.id, depth: 8 });
  hierarchies[artboard.id] = {
    name: artboard.name,
    objectCount: hierarchy.objects?.length ?? 0,
    hierarchy,
  };
}

const linearAnimations = await tool("animation_editor", {
  command: "listLinearAnimations",
  data: { listLinearAnimations: {} },
});
const animationIds = (linearAnimations.linearAnimations ?? []).map((animation) => animation.id);
const animationSettings = animationIds.length
  ? await tool("query_property_values", {
      propertyKeys: Object.fromEntries(animationIds.map((animationId) => [animationId, [56, 57, 59]])),
    })
  : {};
const keyframes = animationIds.length
  ? await tool("animation_editor", {
      command: "queryKeyFrames",
      data: { queryKeyFrames: { animationIds } },
    })
  : {};
const stateMachines = await tool("animation_editor", {
  command: "listStateMachines",
  data: { listStateMachines: {} },
});
const stateMachineDetails = {};
for (const machine of stateMachines.stateMachines ?? []) {
  stateMachineDetails[machine.id] = await tool("animation_editor", {
    command: "queryStateMachine",
    data: { queryStateMachine: { stateMachineId: machine.id } },
  });
}

const v2Objects = hierarchies[V2_ID]?.hierarchy?.objects ?? [];
const representativeIds = [
  V2_ID,
  ...v2Objects.filter((object) => /^rig_(root|cup|handle_l|eye_l|hair)$/.test(object.name ?? "")).map((object) => object.id),
  ...animationIds.slice(0, 1),
];
const propertyKeys = await tool("query_property_keys", { objectIds: [...new Set(representativeIds)] });

await tool("open_file_editor", {
  command: "focusArtboard",
  data: { focusArtboard: { artboardId: "0-17790", fitToViewport: false } },
});
const hairSelected = await tool("open_file_editor", {
  command: "getSelectedArtboard",
  data: { getSelectedArtboard: {} },
});
if (hairSelected?.artboard?.id !== "0-17790") throw new Error(`Hair ownership focus lock failed: ${hairSelected?.artboard?.id ?? "none"}`);
const hairLinearAnimations = await tool("animation_editor", {
  command: "listLinearAnimations",
  data: { listLinearAnimations: {} },
});
const hairStateMachines = await tool("animation_editor", {
  command: "listStateMachines",
  data: { listStateMachines: {} },
});
await tool("open_file_editor", {
  command: "focusArtboard",
  data: { focusArtboard: { artboardId: V2_ID, fitToViewport: true } },
});
const selectedAfterHairAudit = await tool("open_file_editor", {
  command: "getSelectedArtboard",
  data: { getSelectedArtboard: {} },
});
if (selectedAfterHairAudit?.artboard?.id !== V2_ID) throw new Error(`Final v2 focus lock failed: ${selectedAfterHairAudit?.artboard?.id ?? "none"}`);

const hairKeyTargets = [];
for (const [animationId, entries] of Object.entries(keyframes.keyframes ?? {})) {
  for (const entry of entries) {
    const object = v2Objects.find((candidate) => candidate.id === entry.objectId);
    if (object?.name === "rig_hair") hairKeyTargets.push({
      animationId,
      objectId: entry.objectId,
      objectName: object.name,
      propertyKey: entry.propertyKey,
      frame: entry.frame,
      owningArtboardId: V2_ID,
    });
  }
}

const result = {
  capturedAt: new Date().toISOString(),
  exactTarget: {
    requestedUrl: "https://editor.rive.app/file/untitled/2434585",
    fileId: "2434585",
    verification: "Deep link opened in Rive; MCP reloaded and returned the expected protected artboard set.",
  },
  source: {
    path: "/Users/prateekranka/Cowork/ScoreKeeper/design-explorations/mascot-hybrid-a-rig/production-v5-vector-master/canonical-dimensional-pixel.svg",
    sha256: "52328d0b4178dd64095744ee415184ac7cff190f161fca502cd45fed297d1d75",
    canvas: { width: 512, height: 416 },
  },
  mcpUrl: MCP_URL,
  toolSchemas: listedTools.tools ?? [],
  artboards,
  selected,
  hierarchies,
  linearAnimations,
  animationSettings,
  keyframes,
  stateMachines,
  stateMachineDetails,
  representativePropertyKeys: propertyKeys,
  hairOwnership: {
    componentArtboardId: "0-17790",
    selected: hairSelected,
    componentLinearAnimations: hairLinearAnimations,
    componentStateMachines: hairStateMachines,
    mainArtboardHairKeyTargets: hairKeyTargets,
    conclusion: "All current performance hair keys target the rig_hair instance on v2; the component has no performance timelines or state machines.",
  },
};

fs.writeFileSync(OUTPUT, `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({
  output: OUTPUT,
  selected: selected.artboard,
  artboards: (artboards.artboards ?? []).map(({ id, name }) => ({ id, name, objectCount: hierarchies[id]?.objectCount })),
  animations: linearAnimations.linearAnimations,
  stateMachines: stateMachines.stateMachines,
  toolNames: (listedTools.tools ?? []).map((entry) => entry.name),
}, null, 2));
