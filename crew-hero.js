/* Crew hero: the Replay control for the gate card story (#144).
   The story is CSS only. This file only restarts it. */
(function () {
  var hero = document.getElementById('hero');
  var btn = document.querySelector('[data-replay]');
  if (!hero || !btn) return;
  btn.hidden = false;
  btn.addEventListener('click', function () {
    hero.classList.remove('is-playing');
    void hero.offsetWidth;
    hero.classList.add('is-playing');
  });
}());
