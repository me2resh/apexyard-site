#!/usr/bin/env node
// ASD-STE100 lint for the /docs pages.
//
// Rules come from ONE data file (lint/docs-lint-rules.json). The framework
// repository hosts a copy of the same file at docs/docs-lint-rules.json. When
// the release cache has that copy, this lint uses it first.
//
// Usage:
//   node scripts/lint-docs.mjs [options]               lint the generated pages
//   node scripts/lint-docs.mjs [options] FILE.md ...   lint the named files
//
// Options:
//   --rules FILE    the rules file. Default: the framework copy in the release
//                   cache, if it exists, else lint/docs-lint-rules.json.
//   --root DIR      the docs-site folder. Default: the parent of this script.
//   --strict        exit 1 when a finding is in scope.
//   --changed FILE  a list of changed lines: "path:line" or "path:start-end",
//                   one per line. Only findings on these lines are in scope.
//   --scope-only    print only the findings that are in scope.
//   --summary       print the counts per page and the totals only.
//
// Scope:
//   - With --changed: the findings on the listed lines.
//   - Else, page mode: the findings in site-owned text.
//   - Else, file mode: all findings.
//
// Each finding line is "<page>:<line>: <rule>: <detail>". In page mode the
// page is the slug, the line is in src/content/docs/<slug>.md, and the line
// ends with [site] or [framework].
//
// Limits:
//   - The passive check is a heuristic. It finds a form of "be", then up to
//     one adverb, then a past participle. It misses passives without "be" and
//     can flag an adjective that ends in -ed.
//   - A procedure step is a numbered list item. Other text uses the
//     description limit.
//   - The lint ignores code blocks, inline code, HTML lines and URLs.
//   - Site ownership is by exact line match against the strings in
//     content-map.mjs. Text that sync-content.mjs writes from a template
//     counts as framework text.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------- options

function parseArgs(argv) {
  const opts = { root: path.resolve(HERE, '..'), rules: null, strict: false, changed: null, scopeOnly: false, summary: false, files: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const value = () => {
      if (i + 1 >= argv.length) usage(`${a} needs a value.`);
      return argv[++i];
    };
    if (a === '--rules') opts.rules = value();
    else if (a === '--root') opts.root = path.resolve(value());
    else if (a === '--changed') opts.changed = value();
    else if (a === '--strict') opts.strict = true;
    else if (a === '--scope-only') opts.scopeOnly = true;
    else if (a === '--summary') opts.summary = true;
    else if (a === '--help' || a === '-h') usage(null, 0);
    else if (a.startsWith('--')) usage(`Unknown option ${a}.`);
    else opts.files.push(a);
  }
  return opts;
}

function usage(msg, code = 2) {
  if (msg) console.error(`docs-lint: ${msg}`);
  console.error('Usage: lint-docs.mjs [--rules FILE] [--root DIR] [--strict] [--changed FILE] [--scope-only] [--summary] [FILE.md ...]');
  process.exit(code);
}

function fail(msg) {
  console.error(`docs-lint: ${msg}`);
  process.exit(2);
}

// ---------------------------------------------------------------- rules

async function loadContentMap(root) {
  const file = path.join(root, 'content-map.mjs');
  if (!fs.existsSync(file)) return null;
  return import(pathToFileURL(file).href);
}

function resolveRulesPath(opts, map) {
  if (opts.rules) return path.resolve(opts.rules);
  if (map && map.SOURCE && map.SOURCE.tag) {
    const framework = path.join(opts.root, '.cache', `apexyard-${map.SOURCE.tag}`, 'docs', 'docs-lint-rules.json');
    if (fs.existsSync(framework)) return framework;
  }
  return path.join(opts.root, 'lint', 'docs-lint-rules.json');
}

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Word boundaries that keep "just" out of "adjust" and "just-in-time".
function wordRegex(term) {
  const pre = /^[\w']/.test(term) ? "(?<![\\w'-])" : '';
  const post = /[\w']$/.test(term) ? "(?![\\w'-])" : '';
  return new RegExp(pre + esc(term).replace(/\s+/g, '\\s+') + post, 'gi');
}

