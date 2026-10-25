#!/usr/bin/env node
// Check the staged upload layout from build-docs.sh against the CloudFront
// URL rule, so /docs serves the new docs home and the search index loads.
//
// The rule matches the staging CloudFront function (clean URLs):
//   "/" -> "/index.html"; a path with a file extension stays as is;
//   any other path drops a trailing slash and gets ".html".
//
// Usage: node scripts/check-layout.mjs <out-dir>
// <out-dir> holds docs.html and docs/, as the deploy uploads them.

import fs from 'node:fs';
import path from 'node:path';

const out = process.argv[2];
if (!out) {
  console.error('usage: check-layout.mjs <out-dir>');
  process.exit(2);
}

function cloudfrontKey(uri) {
  if (uri === '/' || uri === '') return 'index.html';
  if (/\.[a-zA-Z0-9]+$/.test(uri)) return uri.slice(1);
  if (uri.endsWith('/')) uri = uri.slice(0, -1);
  return `${uri.slice(1)}.html`;
}

const failures = [];
function expectFile(uri, mustContain) {
  const key = cloudfrontKey(uri);
  const file = path.join(out, key);
  if (!fs.existsSync(file)) {
    failures.push(`${uri} -> ${key}: missing`);
    return;
  }
  if (mustContain) {
    const text = fs.readFileSync(file, 'utf8');
    if (!text.includes(mustContain)) failures.push(`${uri} -> ${key}: does not contain ${mustContain}`);
  }
  console.log(`  ok    ${uri} -> ${key}`);
}

// The docs home, with and without a trailing slash.
expectFile('/docs', 'class="ay-index');
expectFile('/docs/', 'class="ay-index');
// An article, the search index, a Markdown copy and the agent page list.
expectFile('/docs/quickstart/install', 'aria-label="Breadcrumb"');
expectFile('/docs/reference/skills/status', 'aria-label="Breadcrumb"');
expectFile('/docs/pagefind/pagefind.js');
expectFile('/docs/quickstart/install.md');
expectFile('/docs/llms.txt');

// Each asset that the docs home loads must be in the upload.
const home = fs.readFileSync(path.join(out, 'docs.html'), 'utf8');
for (const m of home.matchAll(/(?:href|src)="(\/docs\/_astro\/[^"]+)"/g)) expectFile(m[1]);

if (failures.length) {
  for (const f of failures) console.error(`FAIL  ${f}`);
  process.exit(1);
}
console.log('check-layout: /docs resolves to the new docs home, and the search index is in the upload');
