#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const MCP_URL = process.env.RIVE_MCP_URL ?? "http://127.0.0.1:9791/mcp";
const SVG_PATH = join(ROOT, "svg", "scorekeeper-cup-hybrid-a-canonical.svg");
const RUN_ID = process.env.RIVE_RUN_ID ?? new Date().toISOString().replace(/[-:.]/g, "").replace("Z", "Z");
const ARTBOARD_NAME = `__SVG_PROOF__ ScoreKeeper Cup Hybrid A ${RUN_ID}`;
const TRANSACTION_PATH = join(ROOT, "transaction.json");
const ARTBOARD_WIDTH = 512;
const ARTBOARD_HEIGHT = 416;
const PAPER = "#fff4f2ec";
const CHUNK_SIZE = 24;

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
  if (!response.ok) throw new Error(`HTTP ${response.status} ${response.statusText}`);
  const result = await response.json();
  if (result.error) throw new Error(result.error.message ?? JSON.stringify(result.error));
  return result.result;
}

async function rpc(method, params = {}) {
  return request({ jsonrpc: "2.0", id: rpcId++, method, params });
}

async function notify(method, params = {}) {
  return request({ jsonrpc: "2.0", method, params });
}

async function tool(name, args = {}) {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.find((item) => item.type === "text")?.text;
  const parsed = text ? JSON.parse(text) : result;
  if (parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed.errors)}`);
  if (parsed?.success === false) throw new Error(`${name}: ${parsed.error ?? parsed.message}`);
  return parsed;
}

async function initialize() {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "codex-scorekeeper-svg-proof", version: "1.0" },
  });
  await notify("notifications/initialized");
}

function parsePaths(svg) {
  const entries = [];
  const pathPattern = /<path\s+d="([^"]+)"\s+fill="(#[0-9A-Fa-f]{6})"(?:\s+transform="translate\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)")?\s*\/>/g;
  let match;
  while ((match = pathPattern.exec(svg))) {
    const [, d, fill, txRaw = "0", tyRaw = "0"] = match;
    const tx = Number(txRaw);
    const ty = Number(tyRaw);
    const tokens = d.match(/[MLZ]|-?\d+(?:\.\d+)?/g) ?? [];
    const paths = [];
    let commands = [];
    let index = 0;
    while (index < tokens.length) {
      const token = tokens[index++];
      if (token === "M" || token === "L") {
        const x = Number(tokens[index++]) + tx;
        const y = Number(tokens[index++]) + ty;
        commands.push({ commandType: token === "M" ? "moveTo" : "lineTo", x, y });
      } else if (token === "Z") {
        commands.push({ commandType: "close" });
        paths.push({ name: `contour-${paths.length + 1}`, commands });
        commands = [];
      } else {
        throw new Error(`Unsupported SVG path token: ${token}`);
      }
    }
    if (commands.length) throw new Error("Canonical SVG contains an unclosed path");
    entries.push({ fill: `#ff${fill.slice(1).toLowerCase()}`, paths });
  }
  if (!entries.length) throw new Error("No supported SVG paths were found");
  return entries;
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) result.push(items.slice(index, index + size));
  return result;
}

async function focusLock(artboardId) {
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId, fitToViewport: true } },
  });
  await new Promise((resolve) => setTimeout(resolve, 350));
  const selected = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  if (selected.artboard?.id !== artboardId) {
    throw new Error(`Focus lock failed: expected ${artboardId}, found ${selected.artboard?.id ?? "none"}`);
  }
}

async function setArtboardPaper(artboardId) {
  const query = await tool("query_objects", { objectIds: [artboardId], depth: 2 });
  const byId = new Map((query.objects ?? []).map((object) => [object.id, object]));
  const artboard = byId.get(artboardId);
  const fill = (artboard?.children ?? []).map((id) => byId.get(id)).find((object) => object?.types?.includes("Fill"));
  const color = (fill?.children ?? []).map((id) => byId.get(id)).find((object) => object?.types?.includes("SolidColor"));
  if (!color?.id) throw new Error("New artboard does not expose a background SolidColor");
  await tool("set_property_values", { propertyValues: { [color.id]: { 37: PAPER } } });
  const verification = await tool("query_property_values", { propertyKeys: { [color.id]: [37] } });
  const actual = String(verification.values?.[color.id]?.[37] ?? "").toLowerCase();
  if (actual !== PAPER) throw new Error(`Artboard background mismatch: expected ${PAPER}, found ${actual}`);
}

async function main() {
  const svg = readFileSync(SVG_PATH, "utf8");
  const vectorPaths = parsePaths(svg);
  await initialize();

  const before = await tool("list_artboards", {});
  if ((before.artboards ?? []).some((artboard) => artboard.name === ARTBOARD_NAME)) {
    throw new Error(`Refusing artboard name collision: ${ARTBOARD_NAME}`);
  }
  const x = Math.max(0, ...(before.artboards ?? []).map((artboard) => Number(artboard.x ?? 0) + Number(artboard.width ?? 0))) + 160;
  await tool("open_file_editor", {
    command: "createArtboard",
    data: {
      createArtboard: [{ name: ARTBOARD_NAME, x, y: 0, width: ARTBOARD_WIDTH, height: ARTBOARD_HEIGHT, isComponent: false }],
    },
  });
  const after = await tool("list_artboards", {});
  const matches = (after.artboards ?? []).filter((artboard) => artboard.name === ARTBOARD_NAME);
  if (matches.length !== 1) throw new Error(`Expected one created artboard, found ${matches.length}`);
  const artboardId = matches[0].id;

  await focusLock(artboardId);
  await setArtboardPaper(artboardId);

  const shapes = vectorPaths.map((entry, index) => ({
    parentId: artboardId,
    name: `svg-trace-${String(index + 1).padStart(3, "0")}`,
    x: 0,
    y: 0,
    paints: [{ paintType: "fill", color: entry.fill }],
    paths: entry.paths,
  }));

  for (const chunk of chunks(shapes, CHUNK_SIZE)) {
    await focusLock(artboardId);
    await tool("path_editor", { command: "createShapes", data: { createShapes: { shapes: chunk } } });
  }

  await focusLock(artboardId);
  const hierarchy = await tool("get_artboard_hierarchy", { artboardId, depth: 3 });
  const shapeCount = (hierarchy.objects ?? []).filter((object) => object.types?.includes("Shape")).length;
  if (shapeCount !== shapes.length) throw new Error(`Imported shape count mismatch: expected ${shapes.length}, found ${shapeCount}`);

  const transaction = {
    status: "svg-proof-imported",
    runId: RUN_ID,
    artboardId,
    artboardName: ARTBOARD_NAME,
    canvas: [ARTBOARD_WIDTH, ARTBOARD_HEIGHT],
    canonicalSvg: SVG_PATH,
    importedShapeCount: shapeCount,
    riggingStarted: false,
    canonicalMasterApproved: false,
  };
  writeFileSync(TRANSACTION_PATH, `${JSON.stringify(transaction, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(transaction, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? error.message ?? String(error));
  process.exitCode = 1;
});
