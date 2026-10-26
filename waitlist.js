/* Waitlist (#122): the site flag for "Start free with GitHub" buttons and the
   waitlist form. Reads window.APEXYARD_SITE from /site-config.js. No dependencies. */
(function () {
  'use strict';

  var cfg = window.APEXYARD_SITE || {};
  var signinOpen = cfg.signinOpen === true;

  var LABELS = { waitlist: 'Join the waitlist', signin: 'Start free with GitHub' };

  function applyLinks(anchors, open) {
    Array.prototype.forEach.call(anchors, function (a) {
      if (!a.getAttribute('data-waitlist')) {
        a.setAttribute('data-waitlist', a.getAttribute('href'));
      }
      a.textContent = open ? LABELS.signin : LABELS.waitlist;
      a.setAttribute('href', a.getAttribute(open ? 'data-signin' : 'data-waitlist'));
    });
  }

  function mailtoHref(contact, answers) {
    var lines = [
      'Who it is for: ' + answers.audience,
      'What to govern: ' + answers.govern.join(', '),
      'Team size: ' + answers.team_size,
      'Agent tools: ' + (answers.tools.length ? answers.tools.join(', ') : 'Not given')
    ];
    return 'mail' + 'to:' + contact.user + '@' + contact.domain +
      '?subject=' + encodeURIComponent('Join the ApexYard waitlist') +
      '&body=' + encodeURIComponent(lines.join('\n'));
  }

  async function submitAnswers(options) {
    var ui = options.ui;
    function notify(name, status) {
      try {
        ui[name](status);
      } catch (err) {
        try { ui.showFallback(); } catch (fallbackError) {}
      }
    }
    if (!options.endpoint) {
      notify('showFallback');
      return;
    }
    var ctrl = typeof AbortController === 'function' ? new AbortController() : null;
    var timer;
    var res;
    try {
      res = await Promise.race([
        Promise.resolve().then(function () {
          return options.fetchFn(options.endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify(options.body),
            credentials: 'omit',
            signal: ctrl ? ctrl.signal : undefined
          });
        }),
        new Promise(function (_, reject) {
          timer = setTimeout(function () {
            reject(new Error('Request timeout'));
            if (ctrl) ctrl.abort();
          }, options.timeoutMs === undefined ? 10000 : options.timeoutMs);
        })
      ]);
      if (res.ok) notify('showConfirmation');
      else if (res.status === 400 || res.status === 422 || res.status === 429) notify('showError', res.status);
      else notify('showFallback');
    } catch (err) {
      notify('showFallback');
      return;
    } finally {
      if (timer) clearTimeout(timer);
    }
  }

  var api = { LABELS: LABELS, applyLinks: applyLinks, submitAnswers: submitAnswers, mailtoHref: mailtoHref };
  window.ApexYardWaitlist = api;
  if (typeof module !== 'undefined') module.exports = api;
  applyLinks(document.querySelectorAll('[data-signin]'), signinOpen);

  var form = document.getElementById('waitlist-form');
  if (!form) return;

  if (signinOpen) {
    location.replace('https://app.apexyard.ai/signin?src=waitlist');
    return;
  }

  var errBox = document.getElementById('waitlist-errors');
  var done = document.getElementById('waitlist-done');
  var fallback = document.getElementById('waitlist-fallback');
  var submit = document.getElementById('waitlist-submit');
  var busy = false;
  form.hidden = false;
  var noscript = document.getElementById('waitlist-noscript');
  if (noscript) noscript.hidden = true;

  var MESSAGES = {
    email: 'Enter your email address, for example name@company.com.',
    audience: 'Choose who the Gate is for.',
    govern: 'Choose at least one thing you want to govern.',
    team_size: 'Choose a team size.'
  };

  function values(name) {
    return Array.prototype.map.call(
      form.querySelectorAll('input[name="' + name + '"]:checked'),
      function (i) { return i.value; });
  }

  function fieldEl(key) { return form.querySelector('[data-field="' + key + '"]'); }

  function groupInputs(wrap) {
    return wrap.querySelectorAll('input[type="radio"], input[type="checkbox"]');
  }

  function setGroupDescribedBy(wrap, errId) {
    Array.prototype.forEach.call(groupInputs(wrap), function (inp) {
      if (!inp.hasAttribute('data-describedby-orig')) {
        inp.setAttribute('data-describedby-orig', inp.getAttribute('aria-describedby') || '');
      }
      var orig = inp.getAttribute('data-describedby-orig') || '';
      var parts = orig ? orig.split(/\s+/).filter(Boolean) : [];
      if (parts.indexOf(errId) === -1) parts.push(errId);
      inp.setAttribute('aria-describedby', parts.join(' '));
    });
  }

  function clearGroupDescribedBy(wrap) {
    Array.prototype.forEach.call(groupInputs(wrap), function (inp) {
      if (!inp.hasAttribute('data-describedby-orig')) {
        inp.removeAttribute('aria-describedby');
        return;
      }
      var orig = inp.getAttribute('data-describedby-orig');
      if (orig) inp.setAttribute('aria-describedby', orig);
      else inp.removeAttribute('aria-describedby');
      inp.removeAttribute('data-describedby-orig');
    });
  }

  function setError(key, msg) {
    var wrap = fieldEl(key);
    var p = wrap.querySelector('.field__err');
    var control = wrap.querySelector('input, select');
    p.textContent = msg;
    p.hidden = false;
    wrap.classList.add('field--invalid');
    // A group has no invalid state in ARIA. Link the error on every input.
    if (control.type === 'radio' || control.type === 'checkbox') {
      setGroupDescribedBy(wrap, p.id);
    } else {
      control.setAttribute('aria-invalid', 'true');
    }
  }

  function clearErrors() {
    form.querySelectorAll('.field--invalid').forEach(function (w) {
      w.classList.remove('field--invalid');
      clearGroupDescribedBy(w);
    });
    form.querySelectorAll('.field__err').forEach(function (p) { p.hidden = true; p.textContent = ''; });
    form.querySelectorAll('[aria-invalid]').forEach(function (c) { c.removeAttribute('aria-invalid'); });
    errBox.hidden = true;
    errBox.textContent = '';
  }

  function ensureControlId(control, key) {
    if (!control.id) control.id = 'wl-' + key.replace(/_/g, '-');
    return control.id;
  }

  function showSummary(heading, keys) {
    errBox.textContent = '';
    var head = document.createElement('p');
    head.textContent = heading;
    errBox.appendChild(head);
    if (keys && keys.length) {
      keys.forEach(function (key) {
        var control = fieldEl(key).querySelector('input, select');
        var id = ensureControlId(control, key);
        var p = document.createElement('p');
        var a = document.createElement('a');
        a.setAttribute('href', '#' + id);
        a.textContent = MESSAGES[key];
        a.addEventListener('click', function (ev) {
          ev.preventDefault();
          focusFirst(key);
        });
        p.appendChild(a);
        errBox.appendChild(p);
      });
    }
    errBox.hidden = false;
  }

  function validate() {
    var data = {
      email: form.elements.email.value.trim(),
      audience: (values('audience')[0] || ''),
      govern: values('govern'),
      team_size: form.elements.team_size.value,
      tools: values('tools')
    };
    var bad = [];
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) bad.push('email');
    if (!data.audience) bad.push('audience');
    if (!data.govern.length) bad.push('govern');
    if (!data.team_size) bad.push('team_size');
    return { data: data, bad: bad };
  }

  function focusFirst(key) {
    var c = fieldEl(key).querySelector('input, select');
    if (c) c.focus();
  }

  function fail(msg) {
    // The form keeps everything the visitor typed. Only the message changes.
    showSummary(msg);
    errBox.focus();
  }

  function chosenLabels(name) {
    return Array.prototype.map.call(
      form.querySelectorAll('input[name="' + name + '"]:checked'),
      function (input) { return input.closest('label').textContent.trim(); });
  }

  function showFallback() {
    var contact = document.querySelector('.mailto-cta');
    var address = { user: contact.getAttribute('data-u'), domain: contact.getAttribute('data-d') };
    var size = form.elements.team_size;
    var href = mailtoHref(address, {
      audience: chosenLabels('audience')[0],
      govern: chosenLabels('govern'),
      team_size: size.options[size.selectedIndex].textContent.trim(),
      tools: chosenLabels('tools')
    });
    var p = document.createElement('p');
    var link = document.createElement('a');
    link.href = href;
    link.textContent = address.user + '@' + address.domain;
    p.appendChild(document.createTextNode('Our waitlist is not open yet. Email '));
    p.appendChild(link);
    p.appendChild(document.createTextNode(' and we will add you.'));
    fallback.textContent = '';
    fallback.appendChild(p);
    fallback.hidden = false;
    fallback.focus();
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    if (busy) return;
    function reset() {
      busy = false;
      submit.disabled = false;
      submit.textContent = 'Join the waitlist';
    }
    try {
      fallback.hidden = true;
      clearErrors();
      var r = validate();
      if (r.bad.length) {
        r.bad.forEach(function (k) { setError(k, MESSAGES[k]); });
        showSummary(
          'Fix ' + (r.bad.length === 1 ? 'this field' : 'these ' + r.bad.length + ' fields') + ' and send the form again:',
          r.bad
        );
        errBox.focus();
        reset();
        return;
      }

      var src = (new URLSearchParams(location.search).get('src') || '').replace(/[^a-z0-9-]/gi, '').slice(0, 40);
      var body = {
        email: r.data.email,
        audience: r.data.audience,
        govern: r.data.govern,
        team_size: r.data.team_size,
        tools: r.data.tools,
        source: src
      };

      busy = true;
      submit.disabled = true;
      submit.textContent = 'Sending';
      submitAnswers({
        endpoint: cfg.waitlistEndpoint,
        body: body,
        fetchFn: typeof fetch === 'function' ? fetch.bind(window) : null,
        ui: {
          showConfirmation: function () {
            form.hidden = true;
            done.hidden = false;
            done.focus();
            if (typeof window.gtag === 'function') window.gtag('event', 'waitlist_signup');
          },
          showFallback: showFallback,
          showError: function (status) {
            if (status === 429) {
              fail('There were too many requests. Wait a minute, then send the form again. Your answers are still in the form.');
            } else {
              fail('We could not accept these answers. Check the form and send it again. Your answers are still in the form.');
            }
          }
        }
      }).then(reset, reset);
    } catch (err) {
      try { showFallback(); } catch (fallbackError) {}
      reset();
    }
  });

  // Clear a field's error when the visitor changes it.
  form.addEventListener('change', function (e) {
    var wrap = e.target.closest('[data-field]');
    if (!wrap || !wrap.classList.contains('field--invalid')) return;
    wrap.classList.remove('field--invalid');
    wrap.querySelector('.field__err').hidden = true;
    var c = wrap.querySelector('select, input[type="email"]');
    if (c) c.removeAttribute('aria-invalid');
    clearGroupDescribedBy(wrap);
  });
})();
