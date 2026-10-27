/* Published on staging only. The production deploy excludes this file, so [data-staging-only] blocks stay hidden there. */
(function () {
  'use strict';

  function reveal() {
    document.documentElement.setAttribute('data-stage', 'staging');
    document.querySelectorAll('[data-staging-only]').forEach(function (el) {
      el.removeAttribute('hidden');
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', reveal);
  } else {
    reveal();
  }
})();
