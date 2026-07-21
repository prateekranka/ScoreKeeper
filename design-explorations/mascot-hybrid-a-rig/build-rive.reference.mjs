#!/usr/bin/env node

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import {
  BASE_BY_NAME,
  CANVAS,
  COLORS,
  FPS,
  NODES,
  PARTS,
  PIVOTS,
  RIVE_COLORS,
} from "./rig-spec.mjs";
import {
  PERFORMANCE_BY_SLUG,
  PERFORMANCE_SPECS,
  terminalFrame,
  validatePerformanceSpecs,
} from "./performance-spec.mjs";

const ROOT = fileURLToPath(new URL(".", import.meta.url));
const MCP_URL = "http://127.0.0.1:9791/mcp";
const TEMP_ARTBOARD_NAME = "__BUILDING__ Pocket Bookkeeper - Articulated Rig v5";
const FINAL_ARTBOARD_NAME = "Pocket Bookkeeper - Articulated Rig v5";
const STATE_MACHINE_NAME = "Pocket Bookkeeper Behaviors v5";
const STATE_LAYER_NAME = "Behavior";
const SUMMARY_PATH = join(ROOT, "rive-build-summary-v5.json");
const ARTBOARD_X = 0;
const ARTBOARD_Y = 5500;
// Six reaches the deepest authored Shape (root → upper arm → forearm → paw →
// pen → visible pen part) without asking Rive to serialize every path vertex.
const HIERARCHY_DEPTH = 8;
const KEYFRAME_CHUNK_SIZE = 110;
const PROPERTY_CHUNK_SIZE = 45;
const EPSILON = 1e-5;

const PROPERTY = Object.freeze({
  dx: 13,
  dy: 14,
  rotationDeg: 15,
  scaleX: 16,
  scaleY: 17,
  opacity: 18,
});

const TRANSFORM_PROPERTY_KEYS = [13, 14, 15, 16, 17, 18];
const ANIMATION_PROPERTY = Object.freeze({
  fps: 56,
  durationFrames: 57,
  loopValue: 59,
});

let rpcId = 1;

async function rpc(method, params = {}) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: rpcId++, method, params }),
  });
  if (!response.ok) {
    throw new Error(`${method}: HTTP ${response.status} ${response.statusText}`);
  }
  const payload = await response.json();
  if (payload.error) throw new Error(`${method}: ${payload.error.message}`);
  return payload.result;
}

async function notify(method, params = {}) {
  const response = await fetch(MCP_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
    },
    body: JSON.stringify({ jsonrpc: "2.0", method, params }),
  });
  if (!response.ok) throw new Error(`${method}: HTTP ${response.status}`);
}

