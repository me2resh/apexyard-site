// WCAG 2.2 AA contrast for the docs tokens in both themes.
// Text pairs need 4.5:1. State colours are used as rules and icons only,
// so they need 3:1 (non-text contrast) on each background.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const css = fs.readFileSync(new URL('../src/styles/tokens.css', import.meta.url), 'utf8');

// Merge every block whose selector line is exactly `selector {`.
function block(selector) {
  const out = {};
  let from = 0;
  let found = false;
  for (;;) {
    const start = css.indexOf(`\n${selector} {`, from);
    if (start < 0) break;
    found = true;
    const body = css.slice(start, css.indexOf('}', start));
    for (const m of body.matchAll(/--(ay-[\w-]+):\s*([^;]+);/g)) out[m[1]] = m[2].trim();
    from = start + 1;
  }
  assert.ok(found, `missing ${selector}`);
  return out;
}

const light = block(':root');
const dark = { ...light, ...block(":root[data-theme='dark']") };

function value(theme, name) {
  let v = theme[name];
  for (let i = 0; v && v.startsWith('var('); i++) v = theme[v.slice(6, -1)];
  assert.match(v, /^#[0-9A-Fa-f]{6}$/, `${name} resolves to ${v}`);
  return v;
}

function lum(hex) {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

function ratio(a, b) {
  const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
}

const TEXT = ['ay-text', 'ay-text-muted', 'ay-link', 'ay-wait-text'];
const NON_TEXT = ['ay-pass', 'ay-wait', 'ay-block', 'ay-blue', 'ay-focus', 'ay-rule-strong'];
const BACKGROUNDS = ['ay-bg', 'ay-surface'];

for (const [name, theme] of [['light', light], ['dark', dark]]) {
  for (const bg of BACKGROUNDS) {
    for (const fg of TEXT) {
      test(`${name}: ${fg} on ${bg} is at least 4.5:1`, () => {
        const r = ratio(value(theme, fg), value(theme, bg));
        assert.ok(r >= 4.5, `${r.toFixed(2)}:1`);
      });
    }
    for (const fg of NON_TEXT) {
      if (name === 'dark' && fg === 'ay-blue') continue; // dark theme uses ay-link for blue text and rules
      test(`${name}: ${fg} on ${bg} is at least 3:1`, () => {
        const r = ratio(value(theme, fg), value(theme, bg));
        assert.ok(r >= 3, `${r.toFixed(2)}:1`);
      });
    }
    for (const t of ['note', 'required', 'advisory', 'coming']) {
      test(`${name}: text on the ${t} callout tint is at least 4.5:1`, () => {
        const r = ratio(value(theme, 'ay-text'), value(theme, `ay-tint-${t}`));
        assert.ok(r >= 4.5, `${r.toFixed(2)}:1`);
      });
    }
  }
}

for (const [name, theme] of [['light', light], ['dark', dark]]) {
  test(`${name}: text on an accent fill (skip link) is at least 4.5:1`, () => {
    const r = ratio(value(theme, 'ay-on-accent'), value(theme, 'ay-link'));
    assert.ok(r >= 4.5, `${r.toFixed(2)}:1`);
  });
}
