/* ApexYard home (#102): the rule map. Keel is the hub. One rule travels
   from the developers into Keel, out to Build, the Gate and Readiness, and
   back into Keel as a new rule after a miss. Each stage shows one sentence
   in plain words.

   - Without JavaScript, or with prefers-reduced-motion: reduce, the page
     shows the six stages as a static list. Nothing moves.
   - With motion, the list becomes a set of tabs on a hub. When the map
     comes into view, the rule travels the loop once and the selected stage
     advances with it.
   - The tour runs only while the map is in view. Hover and the pause
     button pause it. Focus, a press or a key in the map, and leaving the
     view stop it. The tour never moves focus and never scrolls the page.
   - Scroll cost: the token is a small HTML element that moves with a
     transform (Web Animations API), so the compositor runs it. The stage
     positions and the lines are measured once per layout, never per frame.
     The lines light one leg per stage, not per frame.
   - All sentences share one grid cell, so the map height does not change
     with the stage. No class that changes size or layout changes during
     the tour.
   No dependencies. */
(function () {
  'use strict';

  var root = document.querySelector('[data-rule-map]');
  if (!root || !root.querySelector) return;

  var SVGNS = 'http://www.w3.org/2000/svg';
  var board = root.querySelector('.rule-map__board');
  var svg = root.querySelector('.rule-map__svg');
  var track = root.querySelector('.rule-map__track');
  var legsG = root.querySelector('.rule-map__legs');
  var token = root.querySelector('.rule-map__token');
  var list = root.querySelector('.rule-map__stages');
  var says = root.querySelector('.rule-map__says');
  var control = root.querySelector('.rule-map__control');
  var stages = Array.prototype.slice.call(root.querySelectorAll('.rule-map__stage'));
  var tabs = Array.prototype.slice.call(root.querySelectorAll('.rule-map__btn'));
  var items = Array.prototype.slice.call(root.querySelectorAll('.rule-map__item'));
  var panels = Array.prototype.slice.call(root.querySelectorAll('.rule-map__say'));
  if (!board || !svg || !track || !legsG || !token || !list || !says || !control) return;
  if (tabs.length !== 6 || panels.length !== 6 || items.length !== 6) return;

  var reduce = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
  if ((reduce && reduce.matches) || !token.animate) return; // the static list stays

  // Stage order in the page: developers, Keel, Build, Gate, Readiness, a miss.
  var DEV = 0, KEEL = 1, BUILD = 2, GATE = 3, READY = 4, MISS = 5;
  // The tour visits each stage once, then the miss goes back into Keel.
  var VISIT = [DEV, KEEL, BUILD, GATE, READY, MISS, KEEL];
  var LEGS = VISIT.length - 1;
  // The first leg count that reaches each stage.
  function reach(stage) { return VISIT.indexOf(stage); }

  /* ---------- tabs (WAI-ARIA tabs pattern, horizontal) ---------- */
  list.setAttribute('role', 'tablist');
  list.setAttribute('aria-label', 'How one rule moves through Keel');
  list.setAttribute('aria-orientation', 'horizontal');
  says.setAttribute('role', 'none');
  stages.forEach(function (li) { li.setAttribute('role', 'presentation'); });
  items.forEach(function (li) { li.setAttribute('role', 'none'); });
  tabs.forEach(function (tab, i) {
    var panel = panels[i];
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-controls', panel.id);
    panel.setAttribute('role', 'tabpanel');
    panel.setAttribute('aria-labelledby', tab.id);
    panel.setAttribute('tabindex', '0');
  });

  var current = DEV;
  function select(index, focus) {
    current = index;
    tabs.forEach(function (tab, i) {
      var on = i === index;
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
      tab.tabIndex = on ? 0 : -1;
      // Visibility and opacity only: the grid cell keeps its height.
      items[i].classList.toggle('is-off', !on);
      if (on) panels[i].removeAttribute('aria-hidden');
      else panels[i].setAttribute('aria-hidden', 'true');
    });
    if (focus) tabs[index].focus(); // user keys only, never the tour
  }

  /* ---------- the lines, measured once per layout ---------- */
  var legs = [];  // per leg: { pts: [{x, y}], len, path }
  var homes = []; // per stage: {x, y}

  function rect(el, box) {
    var r = el.getBoundingClientRect();
    return {
      x: r.left - box.left + r.width / 2, y: r.top - box.top + r.height / 2,
      top: r.top - box.top, bottom: r.bottom - box.top
    };
  }

  // A rounded polyline through axis-aligned points.
  function route(points, radius) {
    var d = 'M' + points[0].x + ' ' + points[0].y;
    for (var i = 1; i < points.length; i++) {
      var p = points[i];
      var n = points[i + 1];
      if (!n) { d += ' L' + p.x + ' ' + p.y; break; }
      var prev = points[i - 1];
      var inLen = Math.hypot(p.x - prev.x, p.y - prev.y);
      var outLen = Math.hypot(n.x - p.x, n.y - p.y);
      var rr = Math.min(radius, inLen / 2, outLen / 2);
      if (!inLen || !outLen || rr <= 0) { d += ' L' + p.x + ' ' + p.y; continue; }
      var ax = p.x - (p.x - prev.x) / inLen * rr;
      var ay = p.y - (p.y - prev.y) / inLen * rr;
      var bx = p.x + (n.x - p.x) / outLen * rr;
      var by = p.y + (n.y - p.y) / outLen * rr;
      d += ' L' + ax + ' ' + ay + ' Q' + p.x + ' ' + p.y + ' ' + bx + ' ' + by;
    }
    return d;
  }

  // Drop points that repeat the one before, so no leg has a zero-length step.
  function clean(points) {
    return points.filter(function (p, i) {
      var q = points[i - 1];
      return !q || Math.abs(p.x - q.x) > 0.5 || Math.abs(p.y - q.y) > 0.5;
    });
  }

  function layout() {
    var box = board.getBoundingClientRect();
    if (!box.width) return false;
    svg.setAttribute('viewBox', '0 0 ' + box.width + ' ' + box.height);
    svg.setAttribute('width', box.width);
    svg.setAttribute('height', box.height);

    var c = tabs.map(function (tab) { return rect(tab, box); });
    var side = box.width - 14; // the return line on the right edge
    // The hub layout: Build, the Gate and Readiness start on the same line.
    // Compare the tops, not the centres, so a wrapped label cannot hide it.
    var hub = Math.abs(c[BUILD].top - c[GATE].top) < 4 && Math.abs(c[BUILD].top - c[READY].top) < 4;
    root.classList.toggle('is-row', hub); // set per layout, never during the tour

    homes = c.map(function (p) { return { x: p.x, y: p.y }; });
    var h = homes;
    var paths;
    if (hub) {
      // Top row: developers, Keel, a miss. Their centres share Keel's line.
      h[DEV].y = h[KEEL].y;
      h[MISS].y = h[KEEL].y;
      // Gate sits under Keel: one straight trunk.
      h[GATE].x = h[KEEL].x;
      // The bus runs between the two rows.
      var bus = (Math.max(c[DEV].bottom, c[KEEL].bottom, c[MISS].bottom) + Math.min(c[BUILD].top, c[GATE].top, c[READY].top)) / 2;
      paths = [
        [h[DEV], h[KEEL]],
        [h[KEEL], { x: h[KEEL].x, y: bus }, { x: h[BUILD].x, y: bus }, h[BUILD]],
        [h[BUILD], { x: h[BUILD].x, y: bus }, { x: h[GATE].x, y: bus }, h[GATE]],
        [h[GATE], { x: h[GATE].x, y: bus }, { x: h[READY].x, y: bus }, h[READY]],
        [h[READY], { x: side, y: h[READY].y }, { x: side, y: h[MISS].y }, h[MISS]],
        [h[MISS], h[KEEL]]
      ];
    } else {
      // A column: down through each stage, then up the right edge to Keel.
      for (var s = 0; s < h.length; s++) h[s].x = h[DEV].x;
      paths = [
        [h[DEV], h[KEEL]],
        [h[KEEL], h[BUILD]],
        [h[BUILD], h[GATE]],
        [h[GATE], h[READY]],
        [h[READY], h[MISS]],
        [h[MISS], { x: side, y: h[MISS].y }, { x: side, y: h[KEEL].y }, h[KEEL]]
      ];
    }

    // One grey track and one lit path per leg. Each lights once, when the
    // token arrives.
    var all = [];
    while (legsG.firstChild) legsG.removeChild(legsG.firstChild);
    legs = paths.map(function (raw) {
      var pts = clean(raw.map(function (p) { return { x: p.x, y: p.y }; }));
      var len = 0;
      for (var k = 1; k < pts.length; k++) len += Math.hypot(pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y);
      var d = route(pts, 18);
      all.push(d);
      var path = document.createElementNS(SVGNS, 'path');
      path.setAttribute('class', 'rule-map__leg');
      path.setAttribute('d', d);
      legsG.appendChild(path);
      return { pts: pts, len: len, path: path };
    });
    track.setAttribute('d', all.join(' '));
    return true;
  }

  function put(p) { token.style.transform = 'translate(' + p.x + 'px, ' + p.y + 'px)'; }

  // Lit legs: the first n legs. n = LEGS lights the whole loop.
  function light(n) {
    var seen = {};
    for (var v = 0; v <= Math.min(n, LEGS); v++) seen[VISIT[v]] = true;
    legs.forEach(function (leg, i) { leg.path.classList.toggle('is-lit', i < n); });
    stages.forEach(function (li, i) { li.classList.toggle('is-lit', !!seen[i]); });
  }

  /* ---------- the tour ---------- */
  var DWELL = 2600; // ms on each stage
  var TRAVEL = 900; // ms from one stage to the next
  var state = 'idle'; // idle, running, stopped, done
  var leg = 0;        // legs travelled so far; the token is at VISIT[leg]
  var timer = null;
  var dwellLeft = DWELL;
  var dwellFrom = 0;
  var anim = null;
  var paused = { user: false, hover: false };
  var ran = false; // the tour has started at least once

  function isPaused() { return paused.user || paused.hover; }

  function setControl() {
    // While the tour runs, the button is a toggle with a fixed label and
    // aria-pressed. When the tour has stopped, it is a plain action button.
    if (state === 'stopped' || state === 'done') {
      control.textContent = ran ? 'Play the loop again' : 'Play the loop';
      control.removeAttribute('aria-pressed');
    } else {
      control.textContent = 'Pause the loop';
      control.setAttribute('aria-pressed', paused.user ? 'true' : 'false');
    }
  }

  function clearAll() {
    if (timer) { clearTimeout(timer); timer = null; }
    if (anim) { anim.onfinish = null; anim.cancel(); anim = null; }
  }

  function dwell() {
    dwellFrom = Date.now();
    if (isPaused()) return; // resume() starts the timer
    timer = setTimeout(travel, dwellLeft);
  }

  function travel() {
    timer = null;
    var l = legs[leg];
    if (!l) return;
    var acc = 0;
    var frames = l.pts.map(function (p, k) {
      if (k) acc += Math.hypot(p.x - l.pts[k - 1].x, p.y - l.pts[k - 1].y);
      return { transform: 'translate(' + p.x + 'px, ' + p.y + 'px)', offset: l.len ? acc / l.len : k / (l.pts.length - 1) };
    });
    anim = token.animate(frames, { duration: TRAVEL, easing: 'ease-in-out', fill: 'forwards' });
    if (isPaused()) anim.pause();
    anim.onfinish = arrive;
  }

  function arrive() {
    if (anim) { anim.onfinish = null; anim.cancel(); anim = null; }
    leg += 1;
    var at = VISIT[leg];
    put(homes[at]);
    light(leg);
    select(at, false);
    if (leg >= LEGS) { // back in Keel: the loop is closed
      state = 'done';
      setControl();
      return;
    }
    dwellLeft = DWELL;
    dwell();
  }

  function pause() {
    if (state !== 'running') return;
    if (timer) { clearTimeout(timer); timer = null; dwellLeft = Math.max(0, dwellLeft - (Date.now() - dwellFrom)); }
    if (anim) anim.pause();
  }

  function resume() {
    if (state !== 'running' || isPaused()) return;
    if (anim) anim.play();
    else if (!timer) dwell();
  }

  function start() {
    if (!layout()) return;
    clearAll();
    state = 'running';
    ran = true;
    leg = 0;
    paused.user = false;
    dwellLeft = DWELL;
    select(VISIT[0], false);
    put(homes[VISIT[0]]);
    light(0);
    setControl();
    dwell();
  }

  // Stop at the stage on show. Never moves focus.
  function halt() {
    if (state === 'idle') { state = 'stopped'; setControl(); return; } // input came first: no tour
    if (state !== 'running') return;
    clearAll();
    state = 'stopped';
    put(homes[current]);
    light(leg);
    setControl();
  }

  function stopAt(index) {
    clearAll();
    state = 'stopped';
    put(homes[index]);
    light(reach(index));
    setControl();
  }

  tabs.forEach(function (tab, i) {
    tab.addEventListener('click', function () { select(i, false); stopAt(i); });
    tab.addEventListener('keydown', function (e) {
      var next = -1;
      // A horizontal tab list: Up and Down stay with the page scroll.
      if (e.key === 'ArrowRight') next = (i + 1) % tabs.length;
      else if (e.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
      else if (e.key === 'Home') next = 0;
      else if (e.key === 'End') next = tabs.length - 1;
      if (next < 0) return;
      e.preventDefault();
      select(next, true);
      stopAt(next);
    });
  });

  control.addEventListener('click', function () {
    if (state === 'running') {
      paused.user = !paused.user;
      if (paused.user) pause(); else resume();
      setControl();
      return;
    }
    start();
  });

  // Hover pauses. Focus, a press or a key in the map stops the tour. The
  // pause button sits outside these areas, so it can always restart it.
  [board, says].forEach(function (el) {
    el.addEventListener('mouseenter', function () { paused.hover = true; pause(); });
    el.addEventListener('mouseleave', function () { paused.hover = false; resume(); });
    el.addEventListener('focusin', halt);
    el.addEventListener('pointerdown', halt);
    el.addEventListener('keydown', halt);
  });

  /* ---------- switch on ---------- */
  root.classList.add('is-live');
  control.hidden = false;
  select(VISIT[0], false);
  if (!layout()) return;
  put(homes[VISIT[0]]);
  light(0);
  setControl();

  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting && state === 'idle') start();
        else if (!entry.isIntersecting && state === 'running') halt(); // out of view: the tour stops
      });
    }, { threshold: 0.4 }).observe(board);
  }
  // Without IntersectionObserver the tour does not start by itself. The
  // stages and the play button still work.

  // With reduced motion switched on later, stop and show the static list.
  if (reduce && reduce.addEventListener) {
    reduce.addEventListener('change', function (e) {
      if (!e.matches) return;
      clearAll();
      state = 'stopped';
      root.classList.remove('is-live', 'is-row');
      control.hidden = true;
      list.removeAttribute('role');
      says.removeAttribute('role');
      items.forEach(function (li) { li.classList.remove('is-off'); li.removeAttribute('role'); });
      panels.forEach(function (p) { ['role', 'tabindex', 'aria-labelledby', 'aria-hidden'].forEach(function (a) { p.removeAttribute(a); }); });
    });
  }

  // A new layout (resize, font load) measures the lines again and puts the
  // token on the stage on show. A leg in progress ends at its stage.
  var redraw = function () {
    var moving = !!anim;
    if (anim) { anim.onfinish = null; anim.cancel(); anim = null; }
    if (!layout()) return;
    if (moving) { arrive(); return; }
    put(homes[state === 'done' ? KEEL : current]);
    light(state === 'done' ? LEGS : (state === 'running' ? leg : reach(current)));
  };
  if ('ResizeObserver' in window) {
    var lastW = 0;
    var lastH = 0;
    new ResizeObserver(function () {
      var r = board.getBoundingClientRect();
      if (Math.abs(r.width - lastW) < 1 && Math.abs(r.height - lastH) < 1) return;
      lastW = r.width;
      lastH = r.height;
      redraw();
    }).observe(board);
  } else {
    window.addEventListener('resize', redraw);
  }
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(redraw);
})();
