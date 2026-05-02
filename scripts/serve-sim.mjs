#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const project = "ScoreKeeper.xcodeproj";
const scheme = "ScoreKeeper";
const bundleId = "com.prateekranka.scorekeeper";
const derivedDataPath = "build/ServeSimDerivedData";

const passthroughArgs = process.argv.slice(2);
const requestedDevice =
  process.env.SERVE_SIM_DEVICE || passthroughArgs.find((arg) => !arg.startsWith("-"));

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    shell: false,
    ...options,
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function tryRun(command, args) {
  return spawnSync(command, args, {
    stdio: "inherit",
    shell: false,
  });
}

function readAvailableSimulators() {
  const result = spawnSync("xcrun", ["simctl", "list", "devices", "available", "-j"], {
    encoding: "utf8",
    shell: false,
  });

  if (result.status !== 0) {
    process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }

  const payload = JSON.parse(result.stdout);
  return Object.values(payload.devices)
    .flat()
    .filter((device) => device.isAvailable && !device.name.includes("Apple Watch"));
}

function resolveDevice() {
  const devices = readAvailableSimulators();
  const requested =
    requestedDevice &&
    devices.find((device) => device.name === requestedDevice || device.udid === requestedDevice);

  if (requested) {
    return requested;
  }

  if (requestedDevice) {
    console.error(`No available simulator matched "${requestedDevice}".`);
    process.exit(1);
  }

  const preferred = devices.find((device) => device.name === "iPhone 16 Pro");
  const fallback = devices.find((device) => device.name.startsWith("iPhone")) || devices[0];

  if (!preferred && !fallback) {
    console.error("No available iOS simulators found. Install one in Xcode first.");
    process.exit(1);
  }

  return preferred || fallback;
}

const device = resolveDevice();
const destination = `platform=iOS Simulator,id=${device.udid}`;

console.log(`Booting ${device.name} (${device.udid})...`);
tryRun("xcrun", ["simctl", "boot", device.udid]);
tryRun("open", ["-a", "Simulator"]);

console.log("Building ScoreKeeper for iOS Simulator...");
run("xcodebuild", [
  "-project",
  project,
  "-scheme",
  scheme,
  "-configuration",
  "Debug",
  "-destination",
  destination,
  "-derivedDataPath",
  derivedDataPath,
  "build",
]);

const appPath = `${derivedDataPath}/Build/Products/Debug-iphonesimulator/${scheme}.app`;

console.log("Installing and launching ScoreKeeper...");
run("xcrun", ["simctl", "install", "booted", appPath]);
run("xcrun", ["simctl", "launch", "booted", bundleId]);

console.log("Serving booted simulator at http://localhost:3200...");
run("npx", ["serve-sim", device.udid]);
