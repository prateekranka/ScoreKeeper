#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { BRIDGES, UNDERLAPS, UNDERLAP_BANDS, underlapName } from "./underlap-spec-v3.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PROOFS = path.join(HERE, "proofs");
const OUT = path.join(HERE, "underlap-simulation");
const ITEMS = process.env.UNDERLAP_BRIDGES === "1" ? BRIDGES : process.env.UNDERLAP_SIMPLE === "1" ? UNDERLAPS : UNDERLAP_BANDS;
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
const cases = [["curious_tilt", 28], ["celebrate_shimmy", 25], ["victory_pop", 24], ["idle_breathe_blink", 0]];

for (const [slug, frame] of cases) {
  const source = path.join(PROOFS, slug, "svg", `frame-${String(frame).padStart(4, "0")}.svg`);
  let svg = fs.readFileSync(source, "utf8");
  svg = svg.replace(/\s*<g id="__V3_UNDERLAP__[^>]+>.*?<\/g>/g, "");
  const additionsBySource = new Map();
  for (const item of ITEMS) {
    const id = `asset_${item.semantic}__source_${String(item.sourceIndex).padStart(3, "0")}`;
    const match = svg.match(new RegExp(`<g id="${id}" transform="([^"]+)"`));
    if (!match) throw new Error(`missing ${id} in ${source}`);
    const additions = additionsBySource.get(id) ?? [];
    const name = item.name ?? underlapName(item);
    const opacity = process.env.UNDERLAP_BRIDGES === "1" && slug === "idle_breathe_blink" ? 0 : 1;
    additions.push(`<g id="${name}" transform="${match[1]}" opacity="${opacity}"><rect x="${item.x}" y="${item.y}" width="${item.width}" height="${item.height}" fill="${item.color}"/></g>`);
    additionsBySource.set(id, additions);
  }
  for (const [id, additions] of additionsBySource) svg = svg.replace(`<g id="${id}"`, `${additions.join("\n  ")}\n  <g id="${id}"`);
  const svgOut = path.join(OUT, `${slug}-f${String(frame).padStart(4, "0")}.svg`);
  const pngOut = path.join(OUT, `${slug}-f${String(frame).padStart(4, "0")}.png`);
  fs.writeFileSync(svgOut, svg);
  execFileSync("/usr/bin/sips", ["-s", "format", "png", svgOut, "--out", pngOut], { stdio: "ignore" });
}
process.stdout.write(`${JSON.stringify({ cases: cases.length, underlaps: ITEMS.length, output: OUT }, null, 2)}\n`);
