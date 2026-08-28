#!/usr/bin/env node
// rive-bridge.mjs — drive rive-mcp (stdio JSON-RPC) from the terminal.
// Usage:
//   node rive-bridge.mjs list
//   node rive-bridge.mjs <tool> '<json args>'
// Images in tool results are auto-saved to ./bridge-out/<tool>-<n>.png
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';

const serverCmd = process.env.RIVE_MCP_CMD || 'rive-mcp';
const tool = process.argv[2];
const args = process.argv[3] ? JSON.parse(process.argv[3]) : {};

const child = spawn(serverCmd, [], { stdio: ['pipe', 'pipe', 'inherit'] });
let buf = '';
const pending = new Map();
let nextId = 1;

child.stdout.on('data', (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});

function send(msg) {
  return new Promise((resolve) => {
    const id = nextId++;
    pending.set(id, resolve);
    child.stdin.write(JSON.stringify({ ...msg, id }) + '\n');
  });
}

await send({ jsonrpc: '2.0', method: 'initialize', params: {
  protocolVersion: '2024-11-05',
  capabilities: {},
  clientInfo: { name: 'rive-bridge', version: '1.0.0' }
}});
child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} }) + '\n');

if (tool === 'list') {
  const res = await send({ jsonrpc: '2.0', method: 'tools/list', params: {} });
  for (const t of res.result.tools) {
    console.log(`### ${t.name}`);
    console.log((t.description || '').slice(0, 300));
    if (t.inputSchema && t.inputSchema.properties) {
      console.log('  args:', Object.keys(t.inputSchema.properties).join(', '));
    }
    console.log('');
  }
} else if (tool === 'schema') {
  const res = await send({ jsonrpc: '2.0', method: 'tools/list', params: {} });
  const t = res.result.tools.find((x) => x.name === args.name);
  console.log(JSON.stringify(t?.inputSchema ?? { error: 'tool not found' }, null, 2));
} else {
  const res = await send({ jsonrpc: '2.0', method: 'tools/call', params: { name: tool, arguments: args } });
  const r = res.result;
  if (r.isError) {
    console.error('TOOL ERROR:', JSON.stringify(r, null, 2));
    process.exitCode = 1;
  } else {
    mkdirSync('bridge-out', { recursive: true });
    let imgIdx = 0;
    for (const c of r.content || []) {
      if (c.type === 'text') console.log(c.text);
      else if (c.type === 'image') {
        imgIdx++;
        const m = c.data?.match(/^data:(image\/\w+);base64,(.+)$/s);
        const b64 = m ? m[2] : c.data;
        const ext = m ? m[1].split('/')[1].replace('jpeg', 'jpg') : 'png';
        const p = `bridge-out/${tool}-${imgIdx}.${ext}`;
        writeFileSync(p, Buffer.from(b64, 'base64'));
        console.log(`[image saved: ${p}]`);
      }
    }
  }
}
child.kill();
