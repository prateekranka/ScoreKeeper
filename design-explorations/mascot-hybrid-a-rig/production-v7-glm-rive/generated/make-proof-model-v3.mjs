#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { PIVOTS } from "./motion-spec-v3.mjs";
import { SEMANTIC_PARTS } from "../../production-v6-rive-rig/artwork-scanlines.mjs";
import { BRIDGES } from "./underlap-spec-v3.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const live = JSON.parse(fs.readFileSync(path.join(ROOT, "live-keyframes-v3.json"), "utf8"));
const liveUnderlaps = JSON.parse(fs.readFileSync(path.join(ROOT, "live-underlaps-v3.json"), "utf8"));
if (liveUnderlaps.underlapCount !== BRIDGES.length) throw new Error("live bridge count mismatch");
const canonicalPath = path.resolve(ROOT, "../../production-v5-vector-master/canonical-dimensional-pixel.svg");
const canonical = fs.readFileSync(canonicalPath, "utf8");
const canonicalSha256 = crypto.createHash("sha256").update(Buffer.from(canonical)).digest("hex");
if (canonicalSha256 !== live.source.sha256) throw new Error("canonical source hash mismatch");
const defsEnd = canonical.indexOf("</defs>") + "</defs>".length;
const graphics = [...canonical.slice(defsEnd).matchAll(/<(?:rect\b[^>]*\/>|path\b[^>]*\/>)/g)].map((match) => match[0]);
if (graphics.length !== 48) throw new Error(`expected 48 canonical graphics, found ${graphics.length}`);
const underlapBySource = new Map(BRIDGES.map((item) => [item.sourceIndex, item]));
const remap = new Map();
const derivedGraphics = [];
for (let index = 0; index < graphics.length; index += 1) {
  const underlap = underlapBySource.get(index);
  const mapped = [];
  if (underlap) {
    mapped.push(derivedGraphics.length);
    derivedGraphics.push(`<rect x="${underlap.x}" y="${underlap.y}" width="${underlap.width}" height="${underlap.height}" fill="${underlap.color}" opacity="0"/>`);
  }
  mapped.push(derivedGraphics.length);
  derivedGraphics.push(graphics[index]);
  remap.set(index, mapped);
}
const derivedPath = path.join(ROOT, "canonical-with-live-underlaps-v3.svg");
const derived = `${canonical.slice(0, defsEnd)}\n  <!-- Four queried-live motion-gated v3 seam bridges; canonical source remains immutable. -->\n  ${derivedGraphics.join("\n  ")}\n</svg>\n`;
fs.writeFileSync(derivedPath, derived);
const derivedSha256 = crypto.createHash("sha256").update(Buffer.from(derived)).digest("hex");
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
const model = {
  schema: "scorekeeper.rive-live-keyframes/v1",
  source: { path: "../production-v5-vector-master/canonical-dimensional-pixel.svg", sha256: canonicalSha256 },
  canvas: live.canvas,
  fps: live.fps,
  artboard: typeof live.artboard === "string" ? live.artboard : live.artboard.name,
  nodes,
  animations: live.animations,
  provenance: { liveArtboardId: live.liveArtboardId ?? live.artboard.id, liveExport: "live-keyframes-v3.json", liveUnderlaps: "live-underlaps-v3.json", canonicalAuthorityPath: canonicalPath, canonicalAuthoritySha256: canonicalSha256, derivedProofSourceSha256: derivedSha256, specHash: live.specHash, rendererClass: "fresh-live-query-semantic-reconstruction-with-queried-live-underlaps-not-runtime-capture" },
};
fs.writeFileSync(path.join(ROOT, "proof-model-v3.json"), `${JSON.stringify(model, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ artboard: model.artboard, animations: Object.keys(model.animations), nodes: model.nodes.length }, null, 2)}\n`);
