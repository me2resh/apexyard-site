#!/usr/bin/env bash
# #206 (owner comment, 21 Nov 2026): the moving line's #4242 marker should ride
# at one third of the viewport height (33vh) as soon as the line is on screen,
# and stay there while the line runs. It may only move off that point before
# the line reaches 33vh (the very start) and after the line ends above 33vh
# (the very end).
#
# site.js has no DOM in CI, so this loads it with a minimal window/document
# stub (vm.runInNewContext, same approach as test-waitlist.sh) and exercises
# anchorDocY(), the pure part of the one-third rule PR #205 introduced: given
# a viewport height, a scroll position and the line's own top/bottom in page
# coordinates, it returns the document Y the marker should sit at. Before the
# #206 fix this function did not exist (readTarget() instead pinned its first
# interpolation point to a hardcoded vh/3 "page position" that had nothing to
# do with where the line actually was, which is why the marker rode near the
# bottom of the viewport through most of the page and only reached 33vh near
# the end of the track) -- so this test fails on the old site.js and passes
# on the fixed one.
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

assert.strictEqual(typeof api.anchorDocY, 'function', 'site.js exports anchorDocY');
assert.strictEqual(api.ANCHOR, 1 / 3, 'the anchor is one third of the viewport');
console.log('PASS  site.js exports the pure marker-anchor function');

// A representative page: the line (the "Track" SVG the marker rides) starts
// just under the hero and ends near the bottom of the last section with a
// stop, roughly matching index.html's measured layout at a 900px viewport.
const vh = 900;
const lineTop = 1200;    // where the line starts, right after the hero
const lineBottom = 3600; // where the line ends, near the last section

function expectAnchor(label, sy) {
  const got = api.anchorDocY(vh, sy, lineTop, lineBottom);
  const want = sy + vh * api.ANCHOR;
  assert.strictEqual(got, want, label + ': marker should sit at scrollY + vh/3');
  const viewportFrac = (got - sy) / vh;
  assert(Math.abs(viewportFrac - 1 / 3) < 1e-9, label + ': marker should be at 33% of the viewport, got ' + viewportFrac);
  console.log('PASS  ' + label + ' keeps the marker at 33vh (scrollY=' + sy + ')');
}

// The top of the stats section entering the viewport: scrolled well past the
// line's start, well before its end.
expectAnchor('stats section entering the viewport', 2091);

// The install section (#open-source, "Install ApexYard").
expectAnchor('install section', 2599);

// Very start: the line has not reached 33vh yet, so the marker holds at the
// line's own top instead of sitting below the fold.
const beforeStart = api.anchorDocY(vh, 0, lineTop, lineBottom);
assert.strictEqual(beforeStart, lineTop, 'before the line reaches 33vh, the marker holds at the line start');
console.log('PASS  before the line reaches 33vh, the marker holds at the line start');

// Very end: the line already ended above 33vh, so the marker holds at the
// line's own bottom instead of chasing the fold past the end of the track.
const afterEnd = api.anchorDocY(vh, 10000, lineTop, lineBottom);
assert.strictEqual(afterEnd, lineBottom, 'after the line ends above 33vh, the marker holds at the line end');
console.log('PASS  after the line ends above 33vh, the marker holds at the line end');
NODE
then
  printf 'PASS  Marker anchor tests\n'
else
  printf 'FAIL  Marker anchor tests\n'
  exit 1
fi
