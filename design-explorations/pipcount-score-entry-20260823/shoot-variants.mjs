// Screenshot each variant of the score-entry picker via CDP (no deps, native WebSocket).
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const FILE = resolve(process.argv[2] || 'score-entry-picker.html');
const OUT = resolve(process.argv[3] || 'screenshots');
const URL = 'file://' + FILE;
const port = 9231;
const profileDir = '/tmp/pipcount-entry-chromium';
rmSync(profileDir, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const chrome = spawn('/usr/bin/chromium', [
  '--headless=new', `--remote-debugging-port=${port}`, '--remote-allow-origins=*',
  `--user-data-dir=${profileDir}`, '--no-first-run', '--no-default-browser-check',
  '--disable-gpu', '--hide-scrollbars', '--window-size=520,1000', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

const sleep = ms => new Promise(r => setTimeout(r, ms));
async function retry(fn, attempts = 50) {
  let last;
  for (let i = 0; i < attempts; i++) {
    try { return await fn(); } catch (e) { last = e; await sleep(100); }
  }
  throw last;
}

try {
  const pages = await retry(async () => {
    const r = await fetch(`http://127.0.0.1:${port}/json/list`);
    if (!r.ok) throw new Error(`CDP HTTP ${r.status}`);
    return r.json();
  });
  const target = pages.find(p => p.type === 'page' && p.url === 'about:blank') || pages.find(p => p.type === 'page');
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  ws.binaryType = 'arraybuffer';
  await new Promise((res, rej) => {
    ws.addEventListener('open', res);
    setTimeout(() => rej(new Error('ws open timeout')), 5000);
  });

  let id = 0; const pending = new Map();
  ws.addEventListener('message', ev => {
    const m = JSON.parse(typeof ev.data === 'string' ? ev.data : ev.data.toString());
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  });
  function send(method, params = {}) {
    return new Promise(res => { const mid = ++id; pending.set(mid, res); ws.send(JSON.stringify({ id: mid, method, params })); });
  }

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 520, height: 1040, deviceScaleFactor: 2, mobile: true });
  await send('Page.navigate', { url: URL });
  await sleep(900);

  function check(r) { if (r.error || r.result?.exceptionDetails) throw new Error(JSON.stringify(r.error || r.result.exceptionDetails).slice(0, 300)); return r.result?.result?.value; }

  for (let v = 1; v <= 3; v++) {
    check(await send('Runtime.evaluate', { expression: `typeof setActive==='function'?setActive(${v - 1}):null`, returnByValue: true }));
    await sleep(700);
    check(await send('Runtime.evaluate', { expression: `(() => {
      const cv=document.querySelector('.ledger-row canvas');
      if(!cv)return 'nocanvas';
      const ctx=cv.getContext('2d');
      ctx.lineWidth=7;ctx.lineCap='round';ctx.strokeStyle='#171712';
      ctx.beginPath();ctx.moveTo(30,50);ctx.lineTo(45,20);ctx.lineTo(60,55);ctx.stroke();
      ctx.beginPath();ctx.moveTo(90,25);ctx.lineTo(120,50);ctx.stroke();
      const h=cv.closest('.ledger-row,.pad-card')?.querySelector('.canvas-hint');h&&h.classList.add('hidden');
      return 'ok';
    })()`, returnByValue: true }));
    await sleep(250);
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(`${OUT}/variant-${v}.png`, Buffer.from(shot.result.data, 'base64'));
    console.log(`saved variant-${v}.png`);
  }
} finally {
  chrome.kill();
}
process.exit(0);
