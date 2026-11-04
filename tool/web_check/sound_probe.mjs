// Runs the sound probe's web build in Chrome and prints its SOUND_PROBE
// line (docs/plans/PLAN_V07.md §7): node sound_probe.mjs
// <build/web> [--channel chrome] [--headed]
import { createServer } from 'node:http';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
const web = resolve(args[0]);
const channel = args.includes('--channel') ? args[args.indexOf('--channel') + 1] : undefined;
const headed = args.includes('--headed');
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.css': 'text/css', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};
const server = createServer((request, response) => {
  const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const file = join(web, path === '/' ? 'index.html' : path);
  if (!file.startsWith(web) || !existsSync(file) || statSync(file).isDirectory()) {
    response.writeHead(404);
    response.end();
    return;
  }
  response.writeHead(200, {
    'content-type': types[extname(file)] ?? 'application/octet-stream',
    // Cross-origin isolation, so that SoLoud may use its threaded build.
    'cross-origin-opener-policy': 'same-origin',
    'cross-origin-embedder-policy': 'require-corp',
  });
  response.end(readFileSync(file));
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const base = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({
  headless: !headed,
  channel,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage();
let result = null;
page.on('console', (m) => {
  const text = m.text();
  if (text.includes('SOUND_PROBE {')) result = text.slice(text.indexOf('{'));
  else if (m.type() === 'error') console.error('console:', text);
});
await page.goto(base);
// Flutter's page draws on a canvas: its semantics tree comes after the
// placeholder is clicked, and then the button has a role and a name.
await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
await page.getByRole('button', { name: 'Start', exact: true }).click({ timeout: 60000 });
const deadline = Date.now() + 120000;
while (result === null && Date.now() < deadline) {
  await page.waitForTimeout(500);
}
console.log(result ?? 'no result');
await browser.close();
server.close();
process.exit(result ? 0 : 1);
