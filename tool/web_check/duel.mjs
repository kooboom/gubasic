// The Duel example (docs/DESIGN.md D139) in a real browser: the built web
// player is served with the bundle apps/player/tool/duel_bundle.dart made,
// the script presses "2인" and plays two players on one keyboard. Round 1:
// 1P holds D and punches with F until the knock-out. Round 2: 2P holds the
// left arrow and punches with the period key, a punctuation key, until
// the knock-out. Round 3: the keys a browser sends while a Korean input
// method is on (through the DevTools protocol: `key` a Korean letter,
// `keyCode` 229, `code` the key's place), which must act the same, so 1P
// wins the match. A headless browser cannot turn on a real input method;
// the author checks that once by hand. The player draws on a canvas, so
// the script turns on Flutter's accessibility to find the buttons and the
// labels.
//
//   node tool/web_check/duel.mjs [--web apps/player/build/web]
//        [--bundle apps/player/build/duel/duel.gbz] [--headed]
//        [--channel chrome] [--shots folder]
//
// With --shots it keeps a picture of each knock-out (duel-ko-1.png, …) and
// of the end (duel-web.png).
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
const bundle = option('--bundle', 'apps/player/build/duel/duel.gbz');
const shots = option('--shots', null);
const headed = args.includes('--headed');
const channel = args.includes('--channel') ? args[args.indexOf('--channel') + 1] : undefined;
for (const required of [join(web, 'index.html'), bundle]) {
  if (!existsSync(required)) {
    console.error(`${required} is missing: build the player for the web and run dart run tool/duel_bundle.dart in apps/player`);
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
const page = await context.newPage();
const problems = [];
page.on('console', (m) => {
  if (m.type() === 'error') problems.push(m.text());
});
page.on('pageerror', (e) => problems.push(`${e}`));
await page.goto(base);
await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
const two = page.getByRole('button', { name: '2인', exact: true });
await two.waitFor({ timeout: 60_000 });
await two.click();

const results = [];
const say = (ok, what) => results.push([ok, what]);
// Waits up to [ms] for a label with exactly [text].
const shows = async (text, ms) => {
  try {
    await page.getByText(text, { exact: true }).waitFor({ timeout: ms });
    return true;
  } catch {
    return false;
  }
};
// Holds [walk] and presses [punch] every 300 ms until [text] shows.
const fight = async (press, walk, punch, text) => {
  await press(walk, 'down');
  for (let i = 0; i < 80; i++) {
    await press(punch, 'down');
    await press(punch, 'up');
    if (await shows(text, 300)) break;
  }
  await press(walk, 'up');
  const shown = await shows(text, 1000);
  // The knock-out at the stage's edge: the fighter down stays inside it.
  if (shots) {
    mkdirSync(shots, { recursive: true });
    await page.screenshot({ path: join(shots, `duel-ko-${++knockOuts}.png`) });
  }
  return shown;
};
let knockOuts = 0;

// Round 1 and 2: the keys as a US keyboard sends them.
const keyboard = async (key, how) => (how === 'down' ? page.keyboard.down(key) : page.keyboard.up(key));
say(await shows('1라운드', 5000), 'round 1 starts, the buttons hidden');
say(await fight(keyboard, 'KeyD', 'KeyF', 'KO! 1P가 이겼습니다'), '1P: D held and F pressed, a knock-out');
say(await shows('2라운드', 5000), 'round 2 starts');
say(await fight(keyboard, 'ArrowLeft', 'Period', 'KO! 2P가 이겼습니다'), '2P: ← held and . pressed, a knock-out');

// Round 3: what a browser sends while a Korean input method is on: the
// key is a Korean letter (or Process) and keyCode 229; only `code` tells
// the key's place.
const cdp = await context.newCDPSession(page);
const korean = { KeyD: 'ㅇ', KeyF: 'ㄹ' };
const ime = async (code, how) => {
  await cdp.send('Input.dispatchKeyEvent', {
    type: how === 'down' ? 'keyDown' : 'keyUp',
    key: korean[code] ?? 'Process',
    code,
    windowsVirtualKeyCode: 229,
    nativeVirtualKeyCode: 229,
  });
};
say(await shows('3라운드', 5000), 'round 3 starts');
say(await fight(ime, 'KeyD', 'KeyF', 'KO! 1P가 이겼습니다'), '1P with the Korean input method on: ㅇ held and ㄹ pressed, a knock-out');
say(await shows('1P 승리!', 5000), '1P wins the match, two rounds to one');
say(await page.getByRole('button', { name: '다시: 2인', exact: true }).isVisible(), 'the buttons are back');
if (shots) {
  mkdirSync(shots, { recursive: true });
  await page.screenshot({ path: join(shots, 'duel-web.png') });
}
await browser.close();
server.close();
let failed = false;
for (const [ok, what] of results) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) failed = true;
}
console.log(`${problems.length === 0 ? 'ok  ' : 'FAIL'} ${problems.length === 0 ? 'no error in the console' : `console errors:\n${problems.join('\n')}`}`);
process.exit(failed || problems.length > 0 ? 1 : 0);
