/* Mobile hamburger for the titlebar nav (#9 follow-up).
   Progressive enhancement: this script adds `.nav-enhanced` to the titlebar,
   which flips the CSS from the scroll-strip fallback to a hamburger + dropdown.
   With JS off, the nav stays the horizontally-scrollable strip — still usable. */
(function () {
  var bar = document.querySelector(".titlebar");
  var btn = bar && bar.querySelector(".nav-toggle");
  var nav = bar && bar.querySelector("#primary-nav");
  if (!bar || !btn || !nav) return;

  bar.classList.add("nav-enhanced");

  function set(open) {
    bar.classList.toggle("is-open", open);
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    btn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  }

  btn.addEventListener("click", function (e) {
    e.stopPropagation();
    set(!bar.classList.contains("is-open"));
  });
  // click outside closes
  document.addEventListener("click", function (e) {
    if (bar.classList.contains("is-open") && !bar.contains(e.target)) set(false);
  });
  // Esc closes
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") set(false);
  });
  // tapping a link closes
  nav.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", function () { set(false); });
  });
})();
