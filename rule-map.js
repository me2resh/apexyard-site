/* ApexYard home (#102): the rule map. One rule travels from the rule file
   through Build, the Gate and Readiness, and a miss comes back as a new
   rule. Each stage is a tab that shows one real example.

   - Without JavaScript, every example is visible and no line is drawn.
   - The line is drawn from the positions of the stage buttons, so one
     script serves the row layout and the column layout.
   - The token plays once, when the map scrolls into view, in under five
     seconds. With prefers-reduced-motion: reduce, the map shows the final
     state at once.
   No dependencies. */
(function () {
  'use strict';

  var root = document.querySelector('[data-rule-map]');
  if (!root || !root.querySelector) return;

  var board = root.querySelector('.rule-map__board');
  var svg = root.querySelector('.rule-map__svg');
  var track = root.querySelector('.rule-map__track');
  var trail = root.querySelector('.rule-map__trail');
  var token = root.querySelector('.rule-map__token');
  var stages = Array.prototype.slice.call(root.querySelectorAll('.rule-map__stage'));
  var tabs = Array.prototype.slice.call(root.querySelectorAll('.rule-map__btn'));
  var panels = Array.prototype.slice.call(root.querySelectorAll('.rule-map__example'));
  if (!board || !svg || !track || !trail || !token || tabs.length !== panels.length) return;

  /* ---------- tabs (WAI-ARIA tabs pattern) ---------- */
  var list = root.querySelector('.rule-map__stages');
  list.setAttribute('role', 'tablist');
  list.setAttribute('aria-label', 'Stages of one rule');
  stages.forEach(function (li) { li.setAttribute('role', 'presentation'); });
  tabs.forEach(function (tab, i) {
    var panel = panels[i];
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-controls', panel.id);
    panel.setAttribute('role', 'tabpanel');
    panel.setAttribute('aria-labelledby', tab.id);
    panel.setAttribute('tabindex', '0');
  });

  function select(index, focus) {
    tabs.forEach(function (tab, i) {
      var on = i === index;
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
      tab.tabIndex = on ? 0 : -1;
      panels[i].hidden = !on;
    });
    if (focus) tabs[index].focus();
  }

  tabs.forEach(function (tab, i) {
    tab.addEventListener('click', function () { select(i, false); });
    tab.addEventListener('keydown', function (e) {
      var next = -1;
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') next = (i + 1) % tabs.length;
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') next = (i - 1 + tabs.length) % tabs.length;
      else if (e.key === 'Home') next = 0;
      else if (e.key === 'End') next = tabs.length - 1;
      if (next < 0) return;
      e.preventDefault();
      select(next, true);
    });
  });
  select(0, false);
  root.classList.add('is-ready');

  /* ---------- the line ---------- */
  var stops = []; // path length at each stage, in travel order
  var total = 0;
  var played = false;
  var playing = false;

  function centre(el, box) {
    var r = el.getBoundingClientRect();
    return { x: r.left - box.left + r.width / 2, y: r.top - box.top + r.height / 2, r: r };
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

    var c = stages.map(function (li) { return centre(li.querySelector('.rule-map__btn'), box); });
    var last = c.length - 1; // the "miss" stage closes the loop
    var row = Math.abs(c[0].y - c[1].y) < 4; // the row layout
    var pts = [c[0]];
    var stageAt = [0];
    var i;
    if (row) {
      for (i = 1; i < last; i++) { pts.push(c[i]); stageAt.push(pts.length - 1); }
      var low = c[last].y;
      pts.push({ x: c[last - 1].x, y: low });
      pts.push(c[last]); stageAt.push(pts.length - 1);
      pts.push({ x: c[0].x, y: low });
    } else {
      for (i = 1; i <= last; i++) { pts.push(c[i]); stageAt.push(pts.length - 1); }
      var side = box.width - 10;
      pts.push({ x: side, y: c[last].y });
      pts.push({ x: side, y: c[0].y });
    }
    pts.push({ x: c[0].x, y: c[0].y });

    var d = route(pts, 18);
    track.setAttribute('d', d);
    trail.setAttribute('d', d);
    total = track.getTotalLength();

    // Path length at each stage: walk the corner points, then find the
    // nearest sampled point, so rounded corners do not shift a stop.
    stops = stageAt.map(function (k) {
      var target = pts[k];
      var best = 0;
      var bestD = Infinity;
      for (var s = 0; s <= total; s += 2) {
        var q = track.getPointAtLength(s);
        var dd = (q.x - target.x) * (q.x - target.x) + (q.y - target.y) * (q.y - target.y);
        if (dd < bestD) { bestD = dd; best = s; }
        if (bestD < 1 && dd > bestD + 40) break;
      }
      return best;
    });
    stops[0] = 0;
    stops.push(total);
    trail.style.strokeDasharray = total + ' ' + total;
    return true;
  }

  function place(len) {
    var p = track.getPointAtLength(Math.max(0, Math.min(total, len)));
    token.setAttribute('transform', 'translate(' + p.x + ' ' + p.y + ')');
    trail.style.strokeDashoffset = String(total - len);
  }

  function light(n) {
    stages.forEach(function (li, i) { li.classList.toggle('is-lit', i < n); });
  }

  function finalState() {
    playing = false;
    place(total);
    light(stages.length);
    root.classList.add('is-done');
  }

  function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }

  function play() {
    if (played || !layout()) return;
    played = true;
    playing = true;
    var LEG = 700;   // ms to travel from one stage to the next
    var HOLD = 140;  // ms at each stage
    var legs = stops.length - 1;
    var start = null;
    light(1);
    place(0);
    function frame(now) {
      if (!playing) return;
      if (start === null) start = now;
      var t = now - start;
      var leg = Math.floor(t / (LEG + HOLD));
      if (leg >= legs) { finalState(); return; }
      var within = t - leg * (LEG + HOLD);
      var k = within >= LEG ? 1 : ease(within / LEG);
      place(stops[leg] + (stops[leg + 1] - stops[leg]) * k);
      if (within >= LEG) light(Math.min(stages.length, leg + 2));
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)');
  if (!layout()) return;
  if ((reduce && reduce.matches) || !('IntersectionObserver' in window) || !window.requestAnimationFrame) {
    played = true;
    finalState();
  } else {
    place(0);
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { io.disconnect(); play(); }
      });
    }, { threshold: 0.45 });
    io.observe(board);
  }

  // A new layout (resize, font load) redraws the line. A running play keeps
  // going on the new line; a finished one shows the final state again.
  var redraw = function () {
    if (!layout()) return;
    if (playing) return;
    if (played) finalState(); else place(0);
  };
  if ('ResizeObserver' in window) {
    var lastW = board.getBoundingClientRect().width;
    var lastH = board.getBoundingClientRect().height;
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
