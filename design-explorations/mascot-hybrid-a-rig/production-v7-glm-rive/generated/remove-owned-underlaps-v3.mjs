#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { BRIDGES, BRIDGE_PREFIX } from "./underlap-spec-v3.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const ARTBOARD_ID = "0-32354";
const manifest = JSON.parse(fs.readFileSync(path.join(HERE, "live-underlaps-v3.json"), "utf8"));
let rpcId = 1;
const assert = (condition, message) => { if (!condition) throw new Error(message); };
async function request(payload) { const response = await fetch(URL, { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" }, body: JSON.stringify(payload) }); if (response.status === 202) return {}; const body = await response.json(); if (!response.ok || body.error) throw new Error(body.error?.message ?? `HTTP ${response.status}`); return body; }
async function rpc(method, params = {}) { return (await request({ jsonrpc: "2.0", id: rpcId++, method, params })).result; }
async function tool(name, args = {}) { const result = await rpc("tools/call", { name, arguments: args }); const text = result?.content?.find((item) => item.type === "text")?.text; let parsed = result; if (text) { try { parsed = JSON.parse(text); } catch { parsed = text; } } if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`); return parsed; }

await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "scorekeeper-v3-remove-owned-underlaps", version: "1" } });
await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
await tool("open_file_editor", { command: "focusArtboard", data: { focusArtboard: { artboardId: ARTBOARD_ID, fitToViewport: true } } });
const hierarchy = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
const byId = new Map((hierarchy.objects ?? []).map((object) => [object.id, object]));
const expectedNames = new Set(BRIDGES.map((item) => item.name));
const owned = (hierarchy.objects ?? []).filter((object) => object.name?.startsWith(BRIDGE_PREFIX));
assert(owned.length === BRIDGES.length && owned.every((object) => expectedNames.has(object.name)), "owned bridge identity set mismatch");
assert(manifest.objects.length === BRIDGES.length && manifest.objects.every((row) => byId.get(row.id)?.name === row.name && expectedNames.has(row.name)), "saved manifest no longer matches live owned bridge objects");
await tool("delete_objects", { objectIds: manifest.objects.map((row) => row.id) });
const after = await tool("get_artboard_hierarchy", { artboardId: ARTBOARD_ID, depth: 8 });
assert(!(after.objects ?? []).some((object) => object.name?.startsWith(BRIDGE_PREFIX)), "owned bridge removal incomplete");
const record = { status: "owned_bridges_removed_for_color_matched_replacement", artboardId: ARTBOARD_ID, removed: manifest.objects.map(({ id, name }) => ({ id, name })), objectCountBefore: (hierarchy.objects ?? []).length, objectCountAfter: (after.objects ?? []).length, removedAt: new Date().toISOString() };
fs.writeFileSync(path.join(HERE, "removed-underlaps-v3.json"), `${JSON.stringify(record, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ status: record.status, removed: record.removed.length, objectCountAfter: record.objectCountAfter }, null, 2)}\n`);
