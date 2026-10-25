// The public deny list holds generic terms only. Specific names come from the
// optional private file in DOCS_PRIVATE_TERMS, which stays outside this repo.
// These tests need no private file.
import test from 'node:test';
import assert from 'node:assert/strict';
import { DENY_TERMS, EXCLUDED_PREFIXES } from '../content-map.mjs';

const deny = new RegExp(DENY_TERMS.join('|'), 'i');

test('generic deny terms match paid-component and price wording', () => {
  for (const s of ['a premium component', 'see the pricing page', 'the price is set', 'a paid plan', 'paid tiers']) {
    assert.ok(deny.test(s), s);
  }
});

test('generic deny terms leave ordinary text alone', () => {
  for (const s of ['Rex reviews each pull request', 'the merge gate stays closed', 'a priceless example']) {
    assert.ok(!deny.test(s), s);
  }
});

test('the public deny list holds only the generic patterns', () => {
  assert.deepEqual(DENY_TERMS, ['\\bpremium\\b', '\\bpaid (?:tier|plan|component|feature)s?\\b', '\\bpric(?:e|es|ing)\\b']);
});

test('internal source folders are excluded', () => {
  const prefixes = EXCLUDED_PREFIXES.map((e) => e.prefix);
  for (const p of ['docs/spike', 'docs/prds/', 'docs/technical-designs/', 'docs/designs/', 'docs/perf/', 'docs/quality-regression/', 'docs/eval-agents/', 'docs/agdr/']) {
    assert.ok(prefixes.includes(p), p);
  }
});
