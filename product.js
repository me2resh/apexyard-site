/* ApexYard product pages (#102): nav, live star count, install tabs,
   copy buttons, mail links, cookie consent, and redirects for the old
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

  // Team claims: claims.js can flip any claim to "Coming" with one line.
  var claims = window.APEXYARD_CLAIMS || {};
  document.querySelectorAll('[data-claim]').forEach(function (el) {
    if (claims[el.getAttribute('data-claim')] !== 'coming') return;
    el.classList.add('is-coming');
    var tag = el.querySelector('.claim-coming');
    if (tag) tag.hidden = false;
  });

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
      '?subject=' + encodeURIComponent('ApexYard Team'));
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
