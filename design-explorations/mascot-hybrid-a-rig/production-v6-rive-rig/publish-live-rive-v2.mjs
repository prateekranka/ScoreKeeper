#!/usr/bin/env node

const URL = process.env.RIVE_MCP_URL ?? 'http://127.0.0.1:9791/mcp';
const MAIN_ID = '0-16469';
const TEMP_MAIN_NAME = '__BUILDING__ ScoreKeeper Cup Hybrid A - Production Rig v2 20260715T1449IST';
const FINAL_MAIN_NAME = 'ScoreKeeper Cup Hybrid A - Production Rig v2';
const HAIR_ID = '0-17790';
const TEMP_HAIR_NAME = '__COMPONENT__ ScoreKeeper Hair v2 20260715T1510IST';
const FINAL_HAIR_NAME = 'ScoreKeeper Cup Hair Component v2';
const PROTECTED = { '0-2': 3946, '0-3956': 4092 };
let id = 1;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function request(payload) {
  const response = await fetch(URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' },
    body: JSON.stringify(payload),
  });
  if (response.status === 202) return {};
  const body = await response.json();
  if (body.error) throw new Error(body.error.message);
  return body;
}

async function rpc(method, params = {}) {
  return (await request({ jsonrpc: '2.0', id: id++, method, params })).result;
}

async function tool(name, args = {}) {
  const result = await rpc('tools/call', { name, arguments: args });
  const payload = result?.content?.find((item) => item.type === 'text')?.text;
  let parsed = result;
  if (payload) {
    try { parsed = JSON.parse(payload); } catch { parsed = payload; }
  }
  if (parsed?.success === false || parsed?.errors?.length) throw new Error(`${name}: ${JSON.stringify(parsed)}`);
  return parsed;
}

async function main() {
  await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'scorekeeper-v2-publisher', version: '1' } });
  await request({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });

  const before = await tool('list_artboards', {});
  const byId = new Map((before.artboards ?? []).map((artboard) => [artboard.id, artboard]));
  assert(byId.get(MAIN_ID)?.name === TEMP_MAIN_NAME, `Main artboard identity mismatch: ${byId.get(MAIN_ID)?.name}`);
  assert(byId.get(HAIR_ID)?.name === TEMP_HAIR_NAME, `Hair artboard identity mismatch: ${byId.get(HAIR_ID)?.name}`);
  assert(!(before.artboards ?? []).some((artboard) => artboard.id !== MAIN_ID && artboard.name === FINAL_MAIN_NAME), `Final main name already exists: ${FINAL_MAIN_NAME}`);
  assert(!(before.artboards ?? []).some((artboard) => artboard.id !== HAIR_ID && artboard.name === FINAL_HAIR_NAME), `Final hair name already exists: ${FINAL_HAIR_NAME}`);

  for (const [artboardId, expectedCount] of Object.entries(PROTECTED)) {
    const hierarchy = await tool('get_artboard_hierarchy', { artboardId, depth: 8 });
    assert((hierarchy.objects?.length ?? 0) === expectedCount, `Protected artboard ${artboardId} changed before publish`);
  }

  await tool('open_file_editor', {
    command: 'renameArtboard',
    data: { renameArtboard: [
      { artboardId: MAIN_ID, newName: FINAL_MAIN_NAME },
      { artboardId: HAIR_ID, newName: FINAL_HAIR_NAME },
    ] },
  });
  await tool('open_file_editor', { command: 'focusArtboard', data: { focusArtboard: { artboardId: MAIN_ID, fitToViewport: true } } });

  const after = await tool('list_artboards', {});
  const afterById = new Map((after.artboards ?? []).map((artboard) => [artboard.id, artboard]));
  assert(afterById.get(MAIN_ID)?.name === FINAL_MAIN_NAME, 'Main artboard publish rename did not persist');
  assert(afterById.get(HAIR_ID)?.name === FINAL_HAIR_NAME, 'Hair component publish rename did not persist');
  const selected = await tool('open_file_editor', { command: 'getSelectedArtboard', data: { getSelectedArtboard: {} } });
  assert(selected.artboard?.id === MAIN_ID, `Published artboard is not selected: ${selected.artboard?.id}`);

  const protectedCounts = {};
  for (const [artboardId, expectedCount] of Object.entries(PROTECTED)) {
    const hierarchy = await tool('get_artboard_hierarchy', { artboardId, depth: 8 });
    protectedCounts[artboardId] = hierarchy.objects?.length ?? 0;
    assert(protectedCounts[artboardId] === expectedCount, `Protected artboard ${artboardId} changed after publish`);
  }

  process.stdout.write(`${JSON.stringify({
    status: 'published',
    main: { id: MAIN_ID, name: FINAL_MAIN_NAME },
    hairComponent: { id: HAIR_ID, name: FINAL_HAIR_NAME },
    selectedArtboardId: selected.artboard.id,
    protectedCounts,
  }, null, 2)}\n`);
}

main().catch((error) => {
  console.error(error.stack ?? String(error));
  process.exitCode = 1;
});
