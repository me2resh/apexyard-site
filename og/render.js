#!/usr/bin/env node
/**
 * Render the four Swiss Graphite OG cards to 1200x630 PNG via headless Chromium.
 *
 * Usage: node render.js [--roles N --skills N --hooks N]
 * Counts default to env ROLES/SKILLS/HOOKS (set by render.sh). The HTML
 * templates carry {{ROLES}}/{{SKILLS}}/{{HOOKS}} placeholders that are
 * substituted in-memory before rendering — the committed templates stay
 * count-agnostic so a future regen just re-derives the numbers.
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const TPL_DIR = path.join(__dirname, 'templates');
const OUT_DIR = __dirname;
const CARDS = ['index', 'architecture', 'skills', 'game'];

const counts = {
  ROLES: process.env.ROLES || '0',
  SKILLS: process.env.SKILLS || '0',
  HOOKS: process.env.HOOKS || '0',
};

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1200, height: 630 },
    deviceScaleFactor: 1,
  });

  const baseCss = fs.readFileSync(path.join(TPL_DIR, '_base.css'), 'utf8');

  for (const card of CARDS) {
    const tplPath = path.join(TPL_DIR, `${card}.html`);
    let html = fs.readFileSync(tplPath, 'utf8');
    for (const [k, v] of Object.entries(counts)) {
      html = html.replaceAll(`{{${k}}}`, v);
    }
    // inline _base.css so the page is self-contained (no relative <link> to resolve)
    html = html.replace(
      '<link rel="stylesheet" href="_base.css">',
      `<style>\n${baseCss}\n</style>`
    );
    await page.setContent(html, { waitUntil: 'networkidle' });
    // ensure webfonts are fully loaded before the screenshot
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(500);

    const outPath = path.join(OUT_DIR, `${card}.png`);
    await page.screenshot({ path: outPath, clip: { x: 0, y: 0, width: 1200, height: 630 } });
    console.log(`rendered ${card}.png`);
  }

  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
