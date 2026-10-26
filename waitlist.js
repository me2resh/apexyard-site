/* Waitlist (#122): the site flag for "Start free with GitHub" buttons and the
   waitlist form. Reads window.APEXYARD_SITE from /site-config.js. No dependencies. */
(function () {
  'use strict';

  var cfg = window.APEXYARD_SITE || {};
  var signinOpen = cfg.signinOpen === true;

  // Flag: with the flag on, each button goes to the sign-in. With the flag off,
  // the markup already points to /waitlist, so nothing changes.
  var buttons = document.querySelectorAll('[data-signin]');
  if (signinOpen) {
    buttons.forEach(function (a) { a.setAttribute('href', a.getAttribute('data-signin')); });
  }

  var form = document.getElementById('waitlist-form');
  if (!form) return;

  if (signinOpen) {
    location.replace('https://app.apexyard.ai/signin?src=waitlist');
    return;
  }

  var errBox = document.getElementById('waitlist-errors');
  var done = document.getElementById('waitlist-done');
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

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    if (busy) return;
    clearErrors();
    var r = validate();
    if (r.bad.length) {
      r.bad.forEach(function (k) { setError(k, MESSAGES[k]); });
      showSummary(
        'Fix ' + (r.bad.length === 1 ? 'this field' : 'these ' + r.bad.length + ' fields') + ' and send the form again:',
        r.bad
      );
      errBox.focus();
      return;
    }

    var url = cfg.waitlistEndpoint;
    if (!url) {
      fail('The waitlist is not open yet, so we could not send your answers. Your answers are still in the form. Try again later.');
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
    var ctrl = typeof AbortController === 'function' ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, 15000) : null;

    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(body),
      credentials: 'omit',
      signal: ctrl ? ctrl.signal : undefined
    }).then(function (res) {
      if (res.ok) {
        form.hidden = true;
        done.hidden = false;
        done.focus();
        if (typeof window.gtag === 'function') window.gtag('event', 'waitlist_signup');
        return;
      }
      if (res.status === 400 || res.status === 422) {
        fail('We could not accept these answers. Check the form and send it again. Your answers are still in the form.');
      } else if (res.status === 429) {
        fail('There were too many requests. Wait a minute, then send the form again. Your answers are still in the form.');
      } else {
        fail('We could not save your answers. Your answers are still in the form. Send the form again in a few minutes.');
      }
    }).catch(function () {
      fail('We could not reach the waitlist. Check your connection, then send the form again. Your answers are still in the form.');
    }).then(function () {
      if (timer) clearTimeout(timer);
      busy = false;
      submit.disabled = false;
      submit.textContent = 'Join the waitlist';
    });
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
