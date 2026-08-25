// Light / dark theme toggle for the titlebar nav.
//
// The pages are already dark-mode aware through CSS alone: `@media
// (prefers-color-scheme: dark)` swaps the Swiss Graphite tokens. That follows
// the OS and offers no choice. This adds the choice on top, as a progressive
// enhancement:
//
//   - No stored choice        → <html> carries no data-theme; CSS follows the OS.
//   - Stored "light" / "dark" → <html data-theme="…"> pins that palette. The CSS
//                               token blocks are scoped `:root:not([data-theme="light"])`
//                               (OS default) and `:root[data-theme="dark"]` (pinned).
//   - Picking the theme the OS already uses clears the override instead of
//     pinning it, so the page keeps following the OS afterwards.
//
// A tiny inline <script> in each page's <head> applies the stored choice before
// first paint (no flash of the wrong theme); this file only owns the button.
// With JS off the button stays hidden (`.theme-toggle { display: none }`) and
// the page behaves exactly as before.
//
// Storage key `ay-theme` sits next to `ay-consent`. No build step; vanilla
// ES2017. Loaded once per page via <script src="/theme-toggle.js" defer>.
(function () {
  "use strict";

  var KEY = "ay-theme";
  var root = document.documentElement;
  var bar = document.querySelector(".titlebar");
  var btn = bar && bar.querySelector(".theme-toggle");
  if (!bar || !btn) return;

  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function systemTheme() { return media && media.matches ? "dark" : "light"; }
  // What the page shows right now: the pinned override if any, else the OS.
  function current() { return root.getAttribute("data-theme") || systemTheme(); }

  function render() {
    var dark = current() === "dark";
    btn.classList.toggle("is-dark", dark);
    btn.setAttribute("aria-label", dark ? "Switch to light theme" : "Switch to dark theme");
  }

  btn.addEventListener("click", function () {
    var next = current() === "dark" ? "light" : "dark";
    if (next === systemTheme()) {
      // Back to what the OS says: drop the override rather than pinning it.
      try { localStorage.removeItem(KEY); } catch (e) {}
      root.removeAttribute("data-theme");
    } else {
      try { localStorage.setItem(KEY, next); } catch (e) {}
      root.setAttribute("data-theme", next);
    }
    render();
  });

  // The OS theme flipped while nothing is pinned: CSS already followed it,
  // keep the icon honest too.
  function onSystemChange() { if (!root.hasAttribute("data-theme")) render(); }
  if (media) {
    if (media.addEventListener) media.addEventListener("change", onSystemChange);
    else if (media.addListener) media.addListener(onSystemChange);
  }

  bar.classList.add("theme-enhanced");
  render();
})();