export function compileRules(raw) {
  for (const key of ['sentenceLength', 'passive', 'banned', 'emDash']) {
    if (!raw[key]) throw new Error(`the rules file has no "${key}" key`);
  }
  const p = raw.passive;
  const aux = p.auxiliaries.map(esc).join('|');
  const adv = p.adverbs.map(esc).join('|');
  const irregular = p.irregular.map(esc).join('|');
  const minStem = Math.max(1, (p.regularMinLength || 4) - p.regularSuffix.length);
  const passive = new RegExp(`\\b(?:${aux})\\s+(?:(?:${adv})\\s+)?((?:[A-Za-z]{${minStem},}${esc(p.regularSuffix)})|(?:${irregular}))(?![\\w'-])`, 'gi');
  return {
    stepMax: raw.sentenceLength.step,
    descMax: raw.sentenceLength.description,
    passive,
    passiveExclude: new Set(p.regularExclude.map((w) => w.toLowerCase())),
    approved: ((raw.approved && raw.approved.terms) || []).map(wordRegex),
    banned: raw.banned.entries.map(([kind, term, use]) => ({ kind, term, use, re: wordRegex(term) })),
    emDash: raw.emDash.characters.map((c) => ({ c, re: new RegExp(esc(c), 'g') })),
    emDashUse: raw.emDash.use,
  };
}

// ---------------------------------------------------------------- markdown

const FENCE = /^\s{0,3}(`{3,}|~{3,})/;

function fenceMask(lines) {
  const mask = new Array(lines.length).fill(false);
  let open = null;
  lines.forEach((line, i) => {
    if (open) {
      mask[i] = true;
      const close = line.match(/^\s{0,3}(`{3,}|~{3,})\s*$/);
      if (close && close[1][0] === open[0] && close[1].length >= open.length) open = null;
    } else {
      const m = line.match(FENCE);
      if (m) {
        mask[i] = true;
        open = m[1];
      }
    }
  });
  return mask;
}

