#!/usr/bin/env bash
# #208 (owner decision, 22 Nov 2026): the #4242 marker travels the WHOLE
# moving line in step with scroll progress. This replaces the #206/#207
# "hold the marker at 33vh" rule (see git history for test-marker-anchor.sh
# before this change).
#
# Scroll progress p is 0 when the line's first point first reaches the
# bottom of the viewport (scrollY === lineTop - innerHeight), and 1 when the
# page is scrolled to the bottom (scrollY === scrollHeight - innerHeight).
# p is clamped to [0, 1]. The marker sits at arc length p * total along the
# real measured path (the same pts/cum arc-length tables #178/#206 built),
# so it always moves while scrolling, its on-screen speed varies with how
# the line zigzags, and scrolling up moves it back.
#
# site.js has no DOM in CI, so this loads it with a minimal window/document
# stub (vm.runInNewContext, same approach as test-waitlist.sh) and exercises
# markerLen(), the pure part of the #208 rule: given a viewport height, a
# scroll position, the page's scrollHeight and the line's own top/bottom and
# total arc length in page coordinates, it returns the arc length the
# marker should sit at. Before the #208 fix this function did not exist
# (readTarget() instead held the marker at scrollY + vh/3 clamped to the
# line's extent, so the marker sat still at 33vh through most of the page
# instead of travelling the whole line) -- so this test fails on the old
# site.js and passes on the fixed one.
set -uo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if node - "$root" <<'NODE'
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const root = process.argv[2];
const src = fs.readFileSync(path.join(root, 'site.js'), 'utf8');

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

// A representative page: the line (the "Track" SVG the marker rides) starts
// just under the hero and ends near the bottom of the last section with a
// stop, roughly matching index.html's measured layout at a 900px viewport.
const vh = 900;
const lineTop = 1200;     // where the line starts, right after the hero
const lineBottom = 3600;  // where the line ends, near the last section
const total = 4800;       // the real (zigzagging) arc length of the track
const scrollHeight = 4300; // the whole page is taller than the line alone

// Progress is 0 when the line's first point first reaches the bottom of the
// viewport: scrollY = lineTop - vh.
const firstAppearance = lineTop - vh;
// Progress is 1 when the page is scrolled to the bottom: scrollY = scrollHeight - vh.
const pageBottom = scrollHeight - vh;
const midScroll = (firstAppearance + pageBottom) / 2;

function lenAt(sy) {
  return api.markerLen(vh, sy, scrollHeight, lineTop, lineBottom, total);
}

// p = 0 at first appearance -> the marker sits at the first point (arc length 0).
const atStart = lenAt(firstAppearance);
assert.strictEqual(atStart, 0, 'marker is at the line start when the line first appears');
console.log('PASS  marker is at arc length 0 when the line first comes into view');

// Before the line appears at all, progress stays clamped at 0 (the marker
// does not run ahead of the line reaching the fold).
const beforeAppearance = lenAt(firstAppearance - 500);
assert.strictEqual(beforeAppearance, 0, 'marker holds at the line start before the line appears');
console.log('PASS  marker holds at arc length 0 before the line appears');

// Middle of the scroll range -> half the total arc length.
const atMiddle = lenAt(midScroll);
assert(Math.abs(atMiddle - total / 2) < 1e-9, 'marker is at half the line length at the midpoint, got ' + atMiddle);
console.log('PASS  marker is at half the line length at the midpoint of the scroll range');

// Page bottom -> the last point (the full arc length).
const atBottom = lenAt(pageBottom);
assert.strictEqual(atBottom, total, 'marker is at the line end when the page is scrolled to the bottom');
console.log('PASS  marker is at the full line length when the page is scrolled to the bottom');

// Past the page bottom, progress stays clamped at 1 (no overshoot).
const pastBottom = lenAt(pageBottom + 500);
assert.strictEqual(pastBottom, total, 'marker holds at the line end past the page bottom');
console.log('PASS  marker holds at the full line length past the page bottom');

// Scrolling up reverses the marker: a point further up the page must give a
// strictly smaller arc length than a point further down, at every step.
const samples = [firstAppearance, firstAppearance + (pageBottom - firstAppearance) * 0.25, midScroll,
  firstAppearance + (pageBottom - firstAppearance) * 0.75, pageBottom].map(lenAt);
for (let i = 1; i < samples.length; i += 1) {
  assert(samples[i] > samples[i - 1], 'arc length must strictly increase with scrollY, got ' + samples.join(','));
}
for (let i = samples.length - 1; i > 0; i -= 1) {
  assert(samples[i - 1] < samples[i], 'scrolling back up must move the marker back, got ' + samples.join(','));
}
console.log('PASS  the marker moves forward while scrolling down and back while scrolling up');

// A quarter of the way down the scroll range sits at a quarter of the line
// length too: the marker speed is linear in scroll progress, not held still
// at a fixed viewport position (the #206/#207 rule this replaces).
const quarterScroll = firstAppearance + (pageBottom - firstAppearance) * 0.25;
const atQuarter = lenAt(quarterScroll);
assert(Math.abs(atQuarter - total * 0.25) < 1e-9, 'marker is at a quarter of the line length a quarter through the scroll range, got ' + atQuarter);
console.log('PASS  marker position tracks scroll progress linearly, not a fixed viewport spot');

// A line already on screen at load (its top above the fold, as on
// /how-it-works) starts at the first point at scroll 0 (Rex review
// 6011401939), and still reaches the end at the page bottom.
const shortTop = vh * 0.4;
const shortBottom = shortTop + 2000;
const shortHeight = shortBottom + vh * 0.5;
const atLoad = api.markerLen(vh, 0, shortHeight, shortTop, shortBottom, total);
assert(atLoad === 0, 'a line visible at load starts at arc length 0, got ' + atLoad);
const atEnd = api.markerLen(vh, shortHeight - vh, shortHeight, shortTop, shortBottom, total);
assert(Math.abs(atEnd - total) < 1e-9, 'a line visible at load ends at the full length, got ' + atEnd);
console.log('PASS  a line already on screen at load starts at its first point');
NODE
then
  printf 'PASS  Marker scroll-progress tests\n'
else
  printf 'FAIL  Marker scroll-progress tests\n'
  exit 1
fi
