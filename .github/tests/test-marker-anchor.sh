#!/usr/bin/env bash
# #212 (owner decision, 22 Nov 2026): the #4242 marker is inside the viewport
# at every scroll position from the moment the line's first point is on
# screen to the page bottom. #208 mapped scroll progress to ARC LENGTH, and
# the real line has long horizontal runs, so the marker was often below the
# fold (no marker across the whole stats band). The rule now follows the
# line's vertical position (see markerLen in site.js).
#
# site.js has no DOM in CI, so this loads it with a minimal window/document
# stub (vm.runInNewContext) and exercises markerLen(vh, sy, scrollHeight,
# pts), the pure part. SITE_JS may point at another copy of site.js.
set -uo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if node - "$root" <<'NODE'
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const root = process.argv[2];
const src = fs.readFileSync(process.env.SITE_JS || path.join(root, 'site.js'), 'utf8');

const context = {
  window: { matchMedia: () => ({ matches: false }) },
  document: {
    querySelector: () => null,
    querySelectorAll: () => [],
    addEventListener: () => {},
    documentElement: { clientWidth: 0, scrollHeight: 0, style: {} },
    body: { appendChild: () => {} },
  },
  module: { exports: {} },
};
vm.runInNewContext(src, context);
const api = context.module.exports;

assert.strictEqual(typeof api.markerLen, 'function', 'site.js exports markerLen');
console.log('PASS  site.js exports the pure scroll-progress function');

// Zigzag fixture like the real page: vertical rails joined by long
// horizontal runs (up to 900px wide against 300-700px of vertical travel).
const vh = 900;
const pts = [[200, 1200]];
const xs = [1100, 200, 1100, 200, 1100, 200];
const ys = [1900, 2300, 3100, 3500, 4200, 4900];
xs.forEach((x, i) => {
  const last = pts[pts.length - 1];
  pts.push([last[0], ys[i]]);      // vertical rail
  pts.push([x, ys[i]]);            // long horizontal run
});
pts.push([pts[pts.length - 1][0], 5200]);
const scrollHeight = 5200 + 300;
const lineTop = pts[0][1];
const first = pts[0];
const last = pts[pts.length - 1];

// Arc length -> point, same metric as site.js.
const cum = [0];
for (let i = 1; i < pts.length; i += 1) {
  const dx = Math.abs(pts[i][0] - pts[i - 1][0]);
  const dy = Math.abs(pts[i][1] - pts[i - 1][1]);
  cum.push(cum[i - 1] + dx + dy - Math.min(dx, dy) * 0.586);
}
function pointAt(len) {
  let i = 1;
  while (i < cum.length - 1 && cum[i] < len) i += 1;
  const t = Math.min(1, Math.max(0, (len - cum[i - 1]) / (cum[i] - cum[i - 1] || 1)));
  return [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * t, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * t];
}

const startSy = lineTop - vh;
const endSy = scrollHeight - vh;
let prev = -1;
let steps = 0;
const span = endSy - startSy;
for (let sy = startSy; sy <= endSy; sy += 5) {
  const len = api.markerLen(vh, sy, scrollHeight, pts);
  const y = pointAt(len)[1];
  assert(y >= sy - 1e-6 && y <= sy + vh + 1e-6, 'marker y ' + y + ' outside viewport [' + sy + ', ' + (sy + vh) + ']');
  const p = (sy - startSy) / span;
  if (p > 0 && p < 1) assert(len > prev, 'arc length must strictly increase inside (0,1), sy=' + sy + ' len=' + len + ' prev=' + prev);
  else assert(len >= prev - 1e-9, 'marker moved backwards at sy=' + sy);
  // (d) comfortable band: middle 70% of progress keeps the marker at
  // 0.25..0.8 of the viewport height, not hugging an edge.
  if (p >= 0.15 && p <= 0.85) {
    const f = (y - sy) / vh;
    assert(f >= 0.25 - 1e-6 && f <= 0.8 + 1e-6, 'marker at ' + f.toFixed(2) + ' of the viewport (p=' + p.toFixed(2) + ') is outside 0.25..0.8');
  }
  prev = len;
  steps += 1;
}
console.log('PASS  marker y is inside the viewport at all ' + steps + ' scroll steps');
console.log('PASS  arc length strictly increases while progress is inside (0,1)');
console.log('PASS  marker sits in the 0.25..0.8 viewport band for the middle 70% of progress');

