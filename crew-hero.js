/* Crew hero: the gate card story (#144, #157).
   The story is CSS only. This file starts it once, when the card first scrolls into view,
   and restarts it on Replay. It never loops. */
(function () {
  var hero = document.getElementById('hero');
  var btn = document.querySelector('[data-replay]');
  if (!hero || !btn) return;
  var card = hero.querySelector('.gate-card');

  function play() {
    hero.classList.remove('gc-hold');
    hero.classList.remove('is-playing');
    void hero.offsetWidth;
    hero.classList.add('is-playing');
  }

  if (card && 'IntersectionObserver' in window) {
    hero.classList.add('gc-hold');
    var io = new IntersectionObserver(function (entries) {
      for (var n = 0; n < entries.length; n++) {
        if (entries[n].isIntersecting) {
          io.disconnect();
          play();
          return;
        }
      }
    // Start as soon as any part of the card is on screen, a little above the
    // bottom edge. A ratio threshold never fires when the card is taller than
    // the viewport (for example at 400% zoom), which would leave the ticks hidden.
    }, { threshold: 0, rootMargin: '0px 0px -15% 0px' });
    io.observe(card);
  }

  btn.hidden = false;
  btn.addEventListener('click', play);
}());
