#!/usr/bin/env node
// Checks on the built docs (dist/) and the generated data (src/generated/).
//
//   1. Page counts: each page in nav.json has a built file, the built page
//      count equals the nav total, and the counts on the home page match.
//   2. Links: each internal link resolves to a file, and each #anchor to an
//      id in that file. Links to the rest of the site resolve under the
//      site root. External links are left to link-check.yml.
//   3. Exclusions: no page reads an excluded source, and no built page or
//      Markdown copy contains a deny term (except allowlisted pages).
//      DOCS_PRIVATE_TERMS adds the private term list when it is set.
//   4. Page parts: each article has one h1, a breadcrumb, Copy link,
//      Copy for AI, and Edit on GitHub when it has a source.
//
// Exit 0 when all checks pass. Exit 1 and list each failure otherwise.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { EXCLUDED_PREFIXES, DENY_TERMS, DENY_ALLOW } from '../content-map.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIST = process.env.DOCS_DIST || path.join(ROOT, 'dist');
const SITE = path.resolve(ROOT, '..');
const nav = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'generated', 'nav.json'), 'utf8'));

const failures = [];
const fail = (m) => failures.push(m);

function* files(dir, ext) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* files(p, ext);
    else if (p.endsWith(ext)) yield p;
  }
}

const rel = (p) => path.relative(DIST, p).split(path.sep).join('/');
const isArticleFile = (r) => !r.startsWith('_astro/') && !r.startsWith('pagefind/') && r !== 'index.html';

// ------------------------------------------------------------ 1. counts

const navPages = nav.sections.flatMap((s) => s.groups.flatMap((g) => g.pages.map((p) => ({ ...p, group: g, section: s }))));
const built = [...files(DIST, '.html')].map(rel).filter(isArticleFile);

if (navPages.length !== nav.total) fail(`counts: nav lists ${navPages.length} pages but its total is ${nav.total}.`);
if (built.length !== nav.total) fail(`counts: dist has ${built.length} article pages but nav.json has ${nav.total}.`);
for (const p of navPages) {
  if (!fs.existsSync(path.join(DIST, `${p.slug}.html`))) fail(`counts: page ${p.slug} is in nav.json but not built.`);
}
for (const s of nav.sections) {
  const sum = s.groups.reduce((n, g) => n + g.pages.length, 0);
  if (sum !== s.count) fail(`counts: section ${s.id} says ${s.count} pages but its groups hold ${sum}.`);
}

const home = fs.readFileSync(path.join(DIST, 'index.html'), 'utf8');
const plural = (n) => `${n} ${n === 1 ? 'page' : 'pages'}`;
for (const s of nav.sections) {
  const sectionBlock = home.match(new RegExp(`<h2 id="${s.id}"[^>]*>[^<]*</h2>\\s*<p class="ay-index__count"[^>]*>([^<]*)</p>`));
  if (!sectionBlock || sectionBlock[1].trim() !== plural(s.count)) fail(`counts: home shows "${sectionBlock?.[1]}" for ${s.id}, expected "${plural(s.count)}".`);
  for (const g of s.groups) {
    const row = home.match(new RegExp(`<li class="ay-row"[^>]*id="${g.id}"[\\s\\S]*?<p class="ay-row__count"[^>]*>([^<]*)</p>`));
    if (!row || row[1].trim() !== plural(g.pages.length)) fail(`counts: home shows "${row?.[1]}" for group ${g.id}, expected "${plural(g.pages.length)}".`);
  }
}

// ------------------------------------------------------------ 2. links

// Expressive Code keeps the raw code in a data-code attribute for its copy
// button. That text is not markup, so remove it before reading tags.
const stripCodeAttrs = (html) => html.replace(/\sdata-code="[^"]*"/g, '');

const idCache = new Map();
function idsOf(file) {
  if (!idCache.has(file)) {
    const html = fs.readFileSync(file, 'utf8');
    idCache.set(file, new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1])));
  }
  return idCache.get(file);
}

function targetFile(url) {
  let p = url.split('#')[0].split('?')[0];
  if (p === '/docs' || p === '/docs/') return path.join(DIST, 'index.html');
  if (p.endsWith('/')) p = p.slice(0, -1);
  const hasExt = /\.[a-zA-Z0-9_]+$/.test(p);
  if (p.startsWith('/docs/')) return path.join(DIST, p.slice(6) + (hasExt ? '' : '.html'));
  if (p === '' || p === '/') return path.join(SITE, 'index.html');
  return path.join(SITE, p.slice(1) + (hasExt ? '' : '.html'));
}