// Remove Markdown and HTML syntax, and keep the words a reader sees.
export function cleanInline(s) {
  return s
    .replace(/[‘’]/g, "'")
    .replace(/`+[^`]*`+/g, 'CODE')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\[([^\]]*)\]\[[^\]]*\]/g, '$1')
    .replace(/<https?:[^>]*>/g, 'URL')
    .replace(/https?:\/\/\S+/g, 'URL')
    .replace(/<[^>]+>/g, '')
    .replace(/\\([|*_`#[\]()])/g, '$1')
    .replace(/\*\*|__|\*/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const STEP = /^\s*\d+[.)]\s+/;
const BULLET = /^\s*[-*+]\s+(?:\[[ xX]\]\s+)?/;

// Split a Markdown file into text segments. Each segment is one heading, one
// table cell, one list item or one paragraph, with the line of each part.
export function segments(text) {
  const lines = text.split('\n');
  const mask = fenceMask(lines);
  const out = [];
  let cur = null;
  const close = () => (cur = null);
  const push = (kind, line, t) => {
    const s = cleanInline(t);
    cur = { kind, parts: [] };
    out.push(cur);
    if (s) cur.parts.push({ line, text: s });
  };

  let start = 0;
  if (lines[0] === '---') {
    const end = lines.indexOf('---', 1);
    if (end > 0) {
      for (let i = 1; i < end; i++) {
        const m = lines[i].match(/^(title|description):\s*(.*)$/);
        if (!m) continue;
        let v = m[2].trim();
        try {
          if (v.startsWith('"')) v = JSON.parse(v);
        } catch {
          // Keep the raw value.
        }
        v = v.replace(/^'(.*)'$/, '$1');
        push(m[1] === 'title' ? 'title' : 'text', i + 1, v);
        close();
      }
      start = end + 1;
    }
  }

  for (let i = start; i < lines.length; i++) {
    let line = lines[i];
    const n = i + 1;
    if (mask[i]) {
      close();
      continue;
    }
    line = line.replace(/^(\s*>)+\s?/, '');
    if (!line.trim() || /^\s*</.test(line) || /^\s*(\*\s*){3,}$|^\s*(-\s*){3,}$/.test(line)) {
      close();
      continue;
    }
    if (/^\s*#{1,6}\s/.test(line)) {
      push('title', n, line.replace(/^\s*#{1,6}\s+/, '').replace(/\s#+\s*$/, ''));
      close();
      continue;
    }
    if (/^\s*\|/.test(line)) {
      close();
      if (/^\s*\|?\s*:?-{2,}/.test(line)) continue;
      const cells = line.trim().replace(/^\||\|$/g, '').split(/(?<!\\)\|/);
      for (const c of cells) {
        push('text', n, c);
        close();
      }
      continue;
    }
    if (STEP.test(line)) {
      push('step', n, line.replace(STEP, ''));
      continue;
    }
    if (BULLET.test(line)) {
      push('text', n, line.replace(BULLET, ''));
      continue;
    }
    if (cur) {
      const s = cleanInline(line);
      if (s) cur.parts.push({ line: n, text: s });
    } else push('text', n, line);
  }
  return out.filter((s) => s.parts.length);
}

// ---------------------------------------------------------------- checks

const ABBREV = /\b(e\.g|i\.e|vs|etc|cf|approx)\./gi;

function joinParts(seg) {
  let text = '';
  const starts = [];
  for (const p of seg.parts) {
    if (text) text += ' ';
    starts.push({ at: text.length, line: p.line });
    text += p.text;
  }
  const lineAt = (off) => {
    let line = starts[0].line;
    for (const s of starts) if (s.at <= off) line = s.line;
    return line;
  };
  return { text, lineAt };
}

function sentences(text) {
  const masked = text.replace(ABBREV, (m) => m.slice(0, -1) + '\u0000');
  const out = [];
  let at = 0;
  // Split at a period, ! or ? that a space or the end follows.
  const ends = [];
  for (let i = 0; i < masked.length; i++) {
    if (/[.!?]/.test(masked[i]) && (i + 1 === masked.length || /\s/.test(masked[i + 1]))) ends.push(i + 1);
  }
  for (const e of ends) {
    out.push({ at, text: text.slice(at, e) });
    at = e;
  }
  if (at < text.length) out.push({ at, text: text.slice(at) });
  return out.filter((s) => s.text.trim());
}

const WORD = /[A-Za-z0-9][A-Za-z0-9'_./-]*/g;
export const countWords = (s) => (s.match(WORD) || []).length;

function overlapsApproved(rules, text, start, end) {
  for (const re of rules.approved) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(text))) {
      if (m.index < end && m.index + m[0].length > start) return true;
    }
  }
  return false;
}

export function lintText(text, rules) {
  const findings = [];
  for (const seg of segments(text)) {
    const { text: t, lineAt } = joinParts(seg);
    if (seg.kind !== 'title') {
      const max = seg.kind === 'step' ? rules.stepMax : rules.descMax;
      const rule = seg.kind === 'step' ? 'sentence-length-step' : 'sentence-length';
      for (const s of sentences(t)) {
        const n = countWords(s.text);
        if (n > max) {
          const off = s.at + (s.text.length - s.text.trimStart().length);
          findings.push({ line: lineAt(off), rule, detail: `${n} words (max ${max}): "${s.text.trim().slice(0, 60)}..."` });
        }
      }
    }
    rules.passive.lastIndex = 0;
    let m;
    while ((m = rules.passive.exec(t))) {
      const part = m[1].toLowerCase();
      if (rules.passiveExclude.has(part) || part.endsWith('eed')) continue;
      if (overlapsApproved(rules, t, m.index, m.index + m[0].length)) continue;
      findings.push({ line: lineAt(m.index), rule: 'passive-voice', detail: `"${m[0]}"` });
    }
    for (const b of rules.banned) {
      b.re.lastIndex = 0;
      while ((m = b.re.exec(t))) {
        if (overlapsApproved(rules, t, m.index, m.index + m[0].length)) continue;
        findings.push({ line: lineAt(m.index), rule: 'banned-word', detail: `${b.kind} "${m[0]}", use: ${b.use}` });
      }
    }
    for (const d of rules.emDash) {
      d.re.lastIndex = 0;
      while ((m = d.re.exec(t))) findings.push({ line: lineAt(m.index), rule: 'em-dash', detail: `use ${rules.emDashUse}` });
    }
  }
  return findings.sort((a, b) => a.line - b.line);
}

// ---------------------------------------------------------------- ownership

const norm = (s) => cleanInline(s.replace(STEP, '').replace(BULLET, '')).toLowerCase();

function siteStrings(map) {
  const tag = (map.SOURCE && map.SOURCE.tag) || '';
  const fill = (s) => String(s).replaceAll('{tag}', tag);
  const bySlug = new Map();
  const summaries = [];
  for (const section of map.SECTIONS || []) {
    summaries.push(section.summary);
    for (const group of section.groups) {
      summaries.push(group.summary);
      for (const page of group.pages || []) {
        const strings = [page.title, page.description];
        if (page.coming) strings.push(page.coming.text);
        if (page.figure) strings.push(page.figure.alt);
        for (const c of page.callouts || []) strings.push(c.text);
        for (const part of page.parts || []) if (part.text !== undefined) strings.push(part.text);
        const set = new Set();
        for (const s of strings) for (const l of fill(s || '').split('\n')) if (norm(l)) set.add(norm(l));
        bySlug.set(page.slug, set);
      }
    }
  }
  return { bySlug, summaries: summaries.filter(Boolean).map(fill) };
}

function lineOwner(lines, n, siteSet, allSite) {
  if (allSite) return 'site';
  if (!siteSet) return 'framework';
  let raw = lines[n - 1] || '';
  const fm = raw.match(/^(title|description):\s*(.*)$/);
  if (fm) {
    try {
      raw = JSON.parse(fm[2]);
    } catch {
      raw = fm[2];
    }
  }
  return siteSet.has(norm(raw.replace(/^(\s*>)+\s?/, ''))) ? 'site' : 'framework';
}

// ---------------------------------------------------------------- runs

function lintPages(opts, map, rules) {
  const navFile = path.join(opts.root, 'src', 'generated', 'nav.json');
  if (!fs.existsSync(navFile)) fail(`${navFile} is missing. Run "npm run sync" first.`);
  const nav = JSON.parse(fs.readFileSync(navFile, 'utf8'));
  const { bySlug, summaries } = siteStrings(map || {});
  const results = [];
  for (const section of nav.sections) {
    for (const group of section.groups) {
      for (const pg of group.pages) {
        const file = path.join(opts.root, 'src', 'content', 'docs', `${pg.slug}.md`);
        if (!fs.existsSync(file)) fail(`${file} is missing. Run "npm run sync" first.`);
        const text = fs.readFileSync(file, 'utf8');
        const lines = text.split('\n');
        const allSite = bySlug.has(pg.slug) && pg.sources.length === 0;
        const findings = lintText(text, rules).map((f) => ({ ...f, owner: lineOwner(lines, f.line, bySlug.get(pg.slug), allSite) }));
        results.push({ page: pg.slug, findings });
      }
    }
  }
  // The section and group summaries show on the docs home. Lines are in content-map.mjs.
  const mapFile = path.join(opts.root, 'content-map.mjs');
  if (fs.existsSync(mapFile) && summaries.length) {
    const mapLines = fs.readFileSync(mapFile, 'utf8').split('\n');
    const findings = [];
    for (const s of summaries) {
      const at = mapLines.findIndex((l) => l.includes(s.slice(0, 40)));
      for (const f of lintText(s, rules)) findings.push({ ...f, line: at + 1 || f.line, owner: 'site' });
    }
    results.push({ page: 'index (content-map.mjs)', findings });
  }
  return results;
}

function lintFiles(opts, rules) {
  return opts.files.map((f) => {
    if (!fs.existsSync(f)) fail(`${f} does not exist.`);
    return { page: f, findings: lintText(fs.readFileSync(f, 'utf8'), rules) };
  });
}

export function parseChanged(text) {
  const map = new Map();
  for (const raw of text.split('\n')) {
    const l = raw.trim();
    if (!l || l.startsWith('#')) continue;
    const m = l.match(/^(.*):(\d+)(?:-(\d+))?$/);
    if (!m) fail(`Bad line in the changed-lines file: "${l}". Use path:line or path:start-end.`);
    if (!map.has(m[1])) map.set(m[1], []);
    map.get(m[1]).push([Number(m[2]), Number(m[3] || m[2])]);
  }
  return map;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const map = await loadContentMap(opts.root);
  const rulesPath = resolveRulesPath(opts, map);
  if (!fs.existsSync(rulesPath)) fail(`Rules file ${rulesPath} does not exist.`);
  let rules;
  try {
    rules = compileRules(JSON.parse(fs.readFileSync(rulesPath, 'utf8')));
  } catch (e) {
    fail(`Rules file ${rulesPath} is not valid: ${e.message}`);
  }
  const fileMode = opts.files.length > 0;
  const results = fileMode ? lintFiles(opts, rules) : lintPages(opts, map, rules);

  let scopeName;
  let inScope;
  if (opts.changed) {
    if (!fs.existsSync(opts.changed)) fail(`Changed-lines file ${opts.changed} does not exist.`);
    const changed = parseChanged(fs.readFileSync(opts.changed, 'utf8'));
    scopeName = 'changed lines';
    inScope = (page, f) => (changed.get(page) || []).some(([a, b]) => f.line >= a && f.line <= b);
  } else if (fileMode) {
    scopeName = 'all findings';
    inScope = () => true;
  } else {
    scopeName = 'site-owned text';
    inScope = (page, f) => f.owner === 'site';
  }

  console.log(`docs-lint: rules from ${path.relative(process.cwd(), rulesPath) || rulesPath}`);
  const byRule = {};
  const byOwner = {};
  let total = 0;
  let scoped = 0;
  let pagesWith = 0;
  for (const r of results) {
    const shown = r.findings.filter((f) => !opts.scopeOnly || inScope(r.page, f));
    const n = r.findings.filter((f) => inScope(r.page, f)).length;
    if (r.findings.length) pagesWith++;
    total += r.findings.length;
    scoped += n;
    for (const f of r.findings) {
      byRule[f.rule] = (byRule[f.rule] || 0) + 1;
      if (f.owner) byOwner[f.owner] = (byOwner[f.owner] || 0) + 1;
    }
    if (!shown.length) continue;
    console.log(`== ${r.page}: ${r.findings.length} findings, ${n} in scope`);
    if (opts.summary) continue;
    for (const f of shown) console.log(`${r.page}:${f.line}: ${f.rule}: ${f.detail}${f.owner ? ` [${f.owner}]` : ''}`);
  }
  const fmt = (o) => Object.entries(o).sort().map(([k, v]) => `${k} ${v}`).join(', ') || 'none';
  console.log(`docs-lint: ${results.length} pages, ${total} findings in ${pagesWith} pages`);
  console.log(`  by rule: ${fmt(byRule)}`);
  if (!fileMode) console.log(`  by owner: ${fmt(byOwner)}`);
  console.log(`  in scope (${scopeName}): ${scoped}`);
  if (opts.strict && scoped > 0) {
    console.log(`docs-lint: strict mode, ${scoped} findings in scope. Exit 1.`);
    process.exit(1);
  }
  console.log(opts.strict ? 'docs-lint: strict mode, 0 findings in scope.' : 'docs-lint: report only, exit 0. Use --strict to fail on findings in scope.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