const atStart = pointAt(api.markerLen(vh, startSy, scrollHeight, pts));
assert(atStart[0] === first[0] && atStart[1] === first[1], 'marker starts at the first point, got ' + atStart);
const atEnd = pointAt(api.markerLen(vh, endSy, scrollHeight, pts));
assert(Math.abs(atEnd[0] - last[0]) < 1e-6 && Math.abs(atEnd[1] - last[1]) < 1e-6, 'marker ends at the last point, got ' + atEnd);
assert(api.markerLen(vh, startSy - 500, scrollHeight, pts) === 0, 'marker holds at the start before the line appears');
assert(Math.abs(api.markerLen(vh, endSy + 500, scrollHeight, pts) - cum[cum.length - 1]) < 1e-9, 'marker holds at the end past the page bottom');
console.log('PASS  marker starts at the first point and ends at the last point at page bottom');

// Horizontal runs are not jumped: no single 5px scroll step moves the marker
// by more than a 900px run at once.
let maxJump = 0;
let p0 = api.markerLen(vh, startSy, scrollHeight, pts);
for (let sy = startSy + 5; sy <= endSy; sy += 5) {
  const p1 = api.markerLen(vh, sy, scrollHeight, pts);
  maxJump = Math.max(maxJump, p1 - p0);
  p0 = p1;
}
assert(maxJump < 300, 'marker jumps ' + maxJump + 'px of arc length in one 5px step');
console.log('PASS  horizontal runs take a scroll stretch (max step ' + maxJump.toFixed(1) + ' arc px per 5px)');

// A line already on screen at load starts at its first point at scroll 0 and
// still ends at the last point; a line that ends above the page bottom stays
// in view too.
const shortPts = [[100, 360], [100, 900], [900, 900], [900, 2000]];
const shortHeight = 2450;
const s0 = pointAt0(shortPts, api.markerLen(vh, 0, shortHeight, shortPts));
assert(s0[0] === 100 && s0[1] === 360, 'a line visible at load starts at its first point, got ' + s0);
for (let sy = 0; sy <= shortHeight - vh; sy += 5) {
  const y = pointAt0(shortPts, api.markerLen(vh, sy, shortHeight, shortPts))[1];
  assert(y >= sy - 1e-6 && y <= sy + vh + 1e-6, 'short line: marker y ' + y + ' outside viewport at sy=' + sy);
}
console.log('PASS  a line visible at load, or ending above the page bottom, keeps the marker in view');

// Regression (Rex, PR 213): how-it-works, skills and pricing show the line at
// load (first point 75px from the top) with an early horizontal run and then
// a tall vertical stretch. The marker must stay below the 67px sticky header
// (z-index above the marker) for the middle 70% of progress.
const hiw = [[300, 75], [300, 140], [1000, 140], [1000, 900], [300, 900], [300, 1800], [1000, 1800], [1000, 2600]];
const hiwHeight = 3100;
const hiwEnd = hiwHeight - vh;
for (let sy = 0; sy <= hiwEnd; sy += 5) {
  const pr = sy / hiwEnd;
  const y = pointAt0(hiw, api.markerLen(vh, sy, hiwHeight, hiw))[1];
  assert(y >= sy - 1e-6 && y <= sy + vh + 1e-6, 'how-it-works: marker y ' + y + ' outside viewport at sy=' + sy);
  if (pr >= 0.15 && pr <= 0.85) assert(y - sy >= 67 - 1e-6, 'how-it-works: marker ' + (y - sy).toFixed(1) + 'px from the viewport top (under the 67px header) at sy=' + sy);
}
assert.strictEqual(api.markerLen(vh, 0, 2, [[1, 1]]), 0, 'a single point returns 0, not NaN');
console.log('PASS  a line on screen at load keeps the marker below the sticky header');

function pointAt0(p, len) {
  const c = [0];
  for (let i = 1; i < p.length; i += 1) {
    const dx = Math.abs(p[i][0] - p[i - 1][0]);
    const dy = Math.abs(p[i][1] - p[i - 1][1]);
    c.push(c[i - 1] + dx + dy - Math.min(dx, dy) * 0.586);
  }
  let i = 1;
  while (i < c.length - 1 && c[i] < len) i += 1;
  const t = Math.min(1, Math.max(0, (len - c[i - 1]) / (c[i] - c[i - 1] || 1)));
  return [p[i - 1][0] + (p[i][0] - p[i - 1][0]) * t, p[i - 1][1] + (p[i][1] - p[i - 1][1]) * t];
}
NODE
then
  printf 'PASS  Marker scroll-progress tests\n'
else
  printf 'FAIL  Marker scroll-progress tests\n'
  exit 1
fi
