#!/usr/bin/env bash
# Check the waitlist links and submit results.
set -uo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if node - "$root" <<'NODE'
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const root = process.argv[2];
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const context = {
  window: { APEXYARD_SITE: { signinOpen: false, waitlistEndpoint: '' } },
  document: { querySelectorAll: () => [], getElementById: () => null },
  module: { exports: {} }, setTimeout, clearTimeout, AbortController
};
vm.runInNewContext(read('waitlist.js'), context);
const api = context.window.ApexYardWaitlist;
assert.strictEqual(api, context.module.exports);
function attrs(tag) {
  return Object.fromEntries([...tag.matchAll(/([\w-]+)="([^"]*)"/g)].map(m => [m[1], m[2]]));
}
function anchor(data) {
  return { textContent: '', getAttribute: key => data[key] || null,
    setAttribute: (key, value) => { data[key] = value; } };
}
function node(tag = '') {
  const data = {};
  let text = '';
  return {
    tag, children: [], hidden: true, disabled: false, focused: false,
    get textContent() { return text; },
    set textContent(value) { text = value; this.children = []; },
    appendChild(child) { this.children.push(child); return child; },
    setAttribute(key, value) { data[key] = value; },
    getAttribute(key) { return data[key] || null; },
    hasAttribute(key) { return Object.hasOwn(data, key); },
    removeAttribute(key) { delete data[key]; },
    addEventListener() {},
    focus() { this.focused = true; },
    classList: { add() {}, remove() {}, contains() { return false; } }
  };
}
function page(fetchFn, contact) {
  const ids = Object.fromEntries(['form', 'errors', 'done', 'fallback', 'submit', 'noscript']
    .map(key => [key, node()]));
  const form = ids.form;
  const labels = { audience: 'Startup team', govern: 'Code', tools: 'Agent tools' };
  const inputs = Object.fromEntries(Object.entries(labels).map(([key, label]) => {
    const input = node('input');
    input.value = key;
    input.closest = () => ({ textContent: label });
    return [key, input];
  }));
  form.elements = {
    email: { value: 'typed@example.test' },
    team_size: { value: '2-10', options: [{ textContent: '2 to 10 people' }], selectedIndex: 0 }
  };
  form.querySelectorAll = selector => {
    const match = selector.match(/input\[name="(\w+)"\]:checked/);
    return match ? [inputs[match[1]]] : [];
  };
  const wrappers = {};
  form.querySelector = selector => {
    const key = selector.match(/data-field="(\w+)"/)[1];
    if (!wrappers[key]) {
      const wrap = node();
      const error = node();
      const control = inputs[key] || node('input');
      wrap.querySelector = sel => sel === '.field__err' ? error : control;
      wrap.querySelectorAll = () => inputs[key] ? [control] : [];
      wrappers[key] = wrap;
    }
    return wrappers[key];
  };
  form.addEventListener = (event, handler) => { if (event === 'submit') form.submit = handler; };
  const ctx = {
    window: { APEXYARD_SITE: { signinOpen: false, waitlistEndpoint: '/submit' } },
    document: {
      querySelectorAll: () => [],
      getElementById: id => ids[id.replace('waitlist-', '')],
      querySelector: () => ({ getAttribute: key => contact[key] }),
      createElement: tag => node(tag),
      createTextNode: text => { const n = node(); n.textContent = text; return n; }
    },
    location: { search: '', replace() {} }, URLSearchParams,
    fetch: fetchFn, setTimeout, clearTimeout, AbortController
  };
  vm.runInNewContext(read('waitlist.js'), ctx);
  ids.send = () => form.submit({ preventDefault() {} });
  return ids;
}
async function settle() {
  await new Promise(resolve => setImmediate(resolve));
}
function resetCheck(p) {
  assert.strictEqual(p.submit.disabled, false);
  assert.strictEqual(p.submit.textContent, 'Join the waitlist');
}
async function pageTests(contact) {
  let calls = 0;
  let rejectRequest;
  const p = page(() => {
    calls++;
    return new Promise((resolve, reject) => { rejectRequest = reject; });
  }, contact);
  p.send();
  assert.strictEqual(p.submit.disabled, true);
  assert.strictEqual(p.submit.textContent, 'Sending');
  p.send();
  await Promise.resolve();
  assert.strictEqual(calls, 1);
  rejectRequest(Error('Network error'));
  await settle();
  resetCheck(p);
  assert.strictEqual(p.form.hidden, false);
  assert.strictEqual(p.form.elements.email.value, 'typed@example.test');
  assert.strictEqual(p.fallback.hidden, false);
  assert(p.fallback.focused);
  function links(n) { return (n.tag === 'a' ? [n] : []).concat(...n.children.map(links)); }
  const href = links(p.fallback)[0].href;
  assert(href.startsWith('mailto:'));
  assert(!decodeURIComponent(href).includes('typed@example.test'));
  const body = new URL(href).searchParams.get('body');
  for (const answer of ['Startup team', 'Code', '2 to 10 people', 'Agent tools']) assert(body.includes(answer));
  console.log('PASS  Page fallback keeps answers and omits the typed email');
  console.log('PASS  Page blocks a second submit and resets the button');
  const thrown = page(async () => ({ ok: false, status: 503 }), contact);
  let focuses = 0;
  thrown.fallback.focus = () => { if (++focuses === 1) throw Error('Focus failed'); };
  thrown.send();
  await settle();
  resetCheck(thrown);
  assert.strictEqual(focuses, 2);
  const validation = page(() => { throw Error('Unexpected fetch'); }, contact);
  Object.defineProperty(validation.form.elements.email, 'value', { get() { throw Error('Read failed'); } });
  validation.send();
  resetCheck(validation);
  assert.strictEqual(validation.fallback.hidden, false);
  console.log('PASS  Page throws still reset the button');
  for (const status of [400, 422, 429]) {
    const failed = page(async () => ({ ok: false, status }), contact);
    failed.send();
    await settle();
    assert.strictEqual(failed.errors.hidden, false);
    resetCheck(failed);
  }
  console.log('PASS  Page field replies show errors and reset the button');
  const success = page(async () => ({ ok: true }), contact);
  success.send();
  await settle();
  assert.strictEqual(success.form.hidden, true);
  assert.strictEqual(success.done.hidden, false);
  resetCheck(success);
  console.log('PASS  Page success hides the form and shows confirmation');
}
async function main() {
  const answers = { audience: 'Startup team', govern: ['Code', 'Changes'], team_size: '2 to 10 people', tools: [] };
  const contactTag = read('waitlist.html').match(/<a\b[^>]*class="mailto-cta"[^>]*>/)[0];
  const contact = attrs(contactTag);
  const href = api.mailtoHref({ user: contact['data-u'], domain: contact['data-d'] }, answers);
  assert(href.startsWith('mailto:'));
  const params = new URL(href).searchParams;
  assert.strictEqual(params.get('subject'), 'Join the ApexYard waitlist');
  assert.strictEqual(params.get('body'), 'Who it is for: Startup team\nWhat to govern: Code, Changes\nTeam size: 2 to 10 people\nAgent tools: Not given');
  const email = 'typed@example.test';
  async function result(endpoint, fetchFn, timeoutMs) {
    const calls = [];
    await api.submitAnswers({ endpoint, body: { email, ...answers }, fetchFn, timeoutMs, ui: {
      showConfirmation: () => calls.push('confirmation'),
      showFallback: () => calls.push('fallback'),
      showError: status => calls.push(status)
    } });
    return calls;
  }
  let fetchCalls = 0;
  assert.deepStrictEqual(await result('', () => { fetchCalls++; }), ['fallback']);
  assert.strictEqual(fetchCalls, 0);
  console.log('PASS  Empty endpoint shows the email link');
  assert.deepStrictEqual(await result('/submit', async () => ({ ok: true })), ['confirmation']);
  console.log('PASS  A successful reply shows the confirmation');
  assert.deepStrictEqual(await result('/submit', async () => { throw Error('Network error'); }), ['fallback']);
  console.log('PASS  Network errors show fallback');
  let signal;
  assert.deepStrictEqual(await result('/submit', (_, init) => {
    signal = init.signal;
    return new Promise((resolve, reject) => signal.addEventListener('abort', () => reject(Error('Aborted'))));
  }, 20), ['fallback']);
  assert(signal.aborted);
  console.log('PASS  Timeout aborts the request and shows fallback');
  assert.deepStrictEqual(await result('/submit', () => { throw Error('Fetch failed'); }), ['fallback']);
  console.log('PASS  A thrown fetch shows fallback');
  for (const status of [500, 503]) {
    assert.deepStrictEqual(await result('/submit', async () => ({ ok: false, status })), ['fallback']);
  }
  console.log('PASS  Server errors show fallback');
  for (const status of [400, 422, 429]) {
    assert.deepStrictEqual(await result('/submit', async () => ({ ok: false, status })), [status]);
  }
  for (const status of [403, 404]) {
    assert.deepStrictEqual(await result('/submit', async () => ({ ok: false, status })), ['fallback']);
  }
  console.log('PASS  Client errors show the correct message');
  for (const status of [200, 400]) {
    let fallbacks = 0;
    await api.submitAnswers({ endpoint: '/submit', fetchFn: async () => ({ ok: status === 200, status }), ui: {
      showConfirmation() { throw Error('Callback failed'); },
      showError() { throw Error('Callback failed'); },
      showFallback() { fallbacks++; }
    } });
    assert.strictEqual(fallbacks, 1);
  }
  await api.submitAnswers({ endpoint: '', ui: { showFallback() { throw Error('Fallback failed'); } } });
  console.log('PASS  Thrown callbacks resolve and try fallback');
  await pageTests(contact);

  for (const src of ['home-hero', 'pricing-free', 'gate-head']) {
    const data = { href: '/waitlist?src=' + src, 'data-signin': 'https://app.apexyard.ai/signin?src=' + src };
    const a = anchor(data);
    for (const open of [false, true, false]) {
      api.applyLinks([a], open);
      assert.strictEqual(a.textContent, open ? 'Start free with GitHub' : 'Join the waitlist');
      assert.strictEqual(data.href, open ? data['data-signin'] : '/waitlist?src=' + src);
      assert.strictEqual(data['data-waitlist'], '/waitlist?src=' + src);
    }
  }
  console.log('PASS  Both flag states set the label and target');
  const configContext = { window: {} };
  vm.runInNewContext(read('site-config.js'), configContext);
  const open = configContext.window.APEXYARD_SITE.signinOpen;
  const expectedLabel = open ? 'Start free with GitHub' : 'Join the waitlist';
  const expectedHref = open ? 'https://app.apexyard.ai/signin' : '/waitlist';
  let count = 0;
  for (const name of fs.readdirSync(root).filter(name => name.endsWith('.html'))) {
    for (const m of read(name).matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/gi)) {
      const data = attrs(m[1]);
      if (!Object.hasOwn(data, 'data-signin')) assert(!/^https?:\/\/app\.apexyard\.ai\/signin\b/.test(data.href || ''), name);
      if (!Object.hasOwn(data, 'data-signin')) continue;
      const text = m[2].replace(/<[^>]*>/g, '').trim();
      if (name !== 'waitlist.html') assert.strictEqual(text, expectedLabel, name);
      if (['index.html', 'pricing.html', 'gate.html'].includes(name)) {
        count++;
        assert.strictEqual(text, expectedLabel, name);
        assert(data.href.startsWith(expectedHref), name);
        assert(data['data-waitlist'].startsWith('/waitlist'), name);
      }
    }
  }
  assert.strictEqual(count, 3);
  console.log('PASS  Static links match the flag');
  const fallback = attrs(read('waitlist.html').match(/<div\b[^>]*id="waitlist-fallback"[^>]*>/)[0]);
  assert.strictEqual(fallback.role, 'status');
  assert.strictEqual(fallback.tabindex, '-1');
  assert.strictEqual(fallback['aria-live'], 'polite');
  console.log('PASS  The fallback has status and focus attributes');
}
main().catch(err => { console.error('FAIL  ' + err.stack); process.exitCode = 1; });
NODE
then
  printf 'PASS  Waitlist tests\n'
else
  printf 'FAIL  Waitlist tests\n'
  exit 1
fi
