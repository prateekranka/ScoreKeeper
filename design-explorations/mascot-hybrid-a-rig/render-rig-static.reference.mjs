#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CANVAS, COLORS, NODES } from "./rig-spec.mjs";

const ROOT = new URL(".", import.meta.url).pathname;
const SVG_DIR = join(ROOT, "svg");
const PREVIEW_DIR = join(ROOT, "previews");

function number(value) {
  return Math.round(value * 1000) / 1000;
}

function svgColor(riveColor) {
  if (/^#[0-9A-Fa-f]{8}$/.test(riveColor)) return `#${riveColor.slice(3)}`;
  return riveColor;
}

function pathData(commands) {
  return commands
    .map((command) => {
      if (command.commandType === "moveTo") return `M ${number(command.x)} ${number(command.y)}`;
      if (command.commandType === "lineTo") return `L ${number(command.x)} ${number(command.y)}`;
      if (command.commandType === "cubicTo") {
        return `C ${number(command.control1X)} ${number(command.control1Y)} ${number(command.control2X)} ${number(command.control2Y)} ${number(command.endX)} ${number(command.endY)}`;
      }
      if (command.commandType === "close") return "Z";
      throw new Error(`Unsupported path command ${command.commandType}`);
    })
    .join(" ");
}

function partMarkup(node) {
  const fill = node.paints.find((paint) => paint.paintType === "fill");
  const stroke = node.paints.find((paint) => paint.paintType === "stroke");
  const attributes = [
    fill ? `fill="${svgColor(fill.color)}"` : 'fill="none"',
    stroke ? `stroke="${svgColor(stroke.color)}"` : "",
    stroke ? `stroke-width="${stroke.width}"` : "",
    stroke ? 'stroke-linecap="round" stroke-linejoin="round"' : "",
  ]
    .filter(Boolean)
    .join(" ");
  return `<g id="${node.name}" transform="translate(${node.x} ${node.y})">
${node.paths.map((path) => `  <path id="${node.name}__${path.name}" d="${pathData(path.commands)}" ${attributes}/>`).join("\n")}
</g>`;
}

function pivotTransform(node) {
  const transforms = [`translate(${node.x} ${node.y})`];
  if (node.base.rotation) transforms.push(`rotate(${(node.base.rotation * 180) / Math.PI})`);
  if (node.base.scaleX !== 1 || node.base.scaleY !== 1) {
    transforms.push(`scale(${node.base.scaleX} ${node.base.scaleY})`);
  }
  return transforms.join(" ");
}

function buildTree() {
  const children = new Map();
  for (const node of NODES) {
    const siblings = children.get(node.parent) ?? [];
    siblings.push(node);
    children.set(node.parent, siblings);
  }
  function render(node, depth = 0) {
    const indent = "  ".repeat(depth);
    if (node.kind === "part") return `${indent}${partMarkup(node).replaceAll("\n", `\n${indent}`)}`;
    const contents = (children.get(node.name) ?? []).map((child) => render(child, depth + 1)).join("\n");
    return `${indent}<g id="${node.name}" transform="${pivotTransform(node)}" opacity="${node.base.opacity}">
${contents}
${indent}</g>`;
  }
  return (children.get(null) ?? []).map((node) => render(node, 1)).join("\n");
}

function main() {
  mkdirSync(SVG_DIR, { recursive: true });
  mkdirSync(PREVIEW_DIR, { recursive: true });
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}">
  <rect width="${CANVAS}" height="${CANVAS}" fill="${COLORS.cobalt}"/>
${buildTree()}
</svg>
`;
  const svgPath = join(SVG_DIR, "pocket-bookkeeper-neutral.svg");
  const previewPath = join(PREVIEW_DIR, "pocket-bookkeeper-neutral.png");
  writeFileSync(svgPath, svg);
  execFileSync("cairosvg", [svgPath, "-o", previewPath, "--output-width", "512", "--output-height", "512"]);
  console.log(JSON.stringify({ svgPath, previewPath }, null, 2));
}

main();
