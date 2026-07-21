#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const AUDIT = JSON.parse(fs.readFileSync(path.join(ROOT, "live-v2-audit.json"), "utf8"));
const MOTION = JSON.parse(fs.readFileSync(path.resolve(ROOT, "../../../production-v6-rive-rig/live-keyframes.json"), "utf8"));
const objects = AUDIT.hierarchies["0-16469"].hierarchy.objects ?? [];
const nameById = new Map(objects.map((object) => [object.id, object.name]));
const animationNameById = new Map((AUDIT.linearAnimations.linearAnimations ?? []).map((animation) => [animation.id, animation.name]));

const live = [];
for (const [animationId, keys] of Object.entries(AUDIT.keyframes.keyframes ?? {})) {
  const groups = new Map();
  const interpolationTypes = new Set();
  for (const key of keys) {
    interpolationTypes.add(key.interpolationType ?? "unknown");
    const tuple = `${key.objectId}:${key.propertyKey}`;
    const group = groups.get(tuple) ?? { objectId: key.objectId, name: nameById.get(key.objectId), propertyKey: key.propertyKey, frames: [] };
    group.frames.push({ frame: Number(key.frame), value: key.value });
    groups.set(tuple, group);
  }
  const tracks = [...groups.values()];
  const settings = AUDIT.animationSettings.values?.[animationId] ?? {};
  const terminal = Number(settings[57]);
  const missingEndpoints = tracks.filter((track) => !track.frames.some((key) => key.frame === 0) || !track.frames.some((key) => key.frame === terminal));
  const nonClosing = tracks.filter((track) => {
    const first = track.frames.find((key) => key.frame === 0);
    const last = track.frames.find((key) => key.frame === terminal);
    return first && last && first.value !== last.value;
  });
  live.push({
    animationId,
    slug: animationNameById.get(animationId),
    fps: settings[56],
    terminalFrame: terminal,
    loop: settings[59] === 1,
    keyframeCount: keys.length,
    trackCount: tracks.length,
    movingControls: [...new Set(keys.map((key) => nameById.get(key.objectId)).filter(Boolean))].sort(),
    interpolationTypes: [...interpolationTypes].sort(),
    missingEndpointTracks: missingEndpoints,
    nonClosingTrackCount: nonClosing.length,
  });
}

const exported = Object.entries(MOTION.animations ?? {}).map(([slug, animation]) => {
  const curves = new Set();
  let trackCount = 0;
  for (const properties of Object.values(animation.tracks ?? {})) {
    for (const keys of Object.values(properties)) {
      trackCount += 1;
      for (const key of keys) curves.add(`${key.interpolation}:${(key.curve ?? []).join(",")}`);
    }
  }
  return { slug, durationFrames: animation.durationFrames, loop: animation.loop, trackCount, curveSignatures: [...curves].sort() };
});

const summary = {
  capturedFrom: "live-v2-audit.json",
  live,
  exported,
  structuralFindings: {
    extraDefaultTimeline: (AUDIT.linearAnimations.linearAnimations ?? []).some((animation) => animation.name === "Timeline 1"),
    extraDefaultStateMachine: (AUDIT.stateMachines.stateMachines ?? []).some((machine) => machine.name === "State Machine 1"),
    v2MachineHasEmptyDefaultLayer: (AUDIT.stateMachineDetails["0-32339"]?.layers ?? []).some((layer) => layer.layerName === "Layer 1" && layer.transitions.length === 0),
    backend: "pivot-fk",
    capabilityReason: "No live tool schema exposes bones, weights, deformers, or constraints.",
  },
};

fs.writeFileSync(path.join(ROOT, "live-v2-summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
console.log(JSON.stringify(summary, null, 2));