let linkCount = 0;
for (const file of files(DIST, '.html')) {
  const r = rel(file);
  if (r.startsWith('pagefind/')) continue;
  const html = stripCodeAttrs(fs.readFileSync(file, 'utf8'));
  const urls = [];
  for (const tag of html.matchAll(/<(?:a|link|img|script|source|area|iframe)\b[^>]*>/gi)) {
    for (const a of tag[0].matchAll(/\s(?:href|src)="([^"]+)"/g)) urls.push(a[1]);
  }
  for (const raw of urls) {
    const url = raw.replace(/&amp;/g, '&');
    if (/^(https?:|mailto:|data:|javascript:|\/\/)/.test(url)) continue;
    linkCount++;
    if (url.startsWith('#')) {
      const id = decodeURIComponent(url.slice(1));
      if (id && id !== '_top' && !idsOf(file).has(id)) fail(`links: ${r} links to missing anchor ${url}.`);
      continue;
    }
    if (!url.startsWith('/')) {
      fail(`links: ${r} has a relative link ${url}. Use a root-relative link.`);
      continue;
    }
    const target = targetFile(url);
    if (!fs.existsSync(target)) {
      fail(`links: ${r} links to ${url}, which does not resolve.`);
      continue;
    }
    const hash = url.split('#')[1];
    if (hash && target.endsWith('.html') && target.startsWith(DIST) && !idsOf(target).has(decodeURIComponent(hash))) {
      fail(`links: ${r} links to ${url}, but the anchor is missing.`);
    }
  }
}

// ------------------------------------------------------------ 3. exclusions

for (const p of navPages) {
  for (const s of p.sources || []) {
    const hit = EXCLUDED_PREFIXES.find((e) => s.startsWith(e.prefix));
    if (hit) fail(`exclusions: ${p.slug} reads ${s}, which is under ${hit.prefix}.`);
  }
}

const deny = new RegExp(DENY_TERMS.join('|'), 'i');
let privateRe = null;
if (process.env.DOCS_PRIVATE_TERMS) {
  const terms = fs
    .readFileSync(process.env.DOCS_PRIVATE_TERMS, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  if (terms.length) privateRe = new RegExp(`(?<![\\w./-])(?:${terms.join('|')})(?![\\w-])`, 'i');
}

function visibleText(html) {
  const main = html.match(/<main[\s\S]*?<\/main>/);
  return (main ? main[0] : html)
    .replace(/<script[\s\S]*?<\/script>/g, ' ')
    .replace(/<style[\s\S]*?<\/style>/g, ' ')
    .replace(/<[^>]+>/g, ' ');
}

for (const file of files(DIST, '.html')) {
  const r = rel(file);
  if (r.startsWith('pagefind/')) continue;
  const slug = r.replace(/\.html$/, '');
  const text = visibleText(fs.readFileSync(file, 'utf8'));
  const m = text.match(deny);
  if (m && !DENY_ALLOW[slug]) fail(`exclusions: ${r} contains the deny term "${m[0]}".`);
  if (privateRe && privateRe.test(text)) fail(`exclusions: ${r} names a term from the private list.`);
}
for (const file of [...files(DIST, '.md'), ...files(DIST, '.txt')]) {
  const r = rel(file);
  const slug = r.replace(/\.md$/, '');
  const text = fs.readFileSync(file, 'utf8');
  const m = text.match(deny);
  if (m && !DENY_ALLOW[slug]) fail(`exclusions: ${r} contains the deny term "${m[0]}".`);
  if (privateRe && privateRe.test(text)) fail(`exclusions: ${r} names a term from the private list.`);
}
for (const p of EXCLUDED_PREFIXES) {
  const dir = p.prefix.replace(/^docs\//, '');
  if (dir.endsWith('/') && fs.existsSync(path.join(DIST, dir))) fail(`exclusions: dist has a ${dir} folder, which maps to an excluded source.`);
}

// ------------------------------------------------------------ 4. page parts

for (const p of navPages) {
  const file = path.join(DIST, `${p.slug}.html`);
  if (!fs.existsSync(file)) continue;
  const html = stripCodeAttrs(fs.readFileSync(file, 'utf8'));
  const h1 = (html.match(/<h1[\s>]/g) || []).length;
  if (h1 !== 1) fail(`parts: ${p.slug} has ${h1} h1 elements.`);
  if (!html.includes('aria-label="Breadcrumb"')) fail(`parts: ${p.slug} has no breadcrumb.`);
  if (!html.includes('data-copy-link')) fail(`parts: ${p.slug} has no Copy link button.`);
  if (!html.includes(`data-md-url="/docs/${p.slug}.md"`)) fail(`parts: ${p.slug} has no Copy for AI button.`);
  if (!fs.existsSync(path.join(DIST, `${p.slug}.md`))) fail(`parts: ${p.slug} has no Markdown copy.`);
  const hasFileSource = (p.sources || []).some((s) => !s.endsWith('/'));
  if (hasFileSource && !/>\s*Edit on GitHub\s*</.test(html)) fail(`parts: ${p.slug} has no Edit on GitHub link.`);
}
if (!fs.existsSync(path.join(DIST, 'pagefind', 'pagefind.js'))) fail('search: dist/pagefind/pagefind.js is missing.');
if (!fs.existsSync(path.join(DIST, 'llms.txt'))) fail('agents: dist/llms.txt is missing.');

// ------------------------------------------------------------ report

console.log(`check-output: ${built.length} pages, ${linkCount} internal links, ${nav.sections.map((s) => `${s.title} ${s.count}`).join(', ')}`);
if (failures.length) {
  for (const f of failures) console.error(`FAIL ${f}`);
  console.error(`check-output: ${failures.length} failures`);
  process.exit(1);
}
console.log('check-output: all checks pass');