async function tool(name, arguments_ = {}) {
  const result = await rpc("tools/call", { name, arguments: arguments_ });
  const content = result?.content ?? [];
  const text = content.find((item) => item.type === "text")?.text;
  let parsed = result;
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      throw new Error(`${name}: Rive returned non-JSON text: ${text.slice(0, 500)}`);
    }
  }
  if (parsed?.errors?.length) {
    throw new Error(`${name}: ${JSON.stringify(parsed.errors)}`);
  }
  if (parsed?.success === false) {
    throw new Error(`${name}: ${parsed.error ?? parsed.message ?? JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function initialize() {
  await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "codex-pocket-bookkeeper-rig-v5", version: "5.0" },
  });
  await notify("notifications/initialized").catch(() => {});
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function closeEnough(left, right, epsilon = EPSILON) {
  return Math.abs(Number(left) - Number(right)) <= epsilon;
}

function uniqueByName(objects, name, context) {
  const matches = objects.filter((object) => object.name === name);
  if (matches.length !== 1) {
    throw new Error(`${context}: expected exactly one ${name}, found ${matches.length}`);
  }
  return matches[0];
}

function assertPropertySchema(schema, objectIds, requiredKeys, context) {
  const properties = schema.properties ?? {};
  for (const objectId of objectIds) {
    const available = new Set(
      Object.values(properties[objectId] ?? {})
        .map(Number)
        .filter(Number.isFinite),
    );
    for (const key of requiredKeys) {
      assert(available.has(key), `${context}: object ${objectId} does not expose property key ${key}`);
    }
  }
}

function validateSourceSpecs() {
  validatePerformanceSpecs(PERFORMANCE_SPECS, { throwOnError: true });
  assert(CANVAS === 512, `The v5 Rive contract requires a 512px artboard, found ${CANVAS}`);
  assert(FPS === 60, `The v5 Rive contract requires 60fps, found ${FPS}`);
  assert(NODES.length === PIVOTS.length + PARTS.length, "NODES/PIVOTS/PARTS disagree");
  assert(PERFORMANCE_SPECS.length === 7, `Expected seven performances, found ${PERFORMANCE_SPECS.length}`);

  const nodeNames = NODES.map((node) => node.name);
  assert(new Set(nodeNames).size === nodeNames.length, "Rig node names are not unique");
  const pivotNames = new Set(PIVOTS.map((pivot) => pivot.name));
  const earlier = new Set();
  for (const node of NODES) {
    if (node.parent !== null) {
      assert(earlier.has(node.parent), `${node.name}: parent ${node.parent} must precede its child in NODES`);
      assert(pivotNames.has(node.parent), `${node.name}: parent ${node.parent} is not a pivot`);
    }
    earlier.add(node.name);
  }
  assert(PIVOTS.filter((pivot) => pivot.parent === null).length === 1, "Rig must have exactly one root pivot");

  const animationNames = PERFORMANCE_SPECS.map((spec) => spec.slug);
  const slugs = PERFORMANCE_SPECS.map((spec) => spec.slug);
  assert(new Set(animationNames).size === animationNames.length, "Performance animation names are not unique");
  assert(new Set(slugs).size === slugs.length, "Performance slugs are not unique");
  for (const spec of PERFORMANCE_SPECS) {
    assert(PERFORMANCE_BY_SLUG[spec.slug]?.name === spec.name, `${spec.slug}: PERFORMANCE_BY_SLUG is inconsistent`);
    assert(Number.isFinite(spec.durationSeconds) && spec.durationSeconds > 0, `${spec.name}: invalid duration`);
    assert(terminalFrame(spec) === Math.round(spec.durationSeconds * FPS), `${spec.name}: terminal frame mismatch`);
    for (const [pivotName, properties] of Object.entries(spec.tracks)) {
      assert(BASE_BY_NAME[pivotName], `${spec.name}: track targets unknown pivot ${pivotName}`);
      for (const [property, keys] of Object.entries(properties)) {
        assert(PROPERTY[property], `${spec.name}/${pivotName}: unsupported property ${property}`);
        assert(Array.isArray(keys) && keys.length >= 2, `${spec.name}/${pivotName}/${property}: requires at least two keys`);
        assert(keys[0][0] === 0, `${spec.name}/${pivotName}/${property}: missing frame 0`);
        assert(keys.at(-1)[0] === terminalFrame(spec), `${spec.name}/${pivotName}/${property}: missing terminal frame`);
        for (let index = 0; index < keys.length; index += 1) {
          const [frame, value] = keys[index];
          assert(Number.isInteger(frame), `${spec.name}/${pivotName}/${property}: non-integer frame ${frame}`);
          assert(frame >= 0 && frame <= terminalFrame(spec), `${spec.name}/${pivotName}/${property}: frame ${frame} out of bounds`);
          assert(Number.isFinite(value), `${spec.name}/${pivotName}/${property}: non-finite value at ${frame}`);
          if (index > 0) {
            assert(frame > keys[index - 1][0], `${spec.name}/${pivotName}/${property}: frames must increase strictly`);
          }
        }
        if (spec.loop) {
          assert(
            closeEnough(keys[0][1], keys.at(-1)[1]),
            `${spec.name}/${pivotName}/${property}: loop endpoints differ`,
          );
        }
      }
    }
  }
}

async function focusLock(artboardId) {
  await tool("open_file_editor", {
    command: "focusArtboard",
    data: { focusArtboard: { artboardId, fitToViewport: true } },
  });
  await new Promise((resolve) => setTimeout(resolve, 350));
  let stageSelectionVerified = false;
  try {
    await tool("select_objects", { objectIds: [artboardId] });
    stageSelectionVerified = true;
  } catch (error) {
    // Rive Beta can create the Core artboard before its Stage proxy exists.
    // Active-artboard focus is sufficient for scoped editor commands; retain
    // the stricter selection check whenever the proxy is available.
    if (!String(error?.message ?? error).includes("no stage representation")) throw error;
  }
  const selected = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  const listed = await tool("list_artboards", {});
  const activeId = selected.artboard?.id;
  const selectionId = listed.selectionArtboardId;
  if (activeId !== artboardId || (stageSelectionVerified && selectionId !== artboardId)) {
    throw new Error(
      `Rive focus race: requested ${artboardId}, active ${activeId ?? "none"}, selected ${selectionId ?? "none"}`,
    );
  }
  return { activeId, selectionId, stageSelectionVerified };
}

async function getHierarchy(artboardId) {
  const hierarchy = await tool("get_artboard_hierarchy", {
    artboardId,
    depth: HIERARCHY_DEPTH,
  });
  assert(Array.isArray(hierarchy.objects), "Rive hierarchy response omitted objects");
  return hierarchy;
}

async function setArtboardFillColor(artboardId, color = RIVE_COLORS.cobalt) {
  const query = await tool("query_objects", { objectIds: [artboardId], depth: 2 });
  const objects = query.objects ?? [];
  const byId = new Map(objects.map((object) => [object.id, object]));
  const artboard = byId.get(artboardId);
  const fill = (artboard?.children ?? [])
    .map((id) => byId.get(id))
    .find((object) => object?.types?.includes("Fill"));
  const solidColor = (fill?.children ?? [])
    .map((id) => byId.get(id))
    .find((object) => object?.types?.includes("SolidColor"));
  if (!solidColor?.id) throw new Error(`Missing artboard SolidColor for ${artboardId}`);
  await tool("set_property_values", {
    propertyValues: { [solidColor.id]: { 37: color } },
  });
  const verification = await tool("query_property_values", {
    propertyKeys: { [solidColor.id]: [37] },
  });
  const actual = verification.values?.[solidColor.id]?.[37];
  if (String(actual).toLowerCase() !== color.toLowerCase()) {
    throw new Error(`Could not set artboard fill on ${artboardId}; expected ${color}, found ${actual}`);
  }
  return solidColor.id;
}

function transparentPivotShape(node, parentId) {
  return {
    parentId,
    name: node.name,
    x: 0,
    y: 0,
    paints: [{ paintType: "fill", color: RIVE_COLORS.transparent }],
    paths: [{
      name: `${node.name}__pivot_path`,
      commands: [
        { commandType: "moveTo", x: 0, y: 0 },
        { commandType: "lineTo", x: 0.01, y: 0 },
        { commandType: "lineTo", x: 0, y: 0.01 },
        { commandType: "close" },
      ],
    }],
  };
}

function visiblePartShape(node, parentId) {
  return {
    parentId,
    name: node.name,
    x: node.x ?? 0,
    y: node.y ?? 0,
    paints: node.paints,
    paths: node.paths,
  };
}

function expectedBaseTransform(node) {
  if (node.kind === "pivot") {
    const base = BASE_BY_NAME[node.name];
    return {
      13: base.x,
      14: base.y,
      15: base.rotation,
      16: base.scaleX,
      17: base.scaleY,
      18: base.opacity,
    };
  }
  return {
    13: node.x ?? 0,
    14: node.y ?? 0,
    15: 0,
    16: 1,
    17: 1,
    18: 1,
  };
}

async function resolveUniqueNode(artboardId, nodeName) {
  const hierarchy = await getHierarchy(artboardId);
  return uniqueByName(
    hierarchy.objects.filter((object) => object.types?.includes("Shape")),
    nodeName,
    "Rive geometry",
  );
}

async function createRigGeometry(artboardId) {
  const idsByName = new Map();
  for (const node of NODES) {
    const parentId = node.parent === null ? artboardId : idsByName.get(node.parent);
    assert(parentId, `${node.name}: unresolved parent ${node.parent}`);
    const shape = node.kind === "pivot"
      ? transparentPivotShape(node, parentId)
      : visiblePartShape(node, parentId);
    await tool("path_editor", {
      command: "createShapes",
      data: { createShapes: { shapes: [shape] } },
    });
    // Only pivots are referenced as parents by later payloads. Resolve those
    // immediately; defer the 61 leaf-part lookups to one final hierarchy read.
    if (node.kind === "pivot") {
      const created = await resolveUniqueNode(artboardId, node.name);
      idsByName.set(node.name, created.id);
    }
  }

  const hierarchy = await getHierarchy(artboardId);
  const shapes = hierarchy.objects.filter((object) => object.types?.includes("Shape"));
  for (const node of NODES) {
    const created = uniqueByName(shapes, node.name, "Rive geometry");
    if (idsByName.has(node.name)) {
      assert(idsByName.get(node.name) === created.id, `${node.name}: pivot identity changed during creation`);
    }
    idsByName.set(node.name, created.id);
  }

  for (const group of chunks(NODES, PROPERTY_CHUNK_SIZE)) {
    await tool("set_property_values", {
      propertyValues: Object.fromEntries(
        group.map((node) => [idsByName.get(node.name), expectedBaseTransform(node)]),
      ),
    });
  }
  return idsByName;
}

function parentMap(objects) {
  const result = new Map();
  for (const object of objects) {
    for (const childId of object.children ?? []) {
      const previous = result.get(childId);
      if (previous && previous !== object.id) {
        throw new Error(`Hierarchy child ${childId} has multiple parents: ${previous}, ${object.id}`);
      }
      result.set(childId, object.id);
    }
  }
  return result;
}

async function queryTransformValues(ids) {
  const values = {};
  for (const group of chunks(ids, PROPERTY_CHUNK_SIZE)) {
    const result = await tool("query_property_values", {
      propertyKeys: Object.fromEntries(group.map((id) => [id, TRANSFORM_PROPERTY_KEYS])),
    });
    Object.assign(values, result.values ?? {});
  }
  return values;
}

async function verifyRigGeometry(artboardId, expectedIdsByName) {
  const hierarchy = await getHierarchy(artboardId);
  const objects = hierarchy.objects ?? [];
  const shapeObjects = objects.filter((object) => object.types?.includes("Shape"));
  const actualIdsByName = new Map();
  for (const node of NODES) {
    const object = uniqueByName(shapeObjects, node.name, "Rig verification");
    actualIdsByName.set(node.name, object.id);
    assert(
      expectedIdsByName.get(node.name) === object.id,
      `${node.name}: created ID ${expectedIdsByName.get(node.name)} changed to ${object.id}`,
    );
  }

  const parents = parentMap(objects);
  for (const node of NODES) {
    const id = actualIdsByName.get(node.name);
    const expectedParentId = node.parent === null ? artboardId : actualIdsByName.get(node.parent);
    assert(
      parents.get(id) === expectedParentId,
      `${node.name}: expected parent ${expectedParentId}, found ${parents.get(id) ?? "none"}`,
    );
  }

  const forbidden = objects.filter((object) =>
    (object.types ?? []).some((type) =>
      ["Image", "ImageAsset", "ImageInstance", "NestedArtboard", "ArtboardInstance"].includes(type),
    ),
  );
  assert(forbidden.length === 0, `Rig unexpectedly contains raster/nested objects: ${forbidden.map((object) => object.name).join(", ")}`);

  const pivotIds = PIVOTS.map((pivot) => actualIdsByName.get(pivot.name));
  for (const group of chunks(pivotIds, PROPERTY_CHUNK_SIZE)) {
    const schema = await tool("query_property_keys", { objectIds: group, animates: true });
    assertPropertySchema(schema, group, TRANSFORM_PROPERTY_KEYS, "Animatable pivot schema");
  }

  const values = await queryTransformValues([...actualIdsByName.values()]);
  for (const node of NODES) {
    const id = actualIdsByName.get(node.name);
    const expected = expectedBaseTransform(node);
    for (const key of TRANSFORM_PROPERTY_KEYS) {
      const actual = values[id]?.[key];
      assert(
        closeEnough(actual, expected[key]),
        `${node.name}: base property ${key} expected ${expected[key]}, found ${actual}`,
      );
    }
  }

  return {
    hierarchy,
    idsByName: actualIdsByName,
    nodeCount: NODES.length,
    pivotCount: PIVOTS.length,
    partCount: PARTS.length,
    forbiddenObjectCount: forbidden.length,
    baseTransformsVerified: true,
    parentsVerified: true,
  };
}

function absoluteKeyframeValue(pivotName, property, authoredValue) {
  const base = BASE_BY_NAME[pivotName];
  switch (property) {
    case "dx":
      return base.x + authoredValue;
    case "dy":
      return base.y + authoredValue;
    case "rotationDeg":
      return base.rotation + (authoredValue * Math.PI) / 180;
    case "scaleX":
    case "scaleY":
    case "opacity":
      return authoredValue;
    default:
      throw new Error(`Unsupported authored property ${property}`);
  }
}

function riveKeyframesForSpec(spec, idsByName) {
  const keyframes = [];
  for (const [pivotName, properties] of Object.entries(spec.tracks)) {
    const objectId = idsByName.get(pivotName);
    assert(objectId, `${spec.name}: missing Rive ID for ${pivotName}`);
    for (const [property, keys] of Object.entries(properties)) {
      const propertyKey = PROPERTY[property];
      for (const [frame, authoredValue] of keys) {
        keyframes.push({
          objectId,
          propertyKey,
          frame,
          value: absoluteKeyframeValue(pivotName, property, authoredValue),
          interpolationType: "cubic",
          cubicParams: { x1: 0.42, y1: 0, x2: 0.58, y2: 1 },
        });
      }
    }
  }
  return keyframes;
}

function verifyReportedDuration(animation, spec) {
  const reported = animation.durationSeconds ?? animation.duration;
  if (reported === undefined || reported === null) return;
  const numeric = Number(reported);
  assert(Number.isFinite(numeric), `${spec.name}: Rive returned invalid duration ${reported}`);
  const isSeconds = closeEnough(numeric, spec.durationSeconds, 1e-3);
  const isFrames = closeEnough(numeric, terminalFrame(spec), 1e-3);
  assert(isSeconds || isFrames, `${spec.name}: duration expected ${spec.durationSeconds}s/${terminalFrame(spec)}f, found ${reported}`);
}

async function configureAndVerifyAnimationSettings(artboardId, animationBySlug) {
  const entries = PERFORMANCE_SPECS.map((spec) => ({
    spec,
    animation: animationBySlug.get(spec.slug),
  }));
  const animationIds = entries.map(({ animation }) => animation.id);
  const schema = await tool("query_property_keys", {
    objectIds: animationIds,
  });
  assertPropertySchema(
    schema,
    animationIds,
    Object.values(ANIMATION_PROPERTY),
    "LinearAnimation schema",
  );

  await focusLock(artboardId);
  await tool("set_property_values", {
    propertyValues: Object.fromEntries(entries.map(({ spec, animation }) => [
      animation.id,
      {
        [ANIMATION_PROPERTY.fps]: FPS,
        [ANIMATION_PROPERTY.durationFrames]: terminalFrame(spec),
        [ANIMATION_PROPERTY.loopValue]: spec.loop ? 1 : 0,
      },
    ])),
  });

  const queried = await tool("query_property_values", {
    propertyKeys: Object.fromEntries(animationIds.map((id) => [
      id,
      Object.values(ANIMATION_PROPERTY),
    ])),
  });
  const settings = [];
  for (const { spec, animation } of entries) {
    const values = queried.values?.[animation.id] ?? {};
    const expected = {
      fps: FPS,
      durationFrames: terminalFrame(spec),
      loopValue: spec.loop ? 1 : 0,
    };
    for (const [name, value] of Object.entries(expected)) {
      const key = ANIMATION_PROPERTY[name];
      assert(
        Number(values[key]) === value,
        `${spec.slug}: animation ${name} expected ${value}, found ${values[key]}`,
      );
    }
    settings.push({
      slug: spec.slug,
      animationId: animation.id,
      ...expected,
    });
  }
  return settings;
}

async function createAnimations(artboardId, idsByName) {
  await focusLock(artboardId);
  await tool("animation_editor", {
    command: "createLinearAnimations",
    data: {
      createLinearAnimations: {
        linearAnimations: PERFORMANCE_SPECS.map((spec) => ({
          name: spec.slug,
          duration: spec.durationSeconds,
        })),
      },
    },
  });

  await focusLock(artboardId);
  const list = await tool("animation_editor", {
    command: "listLinearAnimations",
    data: { listLinearAnimations: {} },
  });
  const animations = list.linearAnimations ?? [];
  const animationBySlug = new Map();
  for (const spec of PERFORMANCE_SPECS) {
    const animation = uniqueByName(animations, spec.slug, "Animation creation");
    assert(animation.id && animation.id !== "0-0", `${spec.slug}: missing or stale animation ID ${animation.id ?? "none"}`);
    verifyReportedDuration(animation, spec);
    animationBySlug.set(spec.slug, animation);
  }

  const settings = await configureAndVerifyAnimationSettings(artboardId, animationBySlug);
  const settingsBySlug = new Map(settings.map((entry) => [entry.slug, entry]));

  const expectedByAnimationId = new Map();
  for (const spec of PERFORMANCE_SPECS) {
    const animation = animationBySlug.get(spec.slug);
    const keyframes = riveKeyframesForSpec(spec, idsByName);
    expectedByAnimationId.set(animation.id, { spec, keyframes });
    for (const group of chunks(keyframes, KEYFRAME_CHUNK_SIZE)) {
      await focusLock(artboardId);
      await tool("animation_editor", {
        command: "modifyKeyFrames",
        data: { modifyKeyFrames: { animationId: animation.id, add: group } },
      });
    }
  }

  await focusLock(artboardId);
  const query = await tool("animation_editor", {
    command: "queryKeyFrames",
    data: {
      queryKeyFrames: {
        animationIds: [...animationBySlug.values()].map((animation) => animation.id),
      },
    },
  });

  const verification = [];
  for (const [animationId, expectedEntry] of expectedByAnimationId) {
    const { spec, keyframes: expected } = expectedEntry;
    const actual = query.keyframes?.[animationId] ?? [];
    assert(
      actual.length === expected.length,
      `${spec.name}: expected ${expected.length} keyframes, found ${actual.length}`,
    );

    const actualByTuple = new Map();
    for (const keyframe of actual) {
      const tuple = `${keyframe.objectId}/${Number(keyframe.propertyKey)}/${Number(keyframe.frame)}`;
      assert(!actualByTuple.has(tuple), `${spec.name}: duplicate queried keyframe tuple ${tuple}`);
      actualByTuple.set(tuple, keyframe);
    }
    for (const keyframe of expected) {
      const tuple = `${keyframe.objectId}/${keyframe.propertyKey}/${keyframe.frame}`;
      const found = actualByTuple.get(tuple);
      assert(found, `${spec.name}: missing queried keyframe ${tuple}`);
      assert(
        closeEnough(found.value, keyframe.value, 1e-4),
        `${spec.name}: ${tuple} expected value ${keyframe.value}, found ${found.value}`,
      );
    }

    const terminal = terminalFrame(spec);
    let trackCount = 0;
    const loopErrors = [];
    for (const [pivotName, properties] of Object.entries(spec.tracks)) {
      const objectId = idsByName.get(pivotName);
      for (const [property, keys] of Object.entries(properties)) {
        trackCount += 1;
        const propertyKey = PROPERTY[property];
        const queriedTrack = actual
          .filter((keyframe) => keyframe.objectId === objectId && Number(keyframe.propertyKey) === propertyKey)
          .sort((left, right) => Number(left.frame) - Number(right.frame));
        const first = queriedTrack.find((keyframe) => Number(keyframe.frame) === 0);
        const last = queriedTrack.find((keyframe) => Number(keyframe.frame) === terminal);
        assert(first && last, `${spec.name}/${pivotName}/${property}: queried track lacks an endpoint`);
        if (spec.loop && !closeEnough(first.value, last.value, 1e-4)) {
          loopErrors.push(`${pivotName}/${property}`);
        }
        assert(keys[0][0] === 0 && keys.at(-1)[0] === terminal, `${spec.name}/${pivotName}/${property}: authored endpoints regressed`);
      }
    }
    assert(loopErrors.length === 0, `${spec.name}: loop endpoint mismatch on ${loopErrors.join(", ")}`);
    verification.push({
      slug: spec.slug,
      name: spec.slug,
      displayName: spec.name,
      animationId,
      durationSeconds: spec.durationSeconds,
      terminalFrame: terminal,
      loop: spec.loop,
      nativeSettings: settingsBySlug.get(spec.slug),
      trackCount,
      expectedKeyframeCount: expected.length,
      queriedKeyframeCount: actual.length,
      endpointsVerified: true,
      loopEndpointsMatch: spec.loop ? true : null,
    });
  }

  return { animationBySlug, keyframeQuery: query, settings, verification };
}

function stateNameForSpec(spec) {
  const identity = `${spec.slug} ${spec.name}`.toLowerCase();
  if (identity.includes("welcome_back") || identity.includes("welcome back") || identity.includes("return")) return "Welcome Back";
  if (identity.includes("idle")) return "Idle";
  if (identity.includes("welcome")) return "Welcome";
  if (identity.includes("add_expense") || identity.includes("add expense") || identity.includes("diary")) return "Add Expense";
  if (identity.includes("split")) return "Split Bill";
  if (identity.includes("settled") || identity.includes("joy_jump") || identity.includes("joy jump")) return "Bills Settled";
  if (identity.includes("payment_error") || identity.includes("payment error") || identity.includes("catch") || identity.includes("recovery")) return "Payment Error";
  throw new Error(`Cannot derive a state name for performance ${spec.slug}/${spec.name}`);
}

function stateDefinitions() {
  const definitions = PERFORMANCE_SPECS.map((spec, index) => ({
    stateName: stateNameForSpec(spec),
    animationName: spec.slug,
    x: 140 + (index % 3) * 250,
    y: 120 + Math.floor(index / 3) * 150,
  }));
  assert(new Set(definitions.map((definition) => definition.stateName)).size === 7, "Derived state names are not unique");
  assert(definitions.some((definition) => definition.stateName === "Idle"), "Performance set has no Idle state");
  return definitions;
}

async function createAndVerifyStateMachine(artboardId, animationBySlug) {
  const definitions = stateDefinitions();
  await focusLock(artboardId);
  await tool("animation_editor", {
    command: "createStateMachine",
    data: {
      createStateMachine: {
        name: STATE_MACHINE_NAME,
        layers: [{
          name: STATE_LAYER_NAME,
          states: definitions.map((definition) => ({
            name: definition.stateName,
            x: definition.x,
            y: definition.y,
            linearAnimationName: definition.animationName,
          })),
          otherTransitions: [{ from: "{Entry State}", to: "Idle" }],
        }],
      },
    },
  });

  await focusLock(artboardId);
  const list = await tool("animation_editor", {
    command: "listStateMachines",
    data: { listStateMachines: {} },
  });
  const stateMachine = uniqueByName(list.stateMachines ?? [], STATE_MACHINE_NAME, "State-machine creation");
  assert(
    stateMachine.id && stateMachine.id !== "0-0",
    `${STATE_MACHINE_NAME}: missing or stale state-machine ID ${stateMachine.id ?? "none"}`,
  );

  let detail = await tool("animation_editor", {
    command: "queryStateMachine",
    data: { queryStateMachine: { stateMachineId: stateMachine.id } },
  });
  const normalizeLayer = (layer) => ({ ...layer, name: layer.layerName ?? layer.name });
  const normalizeState = (state) => ({ ...state, name: state.stateName ?? state.name });
  const behaviorLayers = (detail.layers ?? []).map(normalizeLayer).filter((layer) => layer.name === STATE_LAYER_NAME);
  assert(behaviorLayers.length === 1, `Expected one ${STATE_LAYER_NAME} layer, found ${behaviorLayers.length}`);
  let behavior = behaviorLayers[0];
  const expectedStateNames = new Set(definitions.map((definition) => definition.stateName));
  const namedStates = (behavior.states ?? []).map(normalizeState).filter((state) => state.name);
  assert(namedStates.length === definitions.length, `Behavior layer expected seven named states, found ${namedStates.length}`);
  for (const state of namedStates) {
    assert(expectedStateNames.has(state.name), `Unexpected named state ${state.name}`);
  }

  const definitionByState = new Map(definitions.map((definition) => [definition.stateName, definition]));
  const updates = namedStates.map((state) => ({
    id: state.id,
    animationId: animationBySlug.get(definitionByState.get(state.name).animationName).id,
  }));
  await focusLock(artboardId);
  await tool("animation_editor", {
    command: "updateStates",
    data: { updateStates: { states: updates } },
  });

  await focusLock(artboardId);
  detail = await tool("animation_editor", {
    command: "queryStateMachine",
    data: { queryStateMachine: { stateMachineId: stateMachine.id } },
  });
  behavior = uniqueByName((detail.layers ?? []).map(normalizeLayer), STATE_LAYER_NAME, "State-machine verification");
  const normalizedStates = (behavior.states ?? []).map(normalizeState);
  const stateByName = new Map(normalizedStates.filter((state) => state.name).map((state) => [state.name, state]));
  for (const definition of definitions) {
    const state = stateByName.get(definition.stateName);
    assert(state, `Missing state ${definition.stateName}`);
    const expectedAnimation = animationBySlug.get(definition.animationName);
    assert(
      state.animationId === expectedAnimation.id,
      `${definition.stateName}: expected animation ${expectedAnimation.id}, found ${state.animationId ?? "none"}`,
    );
  }

  const transitions = behavior.transitions ?? [];
  assert(transitions.length === 1, `Behavior layer expected one Entry transition, found ${transitions.length}`);
  const transition = transitions[0];
  const idleState = stateByName.get("Idle");
  assert(transition.toStateId === idleState.id, `Entry transition does not target Idle (${idleState.id})`);
  const fromState = normalizedStates.find((state) => state.id === transition.fromStateId);
  assert(fromState && !fromState.name, "The only Behavior transition does not originate at the built-in Entry state");
  assert(!transition.isDisabled, "Entry → Idle transition is disabled");

  return {
    stateMachine: { id: stateMachine.id, name: stateMachine.name },
    detail,
    behaviorLayerId: behavior.id,
    states: definitions.map((definition) => {
      const state = stateByName.get(definition.stateName);
      return {
        id: state.id,
        name: state.name,
        animationId: state.animationId,
        animationName: definition.animationName,
      };
    }),
    transition: {
      id: transition.id,
      fromStateId: transition.fromStateId,
      toStateId: transition.toStateId,
      toStateName: "Idle",
    },
    mappingsVerified: true,
    entryToIdleOnly: true,
    automatedBehaviorInputs: false,
    invocation: "Play the six non-idle behaviors by their exact linear-animation names; generic state-machine inputs are not created by this safe build.",
  };
}

async function assertBuildNamesFree() {
  const listed = await tool("list_artboards", {});
  const finals = (listed.artboards ?? []).filter((artboard) => artboard.name === FINAL_ARTBOARD_NAME);
  const temporaries = (listed.artboards ?? []).filter((artboard) => artboard.name === TEMP_ARTBOARD_NAME);
  if (finals.length) {
    throw new Error(`Refusing to overwrite existing final artboard ${FINAL_ARTBOARD_NAME} (${finals.map((item) => item.id).join(", ")})`);
  }
  if (temporaries.length) {
    throw new Error(`Refusing to overwrite or resume existing temporary artboard ${TEMP_ARTBOARD_NAME} (${temporaries.map((item) => item.id).join(", ")})`);
  }
}

async function createTemporaryArtboard() {
  const result = await tool("open_file_editor", {
    command: "createArtboard",
    data: {
      createArtboard: [{
        name: TEMP_ARTBOARD_NAME,
        x: ARTBOARD_X,
        y: ARTBOARD_Y,
        width: CANVAS,
        height: CANVAS,
        isComponent: true,
      }],
    },
  });
  const created = result.artboards ?? result.createdArtboards ?? result.objects ?? [];
  const artboard = uniqueByName(created, TEMP_ARTBOARD_NAME, "Artboard creation");
  assert(
    artboard.id && artboard.id !== "0-0",
    `Rive did not return a usable temporary artboard ID (${artboard.id ?? "none"})`,
  );
  return artboard;
}

async function removeAutoCreatedDefaults(artboardId) {
  await focusLock(artboardId);
  const animations = await tool("animation_editor", {
    command: "listLinearAnimations",
    data: { listLinearAnimations: {} },
  });
  const stateMachines = await tool("animation_editor", {
    command: "listStateMachines",
    data: { listStateMachines: {} },
  });
  const ownedDefaults = [
    ...(animations.linearAnimations ?? []).filter((item) => item.name === "Timeline 1"),
    ...(stateMachines.stateMachines ?? []).filter((item) => item.name === "State Machine 1"),
  ];
  if (ownedDefaults.length) {
    await tool("delete_objects", { objectIds: ownedDefaults.map((item) => item.id) });
  }
  return ownedDefaults.map((item) => ({ id: item.id, name: item.name }));
}

async function publishArtboard(artboardId) {
  const before = await tool("list_artboards", {});
  const finals = (before.artboards ?? []).filter((artboard) => artboard.name === FINAL_ARTBOARD_NAME);
  const temporaries = (before.artboards ?? []).filter((artboard) => artboard.name === TEMP_ARTBOARD_NAME);
  assert(finals.length === 0, `Cannot publish: ${FINAL_ARTBOARD_NAME} appeared during the build`);
  assert(temporaries.length === 1 && temporaries[0].id === artboardId, "Cannot publish: temporary artboard identity changed");

  await tool("open_file_editor", {
    command: "renameArtboard",
    data: {
      renameArtboard: [{ artboardId, newName: FINAL_ARTBOARD_NAME }],
    },
  });
  const after = await tool("list_artboards", {});
  const published = (after.artboards ?? []).filter((artboard) => artboard.name === FINAL_ARTBOARD_NAME);
  const staleTemporary = (after.artboards ?? []).filter((artboard) => artboard.name === TEMP_ARTBOARD_NAME);
  assert(published.length === 1 && published[0].id === artboardId, "Final artboard rename did not verify");
  assert(staleTemporary.length === 0, "Temporary artboard name remained after publication");
  return published[0];
}

async function build() {
  validateSourceSpecs();
  await initialize();
  await assertBuildNamesFree();

  const temporaryArtboard = await createTemporaryArtboard();
  await focusLock(temporaryArtboard.id);
  const artboardSolidColorId = await setArtboardFillColor(temporaryArtboard.id);
  const removedAutoDefaults = await removeAutoCreatedDefaults(temporaryArtboard.id);

  const createdIdsByName = await createRigGeometry(temporaryArtboard.id);
  const geometry = await verifyRigGeometry(temporaryArtboard.id, createdIdsByName);
  const animations = await createAnimations(temporaryArtboard.id, geometry.idsByName);
  const stateMachine = await createAndVerifyStateMachine(
    temporaryArtboard.id,
    animations.animationBySlug,
  );

  await focusLock(temporaryArtboard.id);
  const finalGeometry = await verifyRigGeometry(temporaryArtboard.id, geometry.idsByName);
  await focusLock(temporaryArtboard.id);
  const selectedBeforePublish = await tool("open_file_editor", {
    command: "getSelectedArtboard",
    data: { getSelectedArtboard: {} },
  });
  assert(selectedBeforePublish.artboard?.id === temporaryArtboard.id, "Final focus verification failed before publish");

  const published = await publishArtboard(temporaryArtboard.id);
  await focusLock(published.id);

  const summary = {
    status: "created-and-verified",
    generatedAt: new Date().toISOString(),
    artboard: {
      id: published.id,
      name: published.name,
      width: CANVAS,
      height: CANVAS,
      x: ARTBOARD_X,
      y: ARTBOARD_Y,
      isComponent: true,
      solidColorId: artboardSolidColorId,
    },
    palette: {
      cobalt: COLORS.cobalt,
      cream: COLORS.cream,
      riveCobalt: RIVE_COLORS.cobalt,
      riveCream: RIVE_COLORS.cream,
    },
    fps: FPS,
    rig: {
      nodeCount: finalGeometry.nodeCount,
      pivotCount: finalGeometry.pivotCount,
      partCount: finalGeometry.partCount,
      pivots: PIVOTS.map((pivot) => ({
        name: pivot.name,
        id: finalGeometry.idsByName.get(pivot.name),
        parent: pivot.parent,
      })),
      parts: PARTS.map((part) => ({
        name: part.name,
        id: finalGeometry.idsByName.get(part.name),
        parent: part.parent,
      })),
    },
    bindPose: PIVOTS.map((pivot) => {
      const base = BASE_BY_NAME[pivot.name];
      return {
        name: pivot.name,
        id: finalGeometry.idsByName.get(pivot.name),
        transform: {
          x: base.x,
          y: base.y,
          rotation: base.rotation,
          scaleX: base.scaleX,
          scaleY: base.scaleY,
          opacity: base.opacity,
        },
      };
    }),
    animations: animations.verification,
    stateMachine,
    verification: {
      sourceSpecsValidated: true,
      hierarchyNamesUnique: true,
      hierarchyParentsCorrect: finalGeometry.parentsVerified,
      baseTransformsMatch: finalGeometry.baseTransformsVerified,
      forbiddenRasterOrNestedObjectCount: finalGeometry.forbiddenObjectCount,
      artboardFillColor: COLORS.cobalt,
      requiredAnimationCount: animations.verification.length,
      allKeyframeTuplesMatch: animations.verification.every(
        (entry) => entry.expectedKeyframeCount === entry.queriedKeyframeCount,
      ),
      allTracksHaveEndpoints: animations.verification.every((entry) => entry.endpointsVerified),
      allLoopEndpointsMatch: animations.verification
        .filter((entry) => entry.loop)
        .every((entry) => entry.loopEndpointsMatch),
      allNativeAnimationSettingsMatch: animations.verification.every(
        (entry) =>
          entry.nativeSettings.fps === FPS &&
          entry.nativeSettings.durationFrames === entry.terminalFrame &&
          entry.nativeSettings.loopValue === (entry.loop ? 1 : 0),
      ),
      stateMappingsMatch: stateMachine.mappingsVerified,
      entryToIdleOnly: stateMachine.entryToIdleOnly,
      removedAutoGeneratedDefaults: removedAutoDefaults,
      finalNamePublishedOnlyAfterValidation: true,
      finalFocusLocked: true,
    },
  };

  writeFileSync(SUMMARY_PATH, `${JSON.stringify(summary, null, 2)}\n`);
  console.log(JSON.stringify(summary, null, 2));
}

await build();
