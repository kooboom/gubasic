// The Shooter example (docs/DESIGN.md D138) in a real browser: the built
// web player is served with the bundle apps/player/tool/shooter_bundle.dart
// made, the script presses Start (a click, which lets the page play sound),
// holds the keys a player would, and checks that the score went up, that
// the page made an AudioContext only after the click, and that nothing
// went wrong in the console. The player draws on a canvas, so the script
// turns on Flutter's accessibility to find the button and the labels.
//
//   node tool/web_check/shooter.mjs [--web apps/player/build/web]
//        [--bundle apps/player/build/shooter/shooter.gbz] [--headed]
//        [--channel chrome] [--shots folder]
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..');
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? resolve(args[i + 1]) : fallback && resolve(root, fallback);
};
const web = option('--web', 'apps/player/build/web');
const bundle = option('--bundle', 'apps/player/build/shooter/shooter.gbz');
const shots = option('--shots', null);
const headed = args.includes('--headed');
const channel = args.includes('--channel') ? args[args.indexOf('--channel') + 1] : undefined;
for (const required of [join(web, 'index.html'), bundle]) {
  if (!existsSync(required)) {
    console.error(`${required} is missing: build the player for the web and run dart run tool/shooter_bundle.dart in apps/player`);
    process.exit(1);
  }
}
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.css': 'text/css', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
  '.gbz': 'application/octet-stream',
};
const server = createServer((request, response) => {
  const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  if (path === '/project.gbz') {
    response.writeHead(200, { 'content-type': types['.gbz'] });
    response.end(readFileSync(bundle));
    return;
  }
  const file = join(web, path === '/' ? 'index.html' : path);
  if (!file.startsWith(web) || !existsSync(file) || statSync(file).isDirectory()) {
    response.writeHead(404);
    response.end();
    return;
  }
  response.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
  response.end(readFileSync(file));
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const base = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({ headless: !headed, channel });
const context = await browser.newContext({ locale: 'ko-KR' });
// Counts the AudioContexts the page makes, and when: none may come before
// the click on Start.
await context.addInitScript(() => {
  window.__audioContexts = [];
  for (const name of ['AudioContext', 'webkitAudioContext']) {
    const Original = window[name];
    if (!Original) continue;
    window[name] = function (...a) {
      window.__audioContexts.push(performance.now());
      return new Original(...a);
    };
    window[name].prototype = Original.prototype;
  }
});
const page = await context.newPage();
const problems = [];
page.on('console', (m) => {
  if (m.type() === 'error') problems.push(m.text());
});
page.on('pageerror', (e) => problems.push(`${e}`));
await page.goto(base);
await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
const start = page.getByRole('button', { name: '시작', exact: true });
await start.waitFor({ timeout: 60_000 });
const beforeClick = await page.evaluate(() => window.__audioContexts.length);
const clickedAt = await page.evaluate(() => performance.now());
await start.click();
// A player holds Right and fires for a while, then Left.
await page.keyboard.down('Space');
await page.keyboard.down('ArrowRight');
await page.waitForTimeout(1500);
await page.keyboard.up('ArrowRight');
await page.keyboard.down('ArrowLeft');
await page.waitForTimeout(4000);
await page.keyboard.up('ArrowLeft');
await page.waitForTimeout(3000);
await page.keyboard.up('Space');
const score = await page.getByText(/^점수 \d+$/).textContent();
const lives = await page.getByText(/^목숨 \d+$/).textContent();
const contexts = await page.evaluate(() => window.__audioContexts);
if (shots) {
  mkdirSync(shots, { recursive: true });
  await page.screenshot({ path: join(shots, 'shooter-web.png') });
}
await browser.close();
server.close();
let failed = false;
const say = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) failed = true;
};
say(beforeClick === 0 && contexts.length > 0 && contexts.every((t) => t >= clickedAt),
  `the page made ${contexts.length} AudioContext(s), all after Start was pressed`);
say(/^점수 [1-9]\d*$/.test(score ?? ''), `the score went up: ${score}`);
say(/^목숨 \d$/.test(lives ?? ''), `the lives are shown: ${lives}`);
say(problems.length === 0, problems.length === 0 ? 'no error in the console' : `console errors:\n${problems.join('\n')}`);
process.exit(failed ? 1 : 0);
