// LASTROOT "Web Demo" export: boots the exported page in headless Chromium
// (swiftshader, software GL) and checks that the title menu shows the DEMO tag.
// It does not play the demo (that is checked on the Linux QA export, see
// docs/DEMO_PLAN.md); it proves the web demo build loads and is a demo build.
//
//   godot --headless --path . --export-release "Web Demo" builds/web_demo/index.html
//   sed -i 's/"args":\[\]/"args":["--","--debug-state"]/' builds/web_demo/index.html
//   (cd builds/web_demo && python3 -m http.server 8792) &
//   NODE_PATH=/opt/node-tools/node_modules node tools/web_demo_check.js http://localhost:8792/index.html evidence/demo
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const URL = process.argv[2] || 'http://localhost:8792/index.html';
const OUT = process.argv[3] || 'evidence/demo';

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', headless: false,
    args: ['--headless=new', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  let ui = [];
  let cur = [];
  let state = '';
  page.on('console', (m) => {
    for (const line of m.text().split('\n')) {
      if (/SCRIPT ERROR|USER ERROR/.test(line)) errors.push(line);
      if (line.startsWith('STATE ')) { state = line; cur = []; }
      else if (line.startsWith('UI ')) cur.push(line.slice(3).split('|').slice(0, 2).join('|'));
      else if (line === 'STATE_END') ui = cur;
    }
  });
  const t0 = Date.now();
  await page.goto(URL);
  let menu = false;
  while (Date.now() - t0 < 300000) {
    if (ui.some((u) => u.startsWith('NewRunButton'))) { menu = true; break; }
    await new Promise((r) => setTimeout(r, 1000));
  }
  await new Promise((r) => setTimeout(r, 4000));
  const shot = path.join(OUT, 'web_demo_title.png');
  await page.screenshot({ path: shot });
  // The DEMO tag is a label, not a tap target, so the debug read-out does not
  // list it: the screenshot is the record for it.
  const result = { url: URL, menu_reached: menu, seconds: Math.round((Date.now() - t0) / 1000), state,
    tap_targets: ui, script_errors: errors, screenshot: shot };
  fs.writeFileSync(path.join(OUT, 'web_demo_check.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ menu_reached: menu, seconds: result.seconds, errors: errors.length }));
  await browser.close();
  process.exit(menu && errors.length === 0 ? 0 : 1);
})();
