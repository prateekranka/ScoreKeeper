#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const V7 = path.dirname(HERE);
const URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const ARTBOARD_ID = "0-32354";
const TEMP_NAME = "__V3_TEMP__ ScoreKeeper Cup Hybrid A 20260715T1415Z-root-recovery";
const FINAL_NAME = "ScoreKeeper Cup Hybrid A - Production Rig v3";
const MACHINE_ID = "0-48286";
const FINAL_MACHINE_NAME = "ScoreKeeper Cup Hybrid A - Behaviors v3";
const EXPECTED_ANIMATIONS = new Map([
  ["idle_breathe_blink", "0-45292"],
  ["hair_bounce", "0-45614"],
  ["victory_pop", "0-45148"],
  ["curious_tilt", "0-45726"],
  ["celebrate_shimmy", "0-45405"],
]);
let rpcId = 1;

function assert(condition, message) { if (!condition) throw new Error(message); }
function readJson(file) { return JSON.parse(fs.readFileSync(file, "utf8")); }
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

async function main() {
  const live = readJson(path.join(HERE, "independent-live-query.json"));
  const proof = readJson(path.join(HERE, "proof-pack-v3/proof-report-v3.json"));
  const qa = readJson(path.join(HERE, "independent-qa-v3.json"));
  const reviewPath = path.join(V7, "evidence/reviews/sol-high-review-4.md");
  assert(live.passed && live.artboardId === ARTBOARD_ID && live.stateMachineId === MACHINE_ID, "live query gate failed");
  assert(proof.passed && qa.passed, "proof/QA gate failed");
  assert(fs.existsSync(reviewPath) && fs.readFileSync(reviewPath, "utf8").includes("REVIEW_APPROVED"), "fresh Sol High approval missing");

  await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-v3-publish", version: "1" } });
  await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
  const before = await tool("list_artboards", {});
  const artboards = before.artboards ?? [];
  assert(artboards.length === 7, `expected seven artboards, found ${artboards.length}`);
  assert(artboards.some((item) => item.id === ARTBOARD_ID && item.name === TEMP_NAME), "owned temp identity mismatch");
  assert(!artboards.some((item) => item.name === FINAL_NAME), `final name already exists: ${FINAL_NAME}`);
  await focus();

  const animations = await tool("animation_editor", { command: "listLinearAnimations", data: { listLinearAnimations: {} } });
  assert((animations.linearAnimations ?? []).length === 5, "five-animation gate failed at publish");
  for (const [name, id] of EXPECTED_ANIMATIONS) assert((animations.linearAnimations ?? []).some((item) => item.id === id && item.name === name), `animation identity mismatch ${name}`);
  const machines = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  assert((machines.stateMachines ?? []).length === 1 && machines.stateMachines[0].id === MACHINE_ID, "machine identity mismatch");

  await tool("rename_objects", { renames: [{ id: ARTBOARD_ID, name: FINAL_NAME }, { id: MACHINE_ID, name: FINAL_MACHINE_NAME }] });
  const after = await tool("list_artboards", {});
  assert((after.artboards ?? []).length === 7, "artboard count changed during publish");
  assert((after.artboards ?? []).some((item) => item.id === ARTBOARD_ID && item.name === FINAL_NAME), "final artboard rename verification failed");
  await focus();
  const machinesAfter = await tool("animation_editor", { command: "listStateMachines", data: { listStateMachines: {} } });
  assert((machinesAfter.stateMachines ?? []).some((item) => item.id === MACHINE_ID && item.name === FINAL_MACHINE_NAME), "final machine rename verification failed");

  const publish = {
    status: "published_v3",
    targetFileId: "2434585",
    artboardId: ARTBOARD_ID,
    artboardName: FINAL_NAME,
    stateMachineId: MACHINE_ID,
    stateMachineName: FINAL_MACHINE_NAME,
    animationIds: Object.fromEntries([...EXPECTED_ANIMATIONS].map(([name, id]) => [name, id])),
    artboardCount: 7,
    v2Preserved: (after.artboards ?? []).some((item) => item.id === "0-16469" && item.name === "ScoreKeeper Cup Hybrid A - Production Rig v2"),
    review: path.relative(HERE, reviewPath),
    publishedAt: new Date().toISOString(),
  };
  assert(publish.v2Preserved, "v2 preservation verification failed");
  fs.writeFileSync(path.join(HERE, "publish-report.json"), `${JSON.stringify(publish, null, 2)}\n`);
  fs.appendFileSync(path.join(V7, "evidence/opencode/opencode-status.md"), `\n- ${publish.publishedAt} — final publish; artboard ${ARTBOARD_ID} ${FINAL_NAME}; machine ${MACHINE_ID} ${FINAL_MACHINE_NAME}; v2 preserved; seven artboards.\n`);
  process.stdout.write(`${JSON.stringify(publish, null, 2)}\n`);
}

main().catch((error) => { console.error(error instanceof Error ? error.message : String(error)); process.exit(2); });
