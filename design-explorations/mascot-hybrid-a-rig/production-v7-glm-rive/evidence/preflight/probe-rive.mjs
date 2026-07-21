#!/usr/bin/env node

const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
let rpcId = 1;

async function request(payload) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
    },
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
  if (!text) return result;
  try { return JSON.parse(text); } catch { return text; }
}

await rpc("initialize", {
  protocolVersion: "2025-06-18",
  capabilities: {},
  clientInfo: { name: "scorekeeper-v7-readonly-preflight", version: "1" },
});
await request({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });

const tools = await rpc("tools/list");
const artboards = await tool("list_artboards", {});
const selected = await tool("open_file_editor", {
  command: "getSelectedArtboard",
  data: { getSelectedArtboard: {} },
});

console.log(JSON.stringify({
  mcpUrl: MCP_URL,
  tools: (tools?.tools ?? []).map(({ name, description, inputSchema }) => ({ name, description, inputSchema })),
  artboards,
  selected,
}, null, 2));
