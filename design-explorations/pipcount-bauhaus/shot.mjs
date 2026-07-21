// Verification capture for the Bauhaus exploration — light + dark.
// Uses headless Chrome directly (playwright module isn't resolvable in this env).
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";

const root = path.dirname(fileURLToPath(import.meta.url));
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const file = (rel) => "file://" + path.join(root, rel);
const shots = path.join(root, "screenshots");
fs.mkdirSync(shots, { recursive: true });

function shoot(url, size, out, scale = 2) {
  const r = spawnSync(
    CHROME,
    [
      "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
      `--force-device-scale-factor=${scale}`,
      `--window-size=${size[0]},${size[1]}`,
      "--virtual-time-budget=1500",
      `--screenshot=${out}`,
      url,
    ],
    { stdio: "ignore" }
  );
  return r.status === 0;
}

// Capture at-rest (device at native 402x874) + full content (device grows to fit).
// `prefix` = "home" (light) or "home-dark" (dark).
function capture(prefix) {
  const atRest = shoot(file(`${prefix}.html`), [402, 874], path.join(shots, `${prefix}.png`));
  console.log(`${prefix} at-rest:`, atRest);

  const tallHtml = fs.readFileSync(path.join(root, `${prefix}.html`), "utf8")
    .replace("</head>", "<style>.device{height:auto;min-height:0;border-radius:30px}.screen{height:auto;min-height:0;overflow:visible}</style></head>");
  const tallPath = path.join(root, `_${prefix}-tall.html`);
  fs.writeFileSync(tallPath, tallHtml);
  const full = shoot(file(`_${prefix}-tall.html`), [402, 1700], path.join(shots, `${prefix}-full.png`));
  fs.unlinkSync(tallPath);
  console.log(`${prefix} full:`, full);
}

capture("home");
capture("home-dark");

// Index hub.
console.log("index:", shoot(file("index.html"), [1100, 1500], path.join(shots, "index.png"), 1));

console.log("Done.");
