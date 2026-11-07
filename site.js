/* ApexYard, variation 1: Interlock.
   Nav, tabs, copy, consent, the track marker and the Home interlock.
   Every page reads complete with this file absent. */
(function () {
  'use strict';

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /* Pull request routes: filters and selection. */
  $$('.cloud').forEach(function (root) {
    var routes = $$('button[data-route]', root);
    if (!routes.length) return;
    var details = $$('[data-detail]', root);
    var filters = $$('[data-rfilter]', root);
    var empty = $('[data-rempty]', root);
    var pick = function (i) {
      routes.forEach(function (r) { r.setAttribute('aria-pressed', r.getAttribute('data-route') === String(i) ? 'true' : 'false'); });
      details.forEach(function (d) { d.hidden = d.getAttribute('data-detail') !== String(i); });
    };
    routes.forEach(function (r) {
      r.disabled = false;
      r.addEventListener('click', function () { pick(r.getAttribute('data-route')); });
    });
    filters.forEach(function (f) {
      f.disabled = false;
      f.addEventListener('click', function () {
        var key = f.getAttribute('data-rfilter');
        filters.forEach(function (o) { o.setAttribute('aria-pressed', o === f ? 'true' : 'false'); });
        var shown = routes.filter(function (r) {
          var on = key === 'all' || r.getAttribute('data-filter') === key;
          r.hidden = !on;
          return on;
        });
        empty.hidden = shown.length > 0;
        $('[data-rempty-d]', root).hidden = shown.length > 0;
        if (shown.length) pick(shown[0].getAttribute('data-route'));
        else details.forEach(function (d) { d.hidden = true; });
      });
    });
  });

  /* Review sizes: each key sets its route. */
  $$('[data-sizes]').forEach(function (root) {
    var rows = $$('[data-size]', root);
    rows.forEach(function (row) {
      var k = $('.size__key', row);
      k.disabled = false;
      k.addEventListener('click', function () {
        rows.forEach(function (r) {
          var on = r === row;
          r.classList.toggle('is-on', on);
          $('.size__key', r).setAttribute('aria-pressed', on ? 'true' : 'false');
        });
      });
    });
  });

  /* Pricing on phones: one plan at a time. */
  var pkeys = $('[data-pkeys]');
  if (pkeys) {
    var tables = $$('[data-pt]');
    var showPlan = function (p) {
      tables.forEach(function (t) { t.setAttribute('data-show', p); });
      $$('[data-pkey]', pkeys).forEach(function (k) { k.setAttribute('aria-pressed', k.getAttribute('data-pkey') === p ? 'true' : 'false'); });
    };
    pkeys.hidden = false;
    $$('[data-pkey]', pkeys).forEach(function (k) {
      k.addEventListener('click', function () { showPlan(k.getAttribute('data-pkey')); });
    });
    showPlan('Team');
  }

  /* Skills filter */
  var find = $('[data-skill-find]');
  if (find) {
    var input = $('#skill-filter');
    var count = $('[data-skill-count]');
    var all = $$('.skill');
    var groups = $$('.skills-sec');
    var none = document.createElement('p');
    none.className = 'skfind__none';
    find.hidden = false;
    var runFilter = function () {
      var q = input.value.trim().toLowerCase();
      var n = 0;
      all.forEach(function (s) {
        var on = !q || s.textContent.toLowerCase().indexOf(q) !== -1;
        s.hidden = !on;
        if (on) n += 1;
      });
      groups.forEach(function (g) {
        var c = $$('.skill', g).filter(function (s) { return !s.hidden; }).length;
        var b = $('.skg__count b', g);
        if (b) b.textContent = c;
        g.classList.toggle('is-empty', c === 0);
      });
      count.textContent = n + ' of ' + all.length + ' skills' + (n ? '' : '. No skill matches. Clear the filter or try another word.');
    };
    input.addEventListener('input', runFilter);
  }

  /* Track: read the real positions of rails and joins, then run one marker. */
  var secs = $$('.sec');
  var lit = null;
  var litPath = null;
  var marker = null;
  var pts = [];
  var cum = [];
  var total = 0;
  var stops = [];
  var heroStops = [];
  var heroEnd = 0;
  var heroPivot = -1;
  var heroAt = 0;
  var heroBottom = 0;
  var bands = [];
  var litFrom = 0;
  var litLen = 0;
  var held = false;
  var cur = 0;
  var target = 0;
  var raf = 0;
  var phone = window.matchMedia('(max-width: 1023px)');

  function docY(el) { return el.getBoundingClientRect().top + window.scrollY; }
  function docX(el) { return el.getBoundingClientRect().left + window.scrollX; }
  function midX(el) { return docX(el) + el.getBoundingClientRect().width / 2; }
  function midY(el) { return docY(el) + el.getBoundingClientRect().height / 2; }

  function measure() {
    pts = [];
    stops = [];
    heroStops = [];
    heroPivot = -1;
    var hero = $('[data-interlock]');
    if (!secs.length) return;
    var push = function (x, y) { pts.push([x, y]); };
    if (hero) {
      var conds = $$('.cond', hero);
      var sigs = conds.map(function (c) { return $('.cond__sig', c); });
      var blade = $('.jn__blade', hero);
      var bladeY = docY($('.jn', hero));
      var mainY = midY($('.plan__main', hero));
      var horizontal = !phone.matches;
      var sig0 = sigs[0];
      if (horizontal) {
        push(docX(sig0) - 46, bladeY);
        heroStops.push(pts.length - 1);
        for (var i = 1; i < sigs.length; i += 1) {
          push(docX(sigs[i]) - 46, bladeY);
          heroStops.push(pts.length - 1);
        }
        var pivot = docX($('.jn', hero)) + parseFloat(getComputedStyle(blade).left);
        push(pivot - 44, bladeY);
        heroStops.push(pts.length - 1);
        push(pivot, bladeY);
        heroPivot = pts.length - 1;
        var gy = bladeY - mainY;
        push(pivot + gy, mainY);
        push(pivot + gy + 44, mainY);
        heroStops.push(pts.length - 1);
      } else {
        var bx = midX(sig0);
        push(bx, midY(sig0) - 32);
        heroStops.push(pts.length - 1);
        for (var j = 1; j < sigs.length; j += 1) {
          push(bx, midY(sigs[j]) - 32);
          heroStops.push(pts.length - 1);
        }
        var jy = docY($('.jn', hero));
        push(bx, jy - 20);
        heroStops.push(pts.length - 1);
        var pivotY = jy;
        push(bx, pivotY);
        heroPivot = pts.length - 1;
        var mx = midX($('.plan__main', hero));
        push(mx, pivotY + (bx - mx));
        heroStops.push(pts.length - 1);
      }
      var exit = $('.plan__exit', hero);
      if (exit && horizontal) {
        var ex = exit.getBoundingClientRect();
        var rx = ex.right + window.scrollX - 3;
        push(rx - 24, mainY);
        push(rx, mainY + 24);
      }
    }
    secs.forEach(function (s, idx) {
      var rail = $(':scope > .rail', s);
      var rr = rail.getBoundingClientRect();
      var x = rr.left + rr.width / 2 + window.scrollX;
      var top = docY(s);
      var bot = rr.bottom + window.scrollY;
      var join = $(':scope > .join', s);
      if (join && pts.length) {
        var k = join.getBoundingClientRect().height / 64;
        var px = pts[pts.length - 1][0];
        var dir = x > px ? 1 : -1;
        push(px, top);
        push(px, top + 8 * k);
        push(px + dir * 24 * k, top + 32 * k);
        push(x - dir * 24 * k, top + 32 * k);
        push(x, top + 56 * k);
        push(x, top + 64 * k);
      } else if (idx === 0) {
        push(x, top + 8);
      } else {
        push(x, top);
      }
      push(x, bot);
      var stn = $$('.stn', s);
      stn.forEach(function (n) { stops.push({ el: n, sec: s, x: x, y: midY(n) }); });
    });
    var term = $('[data-terminal] .key--end');
    if (term) {
      var last = pts[pts.length - 1];
      var kr = term.getBoundingClientRect();
      push(kr.right + window.scrollX + 18, last[1]);
    }
    bands = secs.map(function (s) {
      var r = s.getBoundingClientRect();
      return { top: r.top + window.scrollY, bottom: r.bottom + window.scrollY, dark: s.classList.contains('t-dark') };
    });
    heroBottom = hero ? hero.getBoundingClientRect().bottom + window.scrollY : 0;
    cum = [0];
    for (var n = 1; n < pts.length; n += 1) {
      cum.push(cum[n - 1] + Math.abs(pts[n][0] - pts[n - 1][0]) + Math.abs(pts[n][1] - pts[n - 1][1]) -
        Math.min(Math.abs(pts[n][0] - pts[n - 1][0]), Math.abs(pts[n][1] - pts[n - 1][1])) * .586);
    }
    total = cum[cum.length - 1];
    heroStops = heroStops.map(function (i) { return cum[i]; });
    heroEnd = heroStops.length ? heroStops[heroStops.length - 1] : 0;
    stops.forEach(function (s) {
      for (var i = 1; i < pts.length; i += 1) {
        if (pts[i][0] === s.x && pts[i - 1][0] === s.x && pts[i - 1][1] <= s.y && pts[i][1] >= s.y) {
          s.len = cum[i - 1] + (s.y - pts[i - 1][1]);
          break;
        }
      }
      if (s.len === undefined) s.len = 0;
    });
    litFrom = heroPivot >= 0 ? cum[heroPivot] : 0;
    var d = pts.slice(Math.max(heroPivot, 0)).map(function (p, i) { return (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1); }).join(' ');
    if (litPath) {
      lit.style.height = '0px';
      var W = document.documentElement.clientWidth;
      var H = document.documentElement.scrollHeight;
      litPath.setAttribute('d', d);
      lit.style.height = H + 'px';
      lit.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
      litLen = litPath.getTotalLength();
      litPath.style.strokeDasharray = litLen + ' ' + (litLen + 10);
      litPath.style.strokeWidth = getComputedStyle(document.documentElement).getPropertyValue('--t').trim();
    }
  }

  function pointAt(len) {
    var i = 1;
    while (i < cum.length - 1 && cum[i] < len) i += 1;
    var a = pts[i - 1];
    var b = pts[i];
    var span = cum[i] - cum[i - 1] || 1;
    var t = Math.min(1, Math.max(0, (len - cum[i - 1]) / span));
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  }

  function readTarget() {
    var vh = window.innerHeight;
    var max = document.documentElement.scrollHeight - vh;
    var sy = window.scrollY;
    var base = heroStops.length || !stops.length ? vh * .6 : Math.min(stops[0].y, vh * .6);
    var c = sy + base + (vh * .6 - base) * Math.min(1, sy / (vh * .5));
    var len = heroEnd;
    var start = { y: base, len: heroEnd };
    var prev = start;
    var next = null;
    for (var i = 0; i < stops.length; i += 1) {
      if (stops[i].y <= c) prev = stops[i]; else { next = stops[i]; break; }
    }
    if (next) {
      len = prev.len + (next.len - prev.len) * Math.max(0, (c - prev.y) / (next.y - prev.y));
    } else {
      var s0 = prev.y - vh * .6;
      var f = max > s0 ? Math.max(0, (sy - s0) / (max - s0)) : 1;
      len = prev.len + (total - prev.len) * Math.min(1, f);
    }
    return len;
  }

  function paint() {
    if (!pts.length || !marker) return;
    var p = pointAt(cur);
    marker.style.transform = 'translate3d(' + p[0].toFixed(1) + 'px,' + p[1].toFixed(1) + 'px,0)';
    if (litPath) {
      var f = (cur - litFrom) / Math.max(1, total - litFrom);
      litPath.style.strokeDashoffset = litLen * (1 - Math.min(1, Math.max(0, f)));
    }
    var dark = p[1] < heroBottom;
    bands.forEach(function (b) { if (p[1] >= b.top && p[1] < b.bottom) dark = b.dark; });
    marker.classList.toggle('is-dark', dark);
    stops.forEach(function (s) { s.el.classList.toggle('is-past', cur >= s.len - 2); });
    var end = $('[data-terminal]');
    if (end) end.classList.toggle('is-home', cur >= total - 6);
  }

  function tick() {
    raf = 0;
    if (!pts.length) return;
    var d = target - cur;
    if (reduce) { cur = target; paint(); return; }
    if (Math.abs(d) < .5) { cur = target; paint(); return; }
    var step = d * .12;
    var cap = 170;
    if (step > cap) step = cap;
    if (step < -cap) step = -cap;
    cur += step;
    paint();
    raf = requestAnimationFrame(tick);
  }
  function kick() { if (!raf) raf = requestAnimationFrame(tick); }

  function retarget() {
    if (!pts.length) return;
    if (held) return;
    target = readTarget();
    kick();
  }

  function layoutTrack() {
    measure();
    if (held) { target = heroStops[heroAt] || 0; cur = target; }
    else target = readTarget();
    kick();
    paint();
  }

  if (secs.length) {
    var ns = 'http://www.w3.org/2000/svg';
    lit = document.createElementNS(ns, 'svg');
    lit.setAttribute('class', 'lit');
    lit.setAttribute('aria-hidden', 'true');
    litPath = document.createElementNS(ns, 'path');
    lit.appendChild(litPath);
    document.body.appendChild(lit);
    marker = document.createElement('div');
    marker.className = 'marker';
    marker.setAttribute('aria-hidden', 'true');
    marker.innerHTML = '<b>#214</b>';
    document.body.appendChild(marker);
    window.addEventListener('scroll', retarget, { passive: true });
    window.addEventListener('resize', layoutTrack);
    window.addEventListener('load', layoutTrack);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(layoutTrack);
  }

  /* Home: the interlock. */
  var panel = $('[data-interlock]');
  if (panel) {
    var conds = $$('.cond', panel);
    var keys = $$('[data-press]', panel);
    var msg = $('[data-msg]', panel);
    var routeEl = $('.route', panel);
    var routeWord = $('[data-route-word]', panel);
    var resetKey = $('[data-reset]', panel);
    var STEPS = [
      { held: 'Missing', state: 'held', pass: 'Passed', done: 'Ticket 42 is linked.', first: 'Link the ticket first.' },
      { held: 'Not found', state: 'warn', pass: 'Passed', done: 'The decision record is in place.', first: 'Add the decision record first.' },
      { held: 'Not recorded', state: 'warn', pass: 'Passed', done: 'Every check passed. The route waits for a named person.', first: 'Record the review first.' },
      { held: 'Waiting', state: 'named-wait', pass: 'Approved', done: 'Approved by Dana Reyes, 14:32 UTC, at commit 3f9c2a1' },
    ];
    var next = 0;
    var cleared = false;
    var busy = false;
    var touched = false;
    var autoTimer = null;
    var refuseTimer = null;

    held = true;

    var word = function (i, w) { $('[data-word]', conds[i]).textContent = w; };
    var state = function (i, s) { conds[i].setAttribute('data-state', s); };
    var setRoute = function (kind, w) { routeEl.setAttribute('data-route', kind); routeWord.textContent = w; };
    var say = function (t, refused, named) {
      msg.textContent = t;
      msg.classList.toggle('is-refused', !!refused);
      msg.classList.toggle('is-named', !!named);
    };
    var moveTo = function (stopIndex) {
      heroAt = stopIndex;
      target = heroStops[stopIndex] || 0;
      kick();
    };

    function baseline() {
      next = 0;
      cleared = false;
      busy = false;
      held = true;
      panel.classList.remove('is-clear');
      STEPS.forEach(function (s, i) {
        word(i, s.held);
        state(i, i === 0 ? 'held' : s.state === 'warn' ? 'warn' : 'wait');
        keys[i].setAttribute('aria-pressed', 'false');
        keys[i].classList.remove('is-refused');
      });
      setRoute('held', 'Merge blocked');
      say('No ticket is linked, so the route stays held.');
      if (resetKey) resetKey.hidden = true;
    }

    function finish(instant) {
      panel.classList.add('is-clear');
      cleared = true;
      setRoute('clear', 'Ready to merge');
      if (resetKey) resetKey.hidden = false;
      var open = function () {
        held = false;
        retarget();
        target = Math.max(target, heroEnd);
        kick();
      };
      /* The junction lands first. Only then does the marker roll. */
      if (instant || reduce) {
        moveTo(heroStops.length - 1);
        open();
      } else {
        setTimeout(function () { moveTo(heroStops.length - 1); }, 400);
        setTimeout(open, 1400);
      }
    }

    function press(i) {
      if (busy) return;
      if (cleared || i < next) {
        var name = $('.cond__name', conds[i]).textContent;
        say(name + ' is already clear.');
        return;
      }
      if (i > next) {
        keys[i].classList.add('is-refused');
        conds[i].classList.add('is-refused');
        say('Refused. ' + (i === 3 ? 'A named person approves last, after every other condition clears.' : STEPS[next].first), true);
        clearTimeout(refuseTimer);
        refuseTimer = setTimeout(function () {
          keys.forEach(function (k) { k.classList.remove('is-refused'); });
          conds.forEach(function (c) { c.classList.remove('is-refused'); });
        }, 1400);
        return;
      }
      busy = true;
      keys[i].setAttribute('aria-pressed', 'true');
      if (i < 3) {
        word(i, 'Running');
        state(i, 'run');
        setRoute('check', 'Checking');
      }
      var settle = function () {
        busy = false;
        word(i, STEPS[i].pass);
        state(i, i === 3 ? 'named' : 'pass');
        say(STEPS[i].done, false, i === 3);
        next = i + 1;
        if (i < 3) {
          setRoute('held', 'Merge blocked');
          moveTo(i + 1);
        } else {
          moveTo(4);
          setTimeout(function () { finish(false); }, reduce ? 0 : 420);
        }
      };
      if (reduce) settle(); else setTimeout(settle, i === 3 ? 160 : 420);
    }

    function stopAuto() {
      clearTimeout(autoTimer);
      autoTimer = null;
      touched = true;
    }

    function autoPlay() {
      if (touched || reduce) return;
      autoTimer = setTimeout(function run() {
        if (touched || cleared) return;
        press(next);
        if (next < 4) autoTimer = setTimeout(run, next === 3 ? 1300 : 1150);
      }, 2600);
    }

    keys.forEach(function (k, i) {
      k.disabled = false;
      k.addEventListener('click', function (e) {
        if (e.isTrusted !== false) stopAuto();
        press(i);
      });
    });
    panel.addEventListener('pointerdown', function () { stopAuto(); });
    panel.addEventListener('keydown', function () { stopAuto(); });
    if (resetKey) {
      resetKey.addEventListener('click', function () {
        stopAuto();
        baseline();
        heroAt = 0;
        layoutTrack();
      });
    }

    /* A visitor who leaves before the route is set still gets the marker. */
    var complete = function () {
      if (cleared) return;
      touched = true;
      clearTimeout(autoTimer);
      STEPS.forEach(function (s, i) {
        word(i, s.pass);
        state(i, i === 3 ? 'named' : 'pass');
        keys[i].setAttribute('aria-pressed', 'true');
      });
      next = 4;
      say(STEPS[3].done, false, true);
      finish(true);
    };
    var started = false;
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          if (en.isIntersecting) {
            if (!started) { started = true; autoPlay(); }
          } else if (en.boundingClientRect.bottom < 0) {
            complete();
          }
        });
      }, { threshold: [0, .35] }).observe(panel);
    } else {
      autoPlay();
    }

    baseline();
    measure();
    cur = heroStops[0] || 0;
    target = cur;
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () {
      measure();
      if (!cleared) { cur = heroStops[heroAt] || 0; target = cur; }
      paint();
    });
    paint();
  }
})();
