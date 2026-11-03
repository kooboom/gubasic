// One round of the LiveQuiz example (docs/DESIGN.md D136) in a real
// browser: the relay server runs on this computer (packages/gubasic_relay,
// on 127.0.0.1:7181), the built web player is served with the bundle
// apps/player/tool/livequiz_bundle.dart made (Room.Server pointing to that
// relay server), and two browser contexts play it, the TV and a phone.
// The player draws on a canvas, so the script turns on Flutter's
// accessibility, which puts the buttons, labels and text boxes into the
// page, and acts on those. Nothing of the computer's own mouse or keyboard
// is used.
//
//   node tool/web_check/livequiz.mjs [--web apps/player/build/web]
//        [--bundle apps/player/build/livequiz/livequiz.gbz]
//        [--shots folder] [--headed] [--channel chrome]
//
// Exits 0 when the round ends as expected; --shots saves both screens.
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { readFileSync, existsSync, statSync, mkdirSync } from 'node:fs';
import { join, extname, resolve, dirname } from 'node:path';
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
const bundle = option('--bundle', 'apps/player/build/livequiz/livequiz.gbz');
const shots = option('--shots', null);
const headed = args.includes('--headed');
const channel = args.includes('--channel') ? args[args.indexOf('--channel') + 1] : undefined;
const relayPort = 7181;

for (const required of [join(web, 'index.html'), bundle]) {
  if (!existsSync(required)) {
    console.error(`${required} is missing: build the player for the web and run dart run tool/livequiz_bundle.dart in apps/player`);
    process.exit(1);
  }
}

// The relay server.
const relay = spawn('dart', ['run', 'bin/gubasic_relay.dart', '--port', `${relayPort}`], {
  cwd: join(root, 'packages', 'gubasic_relay'),
  stdio: ['ignore', 'pipe', 'inherit'],
});
const stop = () => relay.kill();
process.on('exit', stop);
for (let i = 0; ; i++) {
  try {
    const health = await fetch(`http://127.0.0.1:${relayPort}/room/health`);
    if (health.ok) break;
  } catch {}
  if (i === 300) throw new Error('the relay server did not start');
  await new Promise((ok) => setTimeout(ok, 200));
}

const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.gbz': 'application/zip', '.css': 'text/css',
  '.txt': 'text/plain; charset=utf-8',
};
const server = createServer((request, response) => {
  const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const file = path === '/project.gbz' ? bundle : join(web, path === '/' ? 'index.html' : path);
  if (!existsSync(file) || statSync(file).isDirectory()) {
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
/** A page of the app in a context of its own, with accessibility on. */
async function open(name) {
  const context = await browser.newContext({ locale: 'ko-KR', viewport: { width: 900, height: 700 } });
  const page = await context.newPage();
  page.on('pageerror', (e) => console.log(`${name}: page error: ${e}`));
  await page.goto(base);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60_000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  return page;
}
const step = (text) => console.log(`- ${text}`);
const shot = async (page, name) => {
  if (!shots) return;
  mkdirSync(shots, { recursive: true });
  await page.screenshot({ path: join(shots, name) });
};

let ok = false;
let tv, phone;
try {
  tv = await open('TV');
  await tv.getByRole('button', { name: 'TV로 진행', exact: true }).click();
  const codeLabel = tv.getByText(/^방 코드: [0-9A-Z]{6}$/);
  await codeLabel.waitFor({ timeout: 30_000 });
  const code = (await codeLabel.textContent()).slice(-6);
  step(`the TV made room ${code}`);

  phone = await open('phone');
  await phone.getByRole('button', { name: '폰으로 참여', exact: true }).click();
  const boxes = phone.getByRole('textbox');
  await boxes.first().waitFor();
  // With accessibility on, a text box is an input element of the page;
  // the letters go in one by one, as a person types them.
  const typeInto = async (box, text) => {
    await box.click();
    await phone.waitForTimeout(300);
    await box.pressSequentially(text, { delay: 150 });
    await phone.waitForTimeout(300);
  };
  await typeInto(boxes.nth(0), code.toLowerCase());
  await typeInto(boxes.nth(1), '민지');
  await phone.getByRole('button', { name: '들어가기', exact: true }).click();
  await phone.getByText(/들어왔습니다/).waitFor({ timeout: 30_000 });
  step('the phone joined, its code typed in small letters');
  await tv.getByText('민지 0점').waitFor({ timeout: 30_000 });
  step('the TV lists 민지');

  await tv.getByRole('button', { name: '시작', exact: true }).click();
  await phone.getByRole('button', { name: '2) 서울', exact: true }).click({ timeout: 30_000 });
  await tv.getByText('정답: 2) 서울').waitFor({ timeout: 30_000 });
  await tv.getByText('민지 10점').waitFor();
  await phone.getByText('정답! 지금 10점').waitFor({ timeout: 30_000 });
  await phone.getByText('내 순위: 1 / 1').waitFor({ timeout: 30_000 });
  step('the phone answered first and right: 10 points, rank 1 of 1');
  await shot(tv, 'livequiz-web-tv.png');
  await shot(phone, 'livequiz-web-phone.png');
  ok = true;
} catch (e) {
  console.log(`FAILED: ${e.message}`);
  if (tv) await shot(tv, 'livequiz-web-failed-tv.png');
  if (phone) await shot(phone, 'livequiz-web-failed-phone.png');
}
await browser.close();
server.close();
stop();
console.log(ok ? 'LiveQuiz: one round played in two browsers' : 'LiveQuiz: DIFFERENT');
process.exit(ok ? 0 : 1);
