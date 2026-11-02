// The parity programs that use Database, run by the built web player in
// a real browser (docs/DESIGN.md D126, CLAUDE.md hard rule 3): for each
// bundle apps/player/tool/parity_bundle.dart made, the player's build is
// served from a local server with that bundle as its project.gbz and
// sqlite3.wasm next to the page, Chromium opens it, and the console's
// `Debug.Print: …` lines and the `Run: …` line are compared with the
// program's NAME.out, the same expected output the VM and the run window
// are compared with.
//
//   node tool/web_check/parity.mjs [--web apps/player/build/web]
//                                  [--bundles apps/player/build/parity]
//                                  [--parity test/parity] [--headed]
//                                  [--channel chrome]
//
// --channel chrome drives the Chrome installed on the PC instead of the
// Chromium Playwright downloads (for a PC whose network refuses the
// download); CI uses the download.
//
// Exits 0 when every program's transcript matches; otherwise prints the
// difference and exits 1. CI runs it on every push (test.yml, player).
import { createServer } from 'node:http';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, extname, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..');
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? resolve(args[i + 1]) : resolve(root, fallback);
};
const web = option('--web', 'apps/player/build/web');
const bundles = option('--bundles', 'apps/player/build/parity');
const parity = option('--parity', 'test/parity');
const headed = args.includes('--headed');
const channel = args.includes('--channel') ? args[args.indexOf('--channel') + 1] : undefined;

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.gbz': 'application/zip',
  '.css': 'text/css',
  '.txt': 'text/plain; charset=utf-8',
};

for (const required of ['index.html', 'sqlite3.wasm']) {
  if (!existsSync(join(web, required))) {
    console.error(`${join(web, required)} is missing: build the player for the web after dart run tool/fetch_sqlite_wasm.dart`);
    process.exit(1);
  }
}
const programs = existsSync(bundles)
  ? readdirSync(bundles).filter((f) => f.endsWith('.gbz')).sort()
  : [];
if (programs.length === 0) {
  console.error(`${bundles} has no .gbz: run dart run tool/parity_bundle.dart in apps/player`);
  process.exit(1);
}

/** Serves the player's build, with [bundle] as its project.gbz. */
let bundle = null;
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
let failed = 0;
for (const file of programs) {
  const name = file.slice(0, -'.gbz'.length);
  bundle = join(bundles, file);
  const expected = readFileSync(join(parity, `${name}.out`), 'utf8').trimEnd().split('\n');
  // A fresh browser profile each time: the app's IndexedDB starts empty,
  // as the VM's and the run window's folders do. English, as the
  // transcripts are: the player speaks the browser's language.
  const context = await browser.newContext({ locale: 'en-US' });
  const page = await context.newPage();
  const lines = [];
  const errors = [];
  let ended;
  const done = new Promise((ok) => (ended = ok));
  page.on('console', (message) => {
    const text = message.text();
    if (text.startsWith('Debug.Print: ')) lines.push(text);
    else if (text.startsWith('Run: ')) {
      lines.push(text.slice('Run: '.length));
      ended();
    }
  });
  page.on('pageerror', (error) => errors.push(`${error}`));
  const start = Date.now();
  await page.goto(base);
  const timeout = new Promise((ok) => setTimeout(() => ok('timeout'), 120_000));
  const outcome = await Promise.race([done.then(() => 'ended'), timeout]);
  const seconds = ((Date.now() - start) / 1000).toFixed(1);
  await context.close();
  const same = outcome === 'ended' && lines.length === expected.length && lines.every((l, i) => l === expected[i]);
  if (same) {
    console.log(`${name}: ${lines.length} lines as in ${name}.out (${seconds} s)`);
    continue;
  }
  failed++;
  console.log(`${name}: DIFFERENT (${outcome}, ${seconds} s)`);
  const width = Math.max(lines.length, expected.length);
  for (let i = 0; i < width; i++) {
    if (lines[i] !== expected[i]) {
      console.log(`  line ${i + 1}`);
      console.log(`    expected: ${expected[i] ?? '(nothing)'}`);
      console.log(`    browser:  ${lines[i] ?? '(nothing)'}`);
    }
  }
  for (const e of errors) console.log(`  page error: ${e}`);
}
await browser.close();
server.close();
process.exit(failed === 0 ? 0 : 1);
