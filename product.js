/* ApexYard product pages (#102): nav, live star count, install tabs,
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

  // Live GitHub star count. If the API call fails, the count stays hidden.
  var starEls = document.querySelectorAll('[data-stars]');
  if (starEls.length && window.fetch) {
    fetch('https://api.github.com/repos/me2resh/apexyard', { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (!d || typeof d.stargazers_count !== 'number') return;
        var n = d.stargazers_count.toLocaleString('en-GB');
        starEls.forEach(function (el) {
          el.textContent = n;
          el.hidden = false;
          var wrap = el.closest('[data-stars-wrap]');
          if (wrap) wrap.hidden = false;
        });
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

  // Pricing product switcher (WAI-ARIA tabs pattern). Without JavaScript the
  // links jump to each product and every panel stays visible. The URL hash
  // selects the tab; an id inside a panel (for example #team) selects that
  // panel. The old #reviews anchor selects Assessments.
  var switcher = document.querySelector('[data-switcher]');
  if (switcher) {
    var sTabs = Array.prototype.slice.call(switcher.querySelectorAll('.switcher__tab'));
    var sPanels = sTabs.map(function (t) { return document.getElementById(t.getAttribute('href').slice(1)); });
    if (sPanels.every(Boolean)) {
      var sList = switcher.querySelector('.switcher__list');
      switcher.setAttribute('role', 'none');
      sList.setAttribute('role', 'tablist');
      sList.setAttribute('aria-label', 'Products');
      sList.setAttribute('aria-orientation', 'horizontal');
      sTabs.forEach(function (t, i) {
        t.setAttribute('role', 'tab');
        t.setAttribute('aria-controls', sPanels[i].id);
        sPanels[i].setAttribute('role', 'tabpanel');
        sPanels[i].setAttribute('aria-labelledby', t.id);
      });
      document.documentElement.classList.add('has-switcher');

      var sSelect = function (i, focus) {
        sTabs.forEach(function (t, j) {
          var on = i === j;
          t.setAttribute('aria-selected', on ? 'true' : 'false');
          t.tabIndex = on ? 0 : -1;
          sPanels[j].hidden = !on;
        });
        // The head script of pricing.html set data-panel before first paint,
        // so the page does not shift. Keep it in step with the selected tab.
        document.documentElement.setAttribute('data-panel', sPanels[i].id);
        if (focus) sTabs[i].focus();
      };
      // The tab with data-default (Gate) opens when the hash names no panel.
      var sDefault = Math.max(0, sTabs.findIndex(function (t) { return t.hasAttribute('data-default'); }));
      var fromHash = function () {
        var h = '';
        try { h = decodeURIComponent((location.hash || '').slice(1)); } catch (e) {}
        if (h === 'reviews') h = 'assessments';
        if (!h) return sDefault;
        var el = document.getElementById(h);
        for (var i = 0; i < sPanels.length; i++) {
          if (el && (sPanels[i] === el || sPanels[i].contains(el))) return i;
        }
        return sDefault;
      };
      var setHash = function (i) {
        if (window.history && history.replaceState) history.replaceState(null, '', '#' + sPanels[i].id);
      };
      sSelect(fromHash(), false);
      window.addEventListener('hashchange', function () { sSelect(fromHash(), false); });
      sTabs.forEach(function (t, i) {
        t.addEventListener('click', function (e) {
          e.preventDefault();
          sSelect(i, false);
          setHash(i);
        });
        t.addEventListener('keydown', function (e) {
          var next = -1;
          // A horizontal tab list: Up and Down stay with the page scroll.
          if (e.key === 'ArrowRight') next = (i + 1) % sTabs.length;
          else if (e.key === 'ArrowLeft') next = (i - 1 + sTabs.length) % sTabs.length;
          else if (e.key === 'Home') next = 0;
          else if (e.key === 'End') next = sTabs.length - 1;
          else if (e.key === ' ') { e.preventDefault(); sSelect(i, false); setHash(i); return; }
          if (next < 0) return;
          e.preventDefault();
          sSelect(next, true);
          setHash(next);
        });
      });
    }
  }

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
