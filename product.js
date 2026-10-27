/* ApexYard product pages (#102): nav, GitHub stats from /github-stats.json, install tabs,
   copy buttons, claim state attributes, mail links, cookie consent, and redirects for the old
   home-page anchors that now live on /docs. No dependencies. */
(function () {
  'use strict';

  function track(name) {
    if (typeof window.gtag === 'function') window.gtag('event', name);
  }

  // Old home-page anchors moved to /docs. Keep shared links working.
  var moved = ['what-you-get', 'who-this-is-for', 'gate-replay', 'the-rules',
    'terminal-demo', 'examples', 'in-the-box', 'commercial', 'alternative',
    'paths', 'demo'];
  var hash = (location.hash || '').slice(1);
  if (document.body.hasAttribute('data-home') && hash && moved.indexOf(hash) !== -1 &&
      !document.getElementById(hash)) {
    var toPricing = hash === 'paths' || hash === 'commercial' || hash === 'demo';
    location.replace(toPricing ? '/pricing' : '/docs#' + hash);
    return;
  }

  // Claims set a data attribute only. No state renders a visible label.
  // data-claim-off replaces the element's text when the claim is not live.
  var claims = window.APEXYARD_CLAIMS || {};
  document.querySelectorAll('[data-claim]').forEach(function (el) {
    var state = claims[el.getAttribute('data-claim')];
    if (state === 'live' || state === 'coming') {
      el.setAttribute('data-claim-state', state);
    }
    if (el.hasAttribute('data-claim-off') && state !== 'live') {
      el.textContent = el.getAttribute('data-claim-off');
    }
  });

  // Theme toggle. The page follows the system setting until the visitor
  // picks a theme; the choice is kept in localStorage when it is available.
  var themeBtn = document.querySelector('[data-theme-toggle]');
  if (themeBtn && window.matchMedia) {
    var docEl = document.documentElement;
    var dark = window.matchMedia('(prefers-color-scheme: dark)');
    var current = function () {
      var t = docEl.getAttribute('data-theme');
      return t === 'dark' || t === 'light' ? t : (dark.matches ? 'dark' : 'light');
    };
    var sync = function () { themeBtn.setAttribute('aria-pressed', current() === 'dark' ? 'true' : 'false'); };
    themeBtn.addEventListener('click', function () {
      var next = current() === 'dark' ? 'light' : 'dark';
      docEl.setAttribute('data-theme', next);
      try { localStorage.setItem('ay-theme', next); } catch (e) {}
      sync();
    });
    if (dark.addEventListener) dark.addEventListener('change', sync);
    sync();
    themeBtn.hidden = false;
  }

  // Product menu (disclosure pattern). Without JS the list stays open.
  var menuBtn = document.querySelector('.site-nav__menu');
  var menu = document.getElementById('product-menu');
  if (menuBtn && menu) {
    var setMenu = function (open) {
      menuBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
      menu.hidden = !open;
    };
    setMenu(false);
    document.documentElement.classList.add('has-menu');
    menuBtn.addEventListener('click', function () {
      setMenu(menuBtn.getAttribute('aria-expanded') !== 'true');
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && menuBtn.getAttribute('aria-expanded') === 'true') {
        setMenu(false);
        menuBtn.focus();
        e.stopImmediatePropagation(); // a second Escape closes the mobile nav
      }
    });
    document.addEventListener('click', function (e) {
      if (!menu.hidden && !menuBtn.contains(e.target) && !menu.contains(e.target)) setMenu(false);
    });
    menu.addEventListener('focusout', function (e) {
      if (window.matchMedia('(min-width: 980px)').matches && e.relatedTarget &&
          !menu.contains(e.relatedTarget) && e.relatedTarget !== menuBtn) setMenu(false);
    });
  }

  // Mobile nav toggle.
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.getElementById('site-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && nav.classList.contains('is-open')) {
        nav.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
        toggle.focus();
      }
    });
  }

  // Same-origin GitHub stats. On any failure the block stays hidden.
  var ghStats = document.querySelectorAll('[data-gh-stats]');
  if (ghStats.length && window.fetch) {
    var months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    fetch('/github-stats.json')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d) return;
        var stars = d.stars;
        var forks = d.forks;
        var asOf = d.asOf;
        if (!Number.isFinite(stars) || stars < 0 || stars !== Math.floor(stars)) return;
        if (!Number.isFinite(forks) || forks < 0 || forks !== Math.floor(forks)) return;
        if (typeof asOf !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(asOf)) return;
        var parts = asOf.split('-');
        var y = +parts[0];
        var m = +parts[1];
        var day = +parts[2];
        if (m < 1 || m > 12 || day < 1 || day > 31) return;
        var dateText = day + ' ' + months[m - 1] + ' ' + y;
        var starsText = stars.toLocaleString('en-GB');
        var forksText = forks.toLocaleString('en-GB');
        document.querySelectorAll('[data-gh-stars]').forEach(function (el) {
          el.textContent = starsText;
        });
        document.querySelectorAll('[data-gh-forks]').forEach(function (el) {
          el.textContent = forksText;
        });
        document.querySelectorAll('[data-gh-asof]').forEach(function (el) {
          el.textContent = dateText;
        });
        ghStats.forEach(function (el) { el.removeAttribute('hidden'); });
      })
      .catch(function () {});
  }

  // Copy buttons.
  function copy(text, btn, status) {
    function done() {
      var prev = btn.textContent;
      btn.textContent = 'Copied';
      setTimeout(function () { btn.textContent = prev; }, 1500);
      if (status) status.textContent = 'Copied to the clipboard.';
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {});
    }
  }
  document.querySelectorAll('[data-copy-target]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var el = document.getElementById(btn.getAttribute('data-copy-target'));
      if (!el) return;
      track('quickstart_copy');
      copy(el.textContent || '', btn, document.getElementById('tabs-status'));
    });
  });

  // Tabs (WAI-ARIA tabs pattern).
  document.querySelectorAll('[data-tabs]').forEach(function (root) {
    var tabs = Array.prototype.slice.call(root.querySelectorAll('[role="tab"]'));
    var panels = Array.prototype.slice.call(root.querySelectorAll('[role="tabpanel"]'));
    function select(tab, focus) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute('aria-selected', on ? 'true' : 'false');
        t.tabIndex = on ? 0 : -1;
      });
      panels.forEach(function (p) {
        if (p.id === tab.getAttribute('aria-controls')) p.removeAttribute('hidden');
        else p.setAttribute('hidden', '');
      });
      if (focus) tab.focus();
    }
    var initial = tabs.find(function (tab) { return tab.getAttribute('aria-selected') === 'true'; });
    if (initial) select(initial, false);
    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () { select(tab, false); });
      tab.addEventListener('keydown', function (e) {
        var next = -1;
        if (e.key === 'ArrowRight') next = (i + 1) % tabs.length;
        else if (e.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
        else if (e.key === 'Home') next = 0;
        else if (e.key === 'End') next = tabs.length - 1;
        if (next < 0) return;
        e.preventDefault();
        select(tabs[next], true);
      });
    });
  });

  // Mail links: the address is assembled here, so the HTML holds no address.
  document.querySelectorAll('.mailto-cta').forEach(function (a) {
    var u = a.getAttribute('data-u');
    var d = a.getAttribute('data-d');
    if (!u || !d) return;
    a.setAttribute('href', 'mail' + 'to:' + encodeURIComponent(u) + '@' + encodeURIComponent(d) +
      '?subject=' + encodeURIComponent(a.getAttribute('data-s') || 'ApexYard Team'));
    a.addEventListener('click', function () { track('mailto_click'); });
  });

  // Cookie consent (same contract as the other pages, #399).
  var KEY = 'ay-consent';
  var banner = document.getElementById('consent');
  if (banner) {
    var stored = null;
    try { stored = localStorage.getItem(KEY); } catch (e) {}
    if (stored !== 'granted' && stored !== 'denied') banner.hidden = false;
    var record = function (choice) {
      if (banner.hidden) return;
      try { localStorage.setItem(KEY, choice); } catch (e) {}
      if (choice === 'granted' && typeof window.gtag === 'function') {
        window.gtag('consent', 'update', { analytics_storage: 'granted' });
      }
      banner.hidden = true;
    };
    banner.addEventListener('click', function (e) {
      var b = e.target.closest('[data-consent]');
      if (b) record(b.getAttribute('data-consent'));
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !banner.hidden) record('denied');
    });
  }
})();

// Site flag and waitlist (#122). The two files load in order, config first.
(function () {
  ['/site-config.js', '/waitlist.js'].forEach(function (src) {
    var s = document.createElement('script');
    s.src = src;
    s.async = false;
    document.head.appendChild(s);
  });
})();

// staging.apexyard.ai is SITE_DOMAIN in .github/workflows/deploy-staging-v2.yml; production excludes staging-only.js (AgDR-0011).
(function () {
  if (location.hostname === 'staging.apexyard.ai') {
    var s = document.createElement('script');
    s.src = '/staging-only.js';
    s.defer = true;
    document.head.appendChild(s);
  }
})();
