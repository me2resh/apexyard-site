/* ApexYard home (#102): the rule map. One rule travels from stage to stage:
   the rule, Build, the Gate, Readiness, and a miss that comes back as a new
   rule. Each stage shows one sentence in plain words.

   - Without JavaScript, or with prefers-reduced-motion: reduce, the page
     shows the five stages as a static list. Nothing moves.
   - With motion, the list becomes a set of tabs on a loop. When the map
     comes into view, the rule travels the loop once and the selected stage
     advances with it.
   - The tour runs only while the map is in view. Hover and the pause
     button pause it. Focus, a press or a key in the map, and leaving the
     view stop it. The tour never moves focus and never scrolls the page.
   - Scroll cost: the token is a small HTML element that moves with a
     transform (Web Animations API), so the compositor runs it. The stage
     positions and the line are measured once per layout, never per frame.
     The line lights one leg per stage, not per frame.
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
  if (tabs.length !== panels.length || items.length !== panels.length) return;

  var reduce = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
  if ((reduce && reduce.matches) || !token.animate) return; // the static list stays

  /* ---------- tabs (WAI-ARIA tabs pattern, horizontal) ---------- */
  list.setAttribute('role', 'tablist');
  list.setAttribute('aria-label', 'Stages of one rule');
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

  var current = 0;
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

  /* ---------- the line, measured once per layout ---------- */
  var legs = [];  // per leg: { pts: [{x, y}], len, path }
  var homes = []; // per stage: {x, y}

  function rect(el, box) {
    var r = el.getBoundingClientRect();
    return { x: r.left - box.left + r.width / 2, y: r.top - box.top + r.height / 2, top: r.top - box.top, bottom: r.bottom - box.top };
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

  function layout() {
    var box = board.getBoundingClientRect();
    if (!box.width) return false;
    svg.setAttribute('viewBox', '0 0 ' + box.width + ' ' + box.height);
    svg.setAttribute('width', box.width);
    svg.setAttribute('height', box.height);

    var c = tabs.map(function (tab) { return rect(tab, box); });
    var last = c.length - 1; // the "miss" stage closes the loop
    var row = Math.abs(c[0].y - c[1].y) < 4; // the row layout
    var pts = [c[0]];
    var stageAt = [0];
    var i;
    root.classList.toggle('is-row', row); // set per layout, never during the tour
    if (row) {
      for (i = 1; i < last; i++) { pts.push(c[i]); stageAt.push(pts.length - 1); }
      var low = c[last].y;
      pts.push({ x: c[last - 1].x, y: low });
      pts.push(c[last]); stageAt.push(pts.length - 1);
      pts.push({ x: c[0].x, y: low });
      // The sentence sits inside the loop.
      var off = box.top - root.getBoundingClientRect().top;
      var top = Math.max(c[0].bottom, c[1].bottom, c[2].bottom, c[3].bottom) + 20;
      var bottom = c[last].top - 20;
      var left = c[0].x + 28;
      var right = c[last - 1].x - 28;
      root.style.setProperty('--says-top', (top + off) + 'px');
      root.style.setProperty('--says-left', left + 'px');
      root.style.setProperty('--says-w', Math.max(0, right - left) + 'px');
      root.style.setProperty('--says-h', Math.max(0, bottom - top) + 'px');
    } else {
      for (i = 1; i <= last; i++) { pts.push(c[i]); stageAt.push(pts.length - 1); }
      var side = box.width - 12;
      pts.push({ x: side, y: c[last].y });
      pts.push({ x: side, y: c[0].y });
    }
    pts.push({ x: c[0].x, y: c[0].y });
    stageAt.push(pts.length - 1); // the loop end is the rule again

    track.setAttribute('d', route(pts, 18));
    homes = c.map(function (p) { return { x: p.x, y: p.y }; });

    // One lit path per leg. Each lights once, when the token arrives.
    while (legsG.firstChild) legsG.removeChild(legsG.firstChild);
    legs = [];
    for (i = 0; i < stageAt.length - 1; i++) {
      var lp = pts.slice(stageAt[i], stageAt[i + 1] + 1).map(function (p) { return { x: p.x, y: p.y }; });
      var len = 0;
      for (var k = 1; k < lp.length; k++) len += Math.hypot(lp[k].x - lp[k - 1].x, lp[k].y - lp[k - 1].y);
      var path = document.createElementNS(SVGNS, 'path');
      path.setAttribute('class', 'rule-map__leg');
      path.setAttribute('d', route(lp, 18));
      legsG.appendChild(path);
      legs.push({ pts: lp, len: len, path: path });
    }
    return true;
  }

  function put(p) { token.style.transform = 'translate(' + p.x + 'px, ' + p.y + 'px)'; }

  // Lit legs: the legs before stage n (n = 5 lights the whole loop).
  function light(n) {
    legs.forEach(function (leg, i) { leg.path.classList.toggle('is-lit', i < n); });
    stages.forEach(function (li, i) { li.classList.toggle('is-lit', i <= Math.min(n, stages.length - 1)); });
  }

  /* ---------- the tour ---------- */
  var DWELL = 2600; // ms on each stage
  var TRAVEL = 900; // ms from one stage to the next
  var state = 'idle'; // idle, running, stopped, done
  var leg = 0;        // the next leg to travel, from stage leg
  var timer = null;
  var dwellLeft = DWELL;
  var dwellFrom = 0;
  var anim = null;
  var paused = { user: false, hover: false };
  var ran = false; // the tour has started at least once

  function isPaused() { return paused.user || paused.hover; }

  function setControl() {
    if (state === 'stopped' || state === 'done') {
      control.textContent = ran ? 'Play the loop again' : 'Play the loop';
      control.setAttribute('aria-pressed', 'false');
    } else {
      control.textContent = paused.user ? 'Play the loop' : 'Pause the loop';
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
    var at = leg % stages.length;
    put(homes[at]);
    light(leg);
    select(at, false);
    if (leg >= legs.length) { // back at the rule: the loop is closed
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
    select(0, false);
    put(homes[0]);
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
    light(current);
    setControl();
  }

  function stopAt(index) {
    clearAll();
    state = 'stopped';
    put(homes[index]);
    light(index);
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
  select(0, false);
  if (!layout()) return;
  put(homes[0]);
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

  // A new layout (resize, font load) measures the line again and puts the
  // token on the stage on show. A leg in progress ends at its stage.
  var redraw = function () {
    var moving = !!anim;
    if (anim) { anim.onfinish = null; anim.cancel(); anim = null; }
    if (!layout()) return;
    if (moving) { arrive(); return; }
    put(homes[state === 'done' ? 0 : current]);
    light(state === 'done' ? legs.length : (state === 'running' ? leg : current));
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
