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
  assert(!params.get('body').includes(email));
  async function result(endpoint, fetchFn) {
    const calls = [];
    await api.submitAnswers({ endpoint, body: { email, ...answers }, fetchFn, ui: {
      showConfirmation: () => calls.push('confirmation'),
      showFallback: () => { calls.push('fallback'); assert(!decodeURIComponent(href).includes(email)); },
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
  assert.deepStrictEqual(await result('/submit', async () => ({ ok: false, status: 500 })), ['fallback']);
  for (const status of [400, 422, 429]) {
    assert.deepStrictEqual(await result('/submit', async () => ({ ok: false, status })), [status]);
  }
  console.log('PASS  Failed requests show the correct message');
  for (const src of ['home-hero', 'pricing-free', 'gate-head', 'gate-free']) {
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
  let count = 0;
  for (const name of fs.readdirSync(root).filter(name => name.endsWith('.html'))) {
    for (const m of read(name).matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/gi)) {
      const data = attrs(m[1]);
      assert(!/^https?:\/\/app\.apexyard\.ai\/signin\b/.test(data.href || ''), name);
      if (!Object.hasOwn(data, 'data-signin')) continue;
      const text = m[2].replace(/<[^>]*>/g, '').trim();
      if (name !== 'waitlist.html') assert.notStrictEqual(text, 'Start free with GitHub', name);
      if (['index.html', 'pricing.html', 'gate.html'].includes(name)) {
        count++;
        assert.strictEqual(text, 'Join the waitlist', name);
        assert(data.href.startsWith('/waitlist'), name);
        assert.strictEqual(data['data-waitlist'], data.href, name);
      }
    }
  }
  assert.strictEqual(count, 4);
  console.log('PASS  Static links use the waitlist state');
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
