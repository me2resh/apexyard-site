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

  function enhance(root) {
    var figure = root;
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
