// LASTROOT web build: end-to-end phone flow with real touch input.
//
// What it is: Chromium (Playwright) emulating a 390x844 phone (DPR 2, touch,
// isMobile) playing the exported Web build. Every action is a
// page.touchscreen.tap() on the canvas (the champion list is scrolled with a
// CDP touch swipe); no fixtures, no debug commands.
// What it is not: a physical phone (software GL, ~1-2 fps, no real fingers).
//
// Where to tap comes from the game's own read-out: started with the user arg
// `--debug-state`, SettingsService prints the run state and every visible tap
// target (name, text, centre in logical pixels) to the console whenever they
// change. The script only reads that; the game reacts to the taps alone.
//
// Setup:
//   godot --headless --path . --export-release "Web" builds/web/index.html
//   python3 tools/build_web_artifact.py <dir>
//   sed -i 's/"args": \[\]/"args": ["--","--debug-state"]/' <dir>/index.html
//   (the evidence run also added "--debug-input", which logs INPUT lines)
//   (cd <dir> && python3 -m http.server 8791) &
//   NODE_PATH=<playwright>/node_modules node tools/web_phone_flow.js http://localhost:8791/index.html evidence/web_phone_flow
//
// Steps (each saves NN_<step>.png and a PASS/FAIL entry in result.json):
//   01 load            page loads, "Start the game" tapped, title menu appears
//   02 new_run         tap New Run -> first-run guide prompt
//   03 skip_guide      tap Skip -> champion select
//   04 choose_spore    swipe the champion list up, tap the Spore Sage's Choose -> battle 1, turn 1
//   05 champion_card   tap the champion card in the hand -> + spots appear
//   06 plus_spot       tap a + spot -> Confirm becomes enabled
//   07 confirm         tap Confirm -> one more ally on the tree
//   08 end_turn        tap End turn, wait for playback -> turn 2, player phase
//   09 forecast_sheet  tap the forecast summary -> sheet expands (▾)
//   10 menu            tap ≡ -> pause menu with Save & quit
//   11 save_quit       tap Save & quit -> title menu with Continue
//   12 continue        tap Continue -> same battle, same turn, same allies
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const URL = process.argv[2] || 'http://localhost:8791/index.html';
const OUT = process.argv[3] || 'evidence/web_phone_flow';
const SLOW = 240000; // swiftshader runs the game at ~1-2 fps

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', headless: false,
    args: ['--headless=new', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, hasTouch: true, isMobile: true });
  const errors = [];
  let block = null;
  let latest = { state: {}, ui: [], at: 0 };
  page.on('console', (m) => {
    const t = m.text();
    if (/SCRIPT ERROR|USER ERROR/.test(t)) errors.push(t);
    for (const line of t.split('\n')) {
      if (line.startsWith('STATE ')) {
        const st = {};
        for (const kv of line.slice(6).split(' ')) { const [k, v] = kv.split('='); st[k] = v; }
        block = { state: st, ui: [] };
      } else if (line.startsWith('UI ') && block) {
        const [name, text, cx, cy, w, h, dis] = line.slice(3).split('|');
        block.ui.push({ name, text, cx: +cx, cy: +cy, w: +w, h: +h, disabled: dis === 'disabled' });
      } else if (line === 'STATE_END' && block) {
        latest = { ...block, at: Date.now() };
        block = null;
      }
    }
  });
  const results = [];
  const t0 = Date.now();
  let n = 0;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  async function waitFor(pred, timeout = SLOW) {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      try { const v = pred(latest); if (v) return v; } catch (e) { /* not there yet */ }
      await sleep(500);
    }
    return null;
  }
  const find = (pred) => latest.ui.find(pred);
  async function tapUi(entry) {
    const box = await page.locator('#canvas').boundingBox();
    const [vw, vh] = (latest.state.view || '430x932').split('x').map(Number);
    const x = box.x + entry.cx * box.width / vw;
    const y = box.y + entry.cy * box.height / vh;
    await page.touchscreen.tap(x, y);
    return { x: Math.round(x), y: Math.round(y) };
  }
  const viewH = () => +(latest.state.view || '430x932').split('x')[1];
  const onScreen = (u) => u.cy > 40 && u.cy < viewH() - 40;
  // A real finger swipe (CDP touch events), e.g. to scroll a list.
  const cdp = await page.context().newCDPSession(page);
  async function swipe(x, y0, y1, steps = 20) {
    const pt = (y) => [{ x, y, radiusX: 4, radiusY: 4, force: 1, id: 1 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: pt(y0) });
    for (let i = 1; i <= steps; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: pt(y0 + (y1 - y0) * i / steps) });
      await sleep(250); // the game runs at 1-2 fps: spread the moves over frames
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  }
  // Swipes up until the target is inside the screen (like a player scrolling).
  async function scrollTo(pick, tries = 8) {
    for (let i = 0; i < tries; i++) {
      const t = find(pick);
      if (t && onScreen(t)) return t;
      const before = t ? t.cy : null;
      await swipe(195, 470, 110);
      await waitFor(() => { const u = find(pick); return u && u.cy !== before; }, 30000);
    }
    const t = find(pick);
    return t && onScreen(t) ? t : null;
  }
  async function step(name, fn) {
    n += 1;
    const id = String(n).padStart(2, '0') + '_' + name;
    const s0 = Date.now();
    let pass = false;
    let detail = '';
    try { const r = await fn(); pass = !!r && r.pass !== false; detail = (r && r.detail) || ''; } catch (e) { detail = 'exception: ' + e.message; }
    await sleep(1500);
    await page.screenshot({ path: path.join(OUT, id + '.png') });
    results.push({ step: id, pass, detail, seconds: Math.round((Date.now() - s0) / 1000), state: latest.state });
    console.log((pass ? 'PASS ' : 'FAIL ') + id + ' ' + detail);
    return pass;
  }
  // Taps a target found by `pick`, then waits until `done` holds (re-tapping
  // once if nothing happened: at 1-2 fps a tap can land before the UI is live).
  async function tapThen(pick, done, label) {
    const target = await waitFor(() => find(pick));
    if (!target) return { pass: false, detail: label + ': target not on screen' };
    const at = await tapUi(target);
    let ok = await waitFor(done, SLOW / 2);
    if (!ok) {
      const again = find(pick);
      if (again) { await tapUi(again); ok = await waitFor(done, SLOW / 2); }
    }
    return { pass: !!ok, detail: `${label}: tapped "${target.text || target.name}" at css ${at.x},${at.y}` + (ok ? '' : ' -> expected change did not happen') };
  }

  let ok = await step('load', async () => {
    await page.goto(URL);
    await page.waitForSelector('#start:not([hidden])', { timeout: SLOW });
    const b = await page.locator('#start').boundingBox();
    await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2);
    const m = await waitFor(() => find((u) => u.name === 'NewRunButton'));
    return { pass: !!m, detail: m ? 'title menu up' : 'menu never appeared' };
  });
  if (ok) ok = await step('new_run', () => tapThen((u) => u.name === 'NewRunButton',
    () => find((u) => u.name === 'SkipGuideButton' || u.name === 'Choose_SPORE'), 'New Run'));
  if (ok) ok = await step('skip_guide', async () => {
    if (!find((u) => u.name === 'SkipGuideButton')) return { pass: true, detail: 'no guide prompt (already answered)' };
    return tapThen((u) => u.name === 'SkipGuideButton', () => find((u) => u.name === 'Choose_SPORE'), 'Skip');
  });
  if (ok) ok = await step('choose_spore', async () => {
    const t = await scrollTo((u) => u.name === 'Choose_SPORE');
    if (!t) return { pass: false, detail: 'swiping never brought Choose (Spore Sage) on screen' };
    return tapThen((u) => u.name === 'Choose_SPORE' && onScreen(u),
      (L) => L.state.phase === 'battle' && L.state.turn === '1' && L.ui.some((u) => u.text === 'card:' + L.state.champ), 'swiped down the list, Choose Spore Sage');
  });
  let allies0 = 0;
  if (ok) ok = await step('champion_card', async () => {
    allies0 = +latest.state.allies;
    return tapThen((u) => u.text === 'card:' + latest.state.champ, () => find((u) => u.text === '+' && !u.disabled), 'champion card');
  });
  if (ok) ok = await step('plus_spot', () => tapThen((u) => u.text === '+' && !u.disabled,
    () => find((u) => u.text === 'Confirm' && !u.disabled), '+ spot'));
  if (ok) ok = await step('confirm', () => tapThen((u) => u.text === 'Confirm' && !u.disabled,
    (L) => +L.state.allies === allies0 + 1, 'Confirm'));
  let turnAfter = '';
  let alliesAfter = '';
  if (ok) ok = await step('end_turn', async () => {
    const r = await tapThen((u) => u.text === 'End turn' && !u.disabled,
      (L) => L.state.turn === '2' && L.state.bphase === 'player' && L.ui.some((u) => u.text === 'End turn' && !u.disabled), 'End turn');
    turnAfter = latest.state.turn;
    alliesAfter = latest.state.allies;
    r.detail += ` -> turn ${turnAfter}, allies ${alliesAfter}`;
    return r;
  });
  if (ok) ok = await step('forecast_sheet', () => tapThen((u) => u.name === 'SheetSummary',
    () => find((u) => u.name === 'SheetSummary' && u.text.startsWith('▾')), 'forecast summary'));
  if (ok) ok = await step('menu', () => tapThen((u) => u.text === '≡', () => find((u) => u.name === 'SaveQuitButton'), 'menu'));
  if (ok) ok = await step('save_quit', () => tapThen((u) => u.name === 'SaveQuitButton', () => find((u) => u.name === 'ContinueButton'), 'Save & quit'));
  if (ok) ok = await step('continue', async () => {
    const r = await tapThen((u) => u.name === 'ContinueButton',
      (L) => L.state.phase === 'battle' && L.ui.some((u) => u.text === 'End turn'), 'Continue');
    const same = latest.state.turn === turnAfter && latest.state.allies === alliesAfter;
    r.pass = r.pass && same;
    r.detail += ` -> turn ${latest.state.turn} (was ${turnAfter}), allies ${latest.state.allies} (was ${alliesAfter})`;
    return r;
  });

  const summary = {
    what: 'Playwright Chromium emulating a 390x844 phone (DPR 2, touch, isMobile), swiftshader GL; NOT a physical phone',
    input: 'page.touchscreen.tap only; tap positions read from the game\'s --debug-state console read-out',
    url: URL, date: new Date().toISOString(), seconds: Math.round((Date.now() - t0) / 1000),
    status: results.length === 12 && results.every((r) => r.pass) ? 'PASS' : 'FAIL',
    steps: results, script_errors: errors.slice(0, 20),
  };
  fs.writeFileSync(path.join(OUT, 'result.json'), JSON.stringify(summary, null, 2));
  console.log('WEB_PHONE_FLOW ' + summary.status + ' ' + results.filter((r) => r.pass).length + '/12');
  await browser.close();
})();
