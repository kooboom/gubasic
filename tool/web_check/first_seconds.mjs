// The first five seconds of a game on a fresh page (STAGE2_PLAN §7): opens
// a measuring player's page (built with -t lib/bench_main.dart
// --dart-define=GUBASIC_BENCH=true) in a new browser with no cache, and
// lines up against the game's first tick (the probe prints a mark) what
// the page did: long tasks (Chromium only), gaps between animation frames,
// AudioContext and WebAssembly starts, picture decoding. Prints one line of
// JSON with the probe's firstSeconds and the page's records.
//
//   node tool/web_check/first_seconds.mjs apps/player/build/bench_web chromium '?bench=duel'
import { chromium, webkit } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
const [web, engine, query] = process.argv.slice(2);
const types = {'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.otf':'font/otf','.ttf':'font/ttf','.gbz':'application/octet-stream'};
const server = createServer((q, r) => { const p = decodeURIComponent(new URL(q.url,'http://x').pathname); const f = join(web, p === '/' ? 'index.html' : p); if (!existsSync(f) || statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; } r.writeHead(200, {'content-type': types[extname(f)] ?? 'application/octet-stream', 'cache-control':'no-store'}); r.end(readFileSync(f)); });
await new Promise(ok => server.listen(0, '127.0.0.1', ok));
const b = await (engine === 'webkit' ? webkit : chromium).launch();
const ctx = await b.newContext({ viewport: { width: 1280, height: 900 } });
await ctx.addInitScript(() => {
  const now = () => performance.now();
  const W = window.__probe = { long: [], raf: [], audio: [], wasm: [], decode: [], tick0: null };
  try { new PerformanceObserver(l => { for (const e of l.getEntries()) W.long.push([e.startTime, e.duration]); }).observe({ type: 'longtask', buffered: true }); } catch {}
  let last = 0; const loop = t => { if (last && t - last > 40) W.raf.push([last, t - last]); last = t; requestAnimationFrame(loop); }; requestAnimationFrame(loop);
  const log = console.log; console.log = (...a) => { if (String(a[0]).startsWith('GUBASIC_BENCH_TICK0')) W.tick0 = now(); return log.apply(console, a); };
  for (const name of ['AudioContext', 'webkitAudioContext']) { const O = window[name]; if (!O) continue; window[name] = function (...a) { const t = now(); const c = new O(...a); W.audio.push(['new ' + name, t, now() - t]); return c; }; window[name].prototype = O.prototype; }
  for (const fn of ['instantiate', 'instantiateStreaming', 'compile', 'compileStreaming']) { const O = WebAssembly[fn]; if (!O) continue; WebAssembly[fn] = function (...a) { const t = now(); const p = O.apply(WebAssembly, a); p.then(() => W.wasm.push([fn, t, now() - t])); return p; }; }
  const cib = window.createImageBitmap; if (cib) window.createImageBitmap = function (...a) { const t = now(); const p = cib.apply(window, a); p.then(() => W.decode.push(['createImageBitmap', t, now() - t])); return p; };
  if (window.ImageDecoder) { const d = ImageDecoder.prototype.decode; ImageDecoder.prototype.decode = function (...a) { const t = now(); const p = d.apply(this, a); p.then(() => W.decode.push(['ImageDecoder', t, now() - t])); return p; }; }
});
const p = await ctx.newPage();
const done = new Promise(ok => p.on('console', m => { const t = m.text(); if (t.startsWith('GUBASIC_BENCH ')) ok(JSON.parse(t.slice(14))); }));
await p.goto(`http://127.0.0.1:${server.address().port}/${query}`);
const bench = await Promise.race([done, new Promise(ok => setTimeout(() => ok(null), 120000))]);
const probe = await p.evaluate(() => {
  const W = window.__probe; const t0 = W.tick0 ?? 0; const rel = xs => xs.map(x => x.map((v, i) => typeof v === 'number' ? Math.round((i === 0 || (x.length === 3 && i === 1) ? v - t0 : v) * 10) / 10 : v));
  const res = performance.getEntriesByType('resource').filter(e => e.startTime > t0 - 2000 && e.startTime < t0 + 5000).map(e => [e.name.split('/').pop(), Math.round(e.startTime - t0), Math.round(e.duration)]);
  const win = xs => xs.filter(x => { const s = typeof x[0] === 'number' ? x[0] : x[1]; return s > -2000 && s < 5000; });
  return { tick0: W.tick0, long: win(rel(W.long)), raf: win(rel(W.raf)), audio: rel(W.audio), wasm: rel(W.wasm), decode: win(rel(W.decode)).slice(0, 40), res };
});
console.log(JSON.stringify({ engine, first: bench?.firstSeconds, max: bench?.tickHandlerMaxMs, probe }));
await b.close(); server.close();
