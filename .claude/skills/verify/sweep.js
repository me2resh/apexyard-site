// Browser step for verify.sh. Usage: node sweep.js <playwright-dir> <base-url>
// Prints one line per page: RESULT|page|PASS or FAIL|detail
const pw = require(process.argv[2]);
const base = process.argv[3];
const pages = ['index.html', 'how-it-works.html', 'pricing.html', 'skills.html'];
const HEADER = 67;
const STEPS = 25;
// Never touch the real keychain: Chrome would try to create its Safe Storage key.
const ARGS = ['--use-mock-keychain', '--password-store=basic'];
const MIN_CHECKED = 5; // fewer checked steps than this cannot prove the marker stays in view

async function launch() {
  try { return await pw.chromium.launch({ args: ARGS }); } catch (e) { /* try system Chrome */ }
  return pw.chromium.launch({ channel: 'chrome', args: ARGS });
}

(async () => {
  const browser = await launch();
  for (const name of pages) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', (e) => errors.push(String(e)));
    let detail = [];
    try {
      const res = await page.goto(base + '/' + name, { waitUntil: 'load', timeout: 20000 });
      if (!res || res.status() !== 200) detail.push('HTTP ' + (res && res.status()));
      await page.waitForTimeout(500);
      const has = await page.evaluate(() => !!document.querySelector('.marker b'));
      const result = { checked: 0, bad: [] };
      if (has) {
        const max = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight);
        for (let i = 0; i <= STEPS - 1; i++) {
          await page.evaluate((y) => window.scrollTo(0, y), Math.round((max * i) / (STEPS - 1)));
          let last = null;
          for (let k = 0; k < 30; k++) {
            await page.waitForTimeout(60);
            const t = await page.evaluate(() => document.querySelector('.marker').style.transform);
            if (t === last) break;
            last = t;
          }
          const s = await page.evaluate(() => {
            const r = document.querySelector('.marker b').getBoundingClientRect();
            const lp = document.querySelector('.lit path');
            const lr = lp ? lp.getBoundingClientRect() : null;
            return { cy: r.top + r.height / 2, vh: innerHeight, lineOn: lr ? lr.top < innerHeight && lr.bottom > 0 : true };
          });
          if (!s.lineOn) continue;
          result.checked++;
          if (s.cy < HEADER || s.cy > s.vh) result.bad.push('step ' + i + ' cy=' + Math.round(s.cy));
        }
      }
      if (errors.length) detail.push('console errors: ' + errors.slice(0, 3).join(' / '));
      if (has && result.bad.length) detail.push('marker out of range: ' + result.bad.slice(0, 4).join(', '));
      if (!has) detail.push('no .marker element on this page');
      else if (result.checked < MIN_CHECKED) detail.push('only ' + result.checked + ' of ' + STEPS + ' steps checked, need ' + MIN_CHECKED);
      const note = 'marker checked at ' + result.checked + ' of ' + STEPS + ' steps';
      console.log('RESULT|' + name + '|' + (detail.length ? 'FAIL' : 'PASS') + '|' + (detail.concat(note)).join('; '));
    } catch (e) {
      console.log('RESULT|' + name + '|FAIL|' + String(e.message).split('\n')[0]);
    }
    await page.close();
  }
  await browser.close();
})().catch((e) => { console.log('ERROR|' + String(e.message).split('\n')[0]); process.exit(2); });
