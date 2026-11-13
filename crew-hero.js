/* Crew hero: the gate card story (#144, #157, #160).
   The story is CSS only. All times come from the variables in site.css (--gc-*), so the card,
   small Hadi, large Hadi and the floor lights never drift apart.
   This file starts the story once, when the card first scrolls into view, restarts it on Replay,
   switches between the two examples, and opens a row's evidence. It never loops. */
(function () {
  var hero = document.getElementById('hero');
  if (!hero) return;
  var card = hero.querySelector('.gate-card');
  if (!card) return;
  var runs = card.querySelectorAll('.gc-run');
  var tabs = card.querySelectorAll('.gc-tab');
  var replays = card.querySelectorAll('[data-replay]');

  // The finale (#190): Hadi rolls in from the right when the story's last element ends.
  // It runs once. A replay uses up the finale and the story goes back to Hadi walking home.
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!reduce) {
    hero.classList.add('has-finale');
    hero.addEventListener('animationend', function (e) {
      if (hero.classList.contains('is-finale') || hero.classList.contains('finale-done')) return;
      if (e.target.classList && e.target.classList.contains('gc-merged')) hero.classList.add('is-finale');
    });
  }

  function play() {
    if (hero.classList.contains('is-finale')) hero.classList.add('finale-done');
    hero.classList.remove('is-finale');
    hero.classList.remove('gc-hold');
    hero.classList.remove('is-playing');
    void hero.offsetWidth;
    hero.classList.add('is-playing');
  }

  // Row evidence. One row is open at a time. Escape closes it and puts focus back on its button.
  function closeEvidence() {
    var open = card.querySelectorAll('.gc-row.is-open');
    for (var n = 0; n < open.length; n++) {
      var btn = open[n].querySelector('.gc-more');
      var panel = document.getElementById(btn.getAttribute('aria-controls'));
      open[n].classList.remove('is-open');
      btn.setAttribute('aria-expanded', 'false');
      if (panel) panel.hidden = true;
    }
  }
  card.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.gc-more') : null;
    if (!btn) return;
    var panel = document.getElementById(btn.getAttribute('aria-controls'));
    var row = btn.closest('.gc-row');
    var wasOpen = btn.getAttribute('aria-expanded') === 'true';
    closeEvidence();
    if (!wasOpen && panel && row) {
      row.classList.add('is-open');
      btn.setAttribute('aria-expanded', 'true');
      panel.hidden = false;
    }
  });
  card.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape' && e.key !== 'Esc') return;
    var row = card.querySelector('.gc-row.is-open');
    if (!row) return;
    var btn = row.querySelector('.gc-more');
    closeEvidence();
    btn.focus();
  });

  // The two examples: a merge that passed and a merge that was blocked.
  function show(name) {
    closeEvidence();
    for (var n = 0; n < runs.length; n++) {
      runs[n].classList.toggle('is-active', runs[n].getAttribute('data-run') === name);
    }
    for (var m = 0; m < tabs.length; m++) {
      tabs[m].setAttribute('aria-pressed', tabs[m].getAttribute('data-run') === name ? 'true' : 'false');
    }
    hero.setAttribute('data-run', name);
    play();
  }
  for (var t = 0; t < tabs.length; t++) {
    tabs[t].addEventListener('click', function (e) {
      var name = e.currentTarget.getAttribute('data-run');
      if (hero.getAttribute('data-run') !== name) show(name);
      else play();
    });
  }

  if ('IntersectionObserver' in window) {
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

  for (var r = 0; r < replays.length; r++) {
    replays[r].hidden = false;
    replays[r].addEventListener('click', play);
  }
}());
