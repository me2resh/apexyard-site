/* ApexYard: animated Keel loop. One orchestrated phase cycle on each
   [data-keel] figure. Without this script the static SVG and step list still
   read. No dependencies. */
(function () {
  'use strict';

  var PHASE_MS = 1800;
  var PHASES = ['change', 'catch', 'miss', 'rule', 'pass', 'measure'];

  var CFG = {
    change: { step: 'build', node: 'build', path: 'change', travel: 'change' },
    catch: { step: 'gate', node: 'gate', gate: 'is-block' },
    miss: { step: 'miss', path: 'miss', travel: 'miss' },
    rule: { step: 'rule', node: 'keel', keel: 'is-new' },
    pass: { step: 'gate', node: 'gate', path: 'change', gate: 'is-pass', travel: 'change' },
    measure: { step: 'readiness', node: 'readiness', path: 'measure' }
  };

  var reduceMq = window.matchMedia
    ? window.matchMedia('(prefers-reduced-motion: reduce)')
    : null;

  /* Flow mode (#196): the home page figure, [data-keel="flow"]. Six steps in a
     caption bar. Build, Gate and Readiness sit in one row, Keel below the Gate.
     The live region speaks only after a user action, never on the auto-advance. */
  var FLOW_MS = 4200;
  var TRAVEL_MS = 1400;
  var FLOW = [
    { step: 'build', nodes: { build: 'is-active' }, wires: { rules: 'brand' }, travel: 'rules' },
    { step: 'gate', nodes: { gate: 'is-block' }, wires: { change: 'block' }, travel: 'change' },
    { step: 'miss', nodes: { gate: 'is-block', keel: 'is-active' }, wires: { miss: 'light' }, travel: 'miss' },
    { step: 'rule', nodes: { keel: 'is-active' }, wires: { rules: 'brand' }, rib: 'new' },
    { step: 'pass', nodes: { gate: 'is-pass' }, wires: { change: 'pass' }, rib: 'pass', ready: 'pass', travel: 'change' },
    { step: 'readiness', nodes: { gate: 'is-pass', readiness: 'is-pass' }, wires: { ready: 'pass' }, rib: 'pass', ready: 'pass', travel: 'ready' }
  ];

  function enhanceFlow(figure) {
    var pauseBtn = figure.querySelector('.keel__pause');
    var dotsBox = figure.querySelector('.kf__dots');
    var live = figure.querySelector('[data-kf-live]');
    var steps = figure.querySelectorAll('.keel__step');
    var nodes = figure.querySelectorAll('[data-node]');
    var wires = figure.querySelectorAll('[data-wire]');
    if (!pauseBtn || !dotsBox || !live || steps.length !== FLOW.length) return;

    var dot = document.createElement('span');
    dot.className = 'kf__dot';
    var dotBtns = [];
    var index = 0;
    var userPaused = false;
    var inView = true;
    var pageHidden = !!document.hidden;
    var running = false;
    var timer = 0;
    var rafId = 0;

    function reduced() { return !!(reduceMq && reduceMq.matches); }
    function canRun() { return !reduced() && inView && !pageHidden && !userPaused; }

    function stepName(i) {
      var n = steps[i].querySelector('.keel__name');
      return n ? n.textContent : '';
    }

    function placeDot(wire, t) {
      var path = wire && wire.querySelector('path');
      if (!path || typeof path.getTotalLength !== 'function') return;
      try {
        var len = path.getTotalLength();
        var pt = path.getPointAtLength(Math.max(0, Math.min(1, t)) * len);
        dot.style.left = pt.x + '%';
        dot.style.top = pt.y + '%';
      } catch (e) { /* path not rendered: leave the dot where it is */ }
    }

    function stopTravel() {
      if (rafId) { window.cancelAnimationFrame(rafId); rafId = 0; }
    }

    function travel(wire, animate) {
      stopTravel();
      if (!wire) { if (dot.parentNode) dot.parentNode.removeChild(dot); return; }
      wire.appendChild(dot);
      if (!animate) { placeDot(wire, 1); return; }
      var start = performance.now();
      placeDot(wire, 0);
      function frame(now) {
        var t = Math.min(1, (now - start) / TRAVEL_MS);
        placeDot(wire, 1 - (1 - t) * (1 - t));
        rafId = t < 1 ? window.requestAnimationFrame(frame) : 0;
      }
      rafId = window.requestAnimationFrame(frame);
    }

    function render(i, animate) {
      var cfg = FLOW[i];
      var k;
      index = i;
      figure.setAttribute('data-phase', cfg.step);
      if (cfg.rib) figure.setAttribute('data-rib', cfg.rib); else figure.removeAttribute('data-rib');
      if (cfg.ready) figure.setAttribute('data-ready', cfg.ready); else figure.removeAttribute('data-ready');
      for (k = 0; k < steps.length; k++) steps[k].classList.toggle('is-active', k === i);
      for (k = 0; k < dotBtns.length; k++) {
        if (k === i) dotBtns[k].setAttribute('aria-current', 'step');
        else dotBtns[k].removeAttribute('aria-current');
      }
      for (k = 0; k < nodes.length; k++) {
        var nodeName = nodes[k].getAttribute('data-node');
        nodes[k].classList.remove('is-active', 'is-block', 'is-pass');
        if (cfg.nodes[nodeName]) nodes[k].classList.add(cfg.nodes[nodeName]);
      }
      var travelWire = null;
      for (k = 0; k < wires.length; k++) {
        var wireName = wires[k].getAttribute('data-wire');
        if (cfg.wires[wireName]) wires[k].setAttribute('data-tone', cfg.wires[wireName]);
        else wires[k].removeAttribute('data-tone');
        if (cfg.travel === wireName) travelWire = wires[k];
      }
      travel(travelWire, animate && !reduced());
    }

    function announce(i) {
      var parts = steps[i].querySelectorAll('p');
      var text = [];
      for (var k = 0; k < parts.length; k++) text.push(parts[k].textContent.trim());
      live.textContent = 'Step ' + (i + 1) + ' of ' + FLOW.length + ': ' + text.join('. ').replace(/\.\./g, '.');
    }

    function stopTimer() {
      if (timer) { window.clearTimeout(timer); timer = 0; }
    }

    function schedule() {
      stopTimer();
      if (!canRun()) { running = false; return; }
      running = true;
      timer = window.setTimeout(function () {
        timer = 0;
        if (!canRun()) { running = false; return; }
        render((index + 1) % FLOW.length, true);
        schedule();
      }, FLOW_MS);
    }

    function halt() {
      stopTimer();
      stopTravel();
      running = false;
      placeDot(dot.parentNode, 1);
    }

    function resume() {
      if (!canRun() || running) return;
      schedule();
    }

    function setMode() {
      if (reduced()) {
        halt();
        pauseBtn.textContent = 'Next step';
        pauseBtn.removeAttribute('aria-pressed');
      } else {
        pauseBtn.textContent = 'Pause animation';
        pauseBtn.setAttribute('aria-pressed', userPaused ? 'true' : 'false');
      }
    }

    for (var d = 0; d < FLOW.length; d++) {
      (function (i) {
        var b = document.createElement('button');
        b.type = 'button';
        b.className = 'kf__dot-btn';
        b.setAttribute('aria-label', 'Step ' + (i + 1) + ': ' + stepName(i));
        b.addEventListener('click', function () {
          if (!reduced()) {
            userPaused = true;
            pauseBtn.setAttribute('aria-pressed', 'true');
          }
          halt();
          render(i, false);
          announce(i);
        });
        dotsBox.appendChild(b);
        dotBtns.push(b);
      })(d);
    }

    pauseBtn.addEventListener('click', function () {
      if (reduced()) {
        render((index + 1) % FLOW.length, false);
        announce(index);
        return;
      }
      userPaused = !userPaused;
      pauseBtn.setAttribute('aria-pressed', userPaused ? 'true' : 'false');
      if (userPaused) halt();
      else resume();
    });

    document.addEventListener('visibilitychange', function () {
      pageHidden = !!document.hidden;
      if (pageHidden) halt();
      else resume();
    });

    if (typeof IntersectionObserver === 'function') {
      var io = new IntersectionObserver(function (entries) {
        var entry = entries[0];
        inView = !!(entry && entry.isIntersecting);
        if (!inView) halt();
        else resume();
      }, { threshold: 0.2 });
      io.observe(figure);
    }

    function onReduceChange() {
      setMode();
      if (reduced()) render(FLOW.length - 1, false);
      else { userPaused = false; setMode(); render(0, true); resume(); }
    }
    if (reduceMq) {
      if (typeof reduceMq.addEventListener === 'function') reduceMq.addEventListener('change', onReduceChange);
      else if (typeof reduceMq.addListener === 'function') reduceMq.addListener(onReduceChange);
    }

    figure.classList.add('is-on');
    dotsBox.hidden = false;
    pauseBtn.hidden = false;
    setMode();
    if (reduced()) render(FLOW.length - 1, false);
    else { render(0, true); resume(); }
  }

  function enhance(root) {
    var figure = root;
    if (figure.getAttribute('data-keel') === 'flow') {
      enhanceFlow(figure);
      return;
    }
    var svg = figure.querySelector('.keel__svg');
    var pauseBtn = figure.querySelector('.keel__pause');
    var steps = figure.querySelectorAll('.keel__step');
    var nodes = figure.querySelectorAll('[data-node]');
    var paths = figure.querySelectorAll('[data-path]');
    var dot = figure.querySelector('.keel__dot');
    var changePath = figure.querySelector('[data-path="change"]');
    var missPath = figure.querySelector('[data-path="miss"]');
    if (!svg || !pauseBtn || !dot || !changePath || !missPath) return;

    var highlight = figure.getAttribute('data-keel-highlight') || '';
    if (highlight === 'build' || highlight === 'gate' || highlight === 'readiness') {
      var hiNode = figure.querySelector('[data-node="' + highlight + '"]');
      var hiStep = figure.querySelector('[data-step="' + highlight + '"]');
      if (hiNode) hiNode.classList.add('is-home');
      if (hiStep) hiStep.classList.add('is-home');
    }

    var userPaused = false;
    var inView = true;
    var pageHidden = !!document.hidden;
    var running = false;
    var phaseIndex = 0;
    var phaseProgress = 0;
    var phaseStartedAt = 0;
    var rafId = 0;
    var holdTimer = 0;
    function clearActive() {
      var i;
      for (i = 0; i < steps.length; i++) steps[i].classList.remove('is-active');
      for (i = 0; i < nodes.length; i++) {
        nodes[i].classList.remove('is-active', 'is-block', 'is-pass', 'is-new');
      }
      for (i = 0; i < paths.length; i++) paths[i].classList.remove('is-active');
    }

    function setDotOnPath(pathEl, t) {
      if (!pathEl || typeof pathEl.getTotalLength !== 'function') return;
      var len = pathEl.getTotalLength();
      var pt = pathEl.getPointAtLength(Math.max(0, Math.min(1, t)) * len);
      dot.setAttribute('cx', String(pt.x));
      dot.setAttribute('cy', String(pt.y));
    }

    function applyPhase(name, progress) {
      var cfg = CFG[name];
      if (!cfg) return;
      clearActive();
      figure.setAttribute('data-phase', name);

      if (cfg.step) {
        var stepEl = figure.querySelector('[data-step="' + cfg.step + '"]');
        if (stepEl) stepEl.classList.add('is-active');
      }
      if (cfg.node) {
        var nodeEl = figure.querySelector('[data-node="' + cfg.node + '"]');
        if (nodeEl) {
          nodeEl.classList.add('is-active');
          if (cfg.gate) nodeEl.classList.add(cfg.gate);
          if (cfg.keel) nodeEl.classList.add(cfg.keel);
        }
      }
      if (cfg.path) {
        var pathEl = figure.querySelector('[data-path="' + cfg.path + '"]');
        if (pathEl) pathEl.classList.add('is-active');
      }

      if (cfg.travel === 'change') setDotOnPath(changePath, progress);
      else if (cfg.travel === 'miss') setDotOnPath(missPath, progress);
      else if (name === 'catch') setDotOnPath(changePath, 1);
      else if (name === 'rule') setDotOnPath(missPath, 1);
      else if (name === 'measure') setDotOnPath(changePath, 1);
    }

    function stopTimers() {
      if (rafId) {
        window.cancelAnimationFrame(rafId);
        rafId = 0;
      }
      if (holdTimer) {
        window.clearTimeout(holdTimer);
        holdTimer = 0;
      }
    }

    function goStatic() {
      stopTimers();
      running = false;
      clearActive();
      figure.setAttribute('data-phase', 'static');
      pauseBtn.hidden = true;
      pauseBtn.setAttribute('aria-pressed', 'false');
      userPaused = false;
    }

    function canRun() {
      return !(reduceMq && reduceMq.matches) && inView && !pageHidden && !userPaused;
    }

    function advancePhase() {
      phaseIndex = (phaseIndex + 1) % PHASES.length;
      phaseProgress = 0;
      startPhase();
    }

    function holdThenAdvance(remaining) {
      holdTimer = window.setTimeout(function () {
        holdTimer = 0;
        if (!canRun()) {
          running = false;
          return;
        }
        advancePhase();
      }, Math.max(0, remaining));
    }

    function tickTravel(now) {
      if (!canRun()) {
        rafId = 0;
        running = false;
        return;
      }
      var elapsed = now - phaseStartedAt;
      phaseProgress = Math.min(1, elapsed / PHASE_MS);
      applyPhase(PHASES[phaseIndex], phaseProgress);
      if (phaseProgress < 1) {
        rafId = window.requestAnimationFrame(tickTravel);
      } else {
        rafId = 0;
        advancePhase();
      }
    }

    function startPhase() {
      if (!canRun()) {
        running = false;
        return;
      }
      running = true;
      var name = PHASES[phaseIndex];
      var cfg = CFG[name];
      phaseStartedAt = performance.now() - phaseProgress * PHASE_MS;
      applyPhase(name, phaseProgress);

      if (cfg.travel) {
        rafId = window.requestAnimationFrame(tickTravel);
      } else {
        var remaining = (1 - phaseProgress) * PHASE_MS;
        holdThenAdvance(remaining);
      }
    }

    function resume() {
      if (!canRun() || running) return;
      if (reduceMq && reduceMq.matches) return;
      pauseBtn.hidden = false;
      startPhase();
    }

    function pauseLoop() {
      if (!running) return;
      stopTimers();
      running = false;
      var name = PHASES[phaseIndex];
      var cfg = CFG[name];
      if (phaseStartedAt) {
        phaseProgress = Math.min(1, (performance.now() - phaseStartedAt) / PHASE_MS);
      }
      applyPhase(name, phaseProgress);
    }

    pauseBtn.addEventListener('click', function () {
      if (reduceMq && reduceMq.matches) return;
      userPaused = !userPaused;
      pauseBtn.setAttribute('aria-pressed', userPaused ? 'true' : 'false');
      if (userPaused) pauseLoop();
      else resume();
    });

    function onVisibility() {
      pageHidden = !!document.hidden;
      if (pageHidden) pauseLoop();
      else resume();
    }
    document.addEventListener('visibilitychange', onVisibility);

    if (typeof IntersectionObserver === 'function') {
      var io = new IntersectionObserver(function (entries) {
        var entry = entries[0];
        inView = !!(entry && entry.isIntersecting);
        if (!inView) pauseLoop();
        else resume();
      }, { threshold: 0.2 });
      io.observe(figure);
    }

    function onReduceChange() {
      if (reduceMq && reduceMq.matches) goStatic();
      else {
        phaseIndex = 0;
        phaseProgress = 0;
        pauseBtn.hidden = false;
        pauseBtn.setAttribute('aria-pressed', 'false');
        userPaused = false;
        resume();
      }
    }
    if (reduceMq) {
      if (typeof reduceMq.addEventListener === 'function') {
        reduceMq.addEventListener('change', onReduceChange);
      } else if (typeof reduceMq.addListener === 'function') {
        reduceMq.addListener(onReduceChange);
      }
    }

    if (reduceMq && reduceMq.matches) {
      goStatic();
      return;
    }

    setDotOnPath(changePath, 0);
    pauseBtn.hidden = false;
    phaseIndex = 0;
    phaseProgress = 0;
    resume();
  }

  var roots = document.querySelectorAll('[data-keel]');
  for (var i = 0; i < roots.length; i++) enhance(roots[i]);
})();
