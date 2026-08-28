import { spawn } from 'node:child_process';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const root = path.dirname(new URL(import.meta.url).pathname);
const htmlPath = path.join(root, 'scoring-picker.html');
const outDir = path.join(root, 'screenshots');
const profileDir = '/tmp/pipcount-prototype-chromium';
const port = 9224;
await rm(profileDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });
const chrome = spawn('/usr/bin/chromium', [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  '--remote-allow-origins=*',
  `--user-data-dir=${profileDir}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-gpu',
  '--hide-scrollbars',
  'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });
let chromeError = '';
chrome.stderr.on('data', chunk => { chromeError += chunk.toString(); });

async function retry(fn, attempts = 50) {
  let last;
  for (let index = 0; index < attempts; index += 1) {
    try { return await fn(); } catch (error) { last = error; await new Promise(resolve => setTimeout(resolve, 100)); }
  }
  throw last;
}

try {
  const pages = await retry(async () => {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`);
    if (!response.ok) throw new Error(`CDP HTTP ${response.status}`);
    const data = await response.json();
    if (!data[0]?.webSocketDebuggerUrl) throw new Error('No CDP page target');
    return data;
  });
  const pageTarget = pages.find(page => page.type === 'page' && page.url === 'about:blank')
    || pages.find(page => page.type === 'page');
  if (!pageTarget?.webSocketDebuggerUrl) throw new Error('No page target in CDP list');
  const socket = new WebSocket(pageTarget.webSocketDebuggerUrl);

  await Promise.race([
    new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve, { once: true });
      socket.addEventListener('error', reject, { once: true });
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error('CDP WebSocket open timeout')), 5000)),
  ]);

  let id = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message)); else resolve(message.result);
    }
  });
  function send(method, params = {}) {
    const callId = ++id;
    return new Promise((resolve, reject) => {
      pending.set(callId, { resolve, reject });
      socket.send(JSON.stringify({ id: callId, method, params }));
    });
  }

  async function evaluate(expression) {
    const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || 'Runtime exception');
    return result.result.value;
  }
  async function navigate(variant) {

    const url = pathToFileURL(htmlPath);
    url.searchParams.set('v', String(variant));
    await send('Page.navigate', { url: url.href });
    await retry(async () => {
      const state = await evaluate(`document.readyState`);
      if (state !== 'complete') throw new Error(`document state ${state}`);
      return state;
    });

    await retry(async () => {
      const ready = await evaluate(`Boolean(document.querySelector('.phone') && document.querySelector('[data-submit]'))`);
      if (!ready) throw new Error('prototype not mounted');
      return ready;
    });
  }
  async function screenshot(name) {
    const result = await send('Page.captureScreenshot', { format: 'png', fromSurface: true });
    await writeFile(path.join(outDir, name), Buffer.from(result.data, 'base64'));
  }

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 560, height: 1000, deviceScaleFactor: 1, mobile: false });

  const reports = [];
  for (let variant = 1; variant <= 3; variant += 1) {
    await navigate(variant);
    await new Promise(resolve => setTimeout(resolve, 450));
    const title = await evaluate(`document.querySelector('.proto-picker-item[data-active]').textContent.trim()`);
    await screenshot(`0${variant}-${title.toLowerCase().replaceAll(' ', '-')}.png`);
    const before = await evaluate(`document.querySelector('[data-round]').textContent.trim()`);
    await evaluate(`document.querySelector('.step.plus').click()`);
    const after = await evaluate(`document.querySelector('[data-round]').textContent.trim()`);
    if (before === after) throw new Error(`${title}: score did not change after plus`);
    await evaluate(`document.querySelector('[data-submit]').click()`);
    const saved = await evaluate(`document.querySelector('[data-submit]').textContent.includes('saved') || document.querySelector('[data-submit]').textContent.includes('Stamp')`);
    if (!saved) throw new Error(`${title}: submit feedback missing`);
    reports.push({ variant, title, before, after, submitFeedback: saved });
  }
  console.log(JSON.stringify({ ok: true, reports, screenshots: outDir }, null, 2));
  socket.close();
} catch (error) {
  console.error(error.stack || String(error));
  if (chromeError) console.error(chromeError.slice(-2000));
  process.exitCode = 1;
} finally {
  chrome.kill('SIGTERM');
  chrome.unref();
}
