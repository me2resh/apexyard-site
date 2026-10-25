#!/usr/bin/env node
// Generate the /docs pages from me2resh/apexyard at the pinned tag.
//
// Inputs:
//   content-map.mjs              structure: groups, pages, source paths
//   APEXYARD_REPO (optional)     a local clone that has the pinned tag
//   DOCS_PRIVATE_TERMS (optional) a file outside this repo, one term per line
//
// Outputs (all generated, all gitignored):
//   src/content/docs/**.md       Starlight pages
//   public/**.md                 Markdown alternates for "Copy for AI"
//   public/llms.txt              page list for agents
//   src/generated/nav.json       groups, pages and counts
//   src/generated/exclusions.json what the build left out, and why

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import GithubSlugger from 'github-slugger';
import { SOURCE, SECTIONS, EXCLUDED_PREFIXES, DENY_TERMS, DENY_ALLOW } from '../content-map.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE = path.join(ROOT, '.cache', `apexyard-${SOURCE.tag}`);
const OUT_CONTENT = path.join(ROOT, 'src', 'content', 'docs');
const OUT_PUBLIC = path.join(ROOT, 'public');
const OUT_GEN = path.join(ROOT, 'src', 'generated');
const BASE = '/docs';

// ---------------------------------------------------------------- source

function git(args, opts = {}) {
  return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...opts }).trim();
}

function fetchSource() {
  const stamp = path.join(CACHE, '.source-commit');
  if (fs.existsSync(stamp) && fs.readFileSync(stamp, 'utf8').trim() === SOURCE.commit) return;
  fs.rmSync(CACHE, { recursive: true, force: true });
  fs.mkdirSync(CACHE, { recursive: true });
  const local = process.env.APEXYARD_REPO;
  if (local) {
    const commit = git(['-C', local, 'rev-parse', `${SOURCE.tag}^{commit}`]);
    if (commit !== SOURCE.commit) fail(`Tag ${SOURCE.tag} in ${local} is ${commit}. The content map pins ${SOURCE.commit}.`);
    const tar = execFileSync('git', ['-C', local, 'archive', '--format=tar', SOURCE.tag], { maxBuffer: 1 << 30 });
    execFileSync('tar', ['-x', '-C', CACHE], { input: tar });
  } else {
    git(['clone', '--quiet', '--depth', '1', '--branch', SOURCE.tag, `${SOURCE.url}.git`, CACHE]);
    const commit = git(['-C', CACHE, 'rev-parse', 'HEAD']);
    if (commit !== SOURCE.commit) fail(`Tag ${SOURCE.tag} on ${SOURCE.url} is ${commit}. The content map pins ${SOURCE.commit}.`);
    fs.rmSync(path.join(CACHE, '.git'), { recursive: true, force: true });
  }
  fs.writeFileSync(stamp, SOURCE.commit + '\n');
}

function fail(msg) {
  console.error(`sync-content: ${msg}`);
  process.exit(1);
}

function readSource(rel) {
  checkNotExcluded(rel);
  const file = path.join(CACHE, rel);
  if (!fs.existsSync(file)) fail(`Source file ${rel} is not in ${SOURCE.tag}. Update content-map.mjs.`);
  return fs.readFileSync(file, 'utf8');
}

function checkNotExcluded(rel) {
  const hit = EXCLUDED_PREFIXES.find((e) => rel.startsWith(e.prefix));
  if (hit) fail(`Source ${rel} is under the excluded prefix ${hit.prefix} (${hit.reason}).`);
}

let TREE_FILES = null;
function treeFiles() {
  if (TREE_FILES) return TREE_FILES;
  const out = new Set();
  const dirs = new Set();
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const abs = path.join(dir, entry.name);
      const rel = path.relative(CACHE, abs).split(path.sep).join('/');
      if (entry.isDirectory()) {
        dirs.add(rel);
        walk(abs);
      } else out.add(rel);
    }
  })(CACHE);
  TREE_FILES = { files: out, dirs };
  return TREE_FILES;
}

// ---------------------------------------------------------------- markdown

const FENCE = /^\s{0,3}(`{3,}|~{3,})/;

// Walk lines and report which lines are inside a fenced code block.
function fenceMask(lines) {
  const mask = new Array(lines.length).fill(false);
  let open = null;
  lines.forEach((line, i) => {
    const m = line.match(FENCE);
    if (open) {
      mask[i] = true;
      const close = line.match(/^\s{0,3}(`{3,}|~{3,})\s*$/);
      if (close && close[1][0] === open[0] && close[1].length >= open.length) open = null;
    } else if (m) {
      mask[i] = true;
      open = m[1];
    }
  });
  return mask;
}

function headings(lines) {
  const mask = fenceMask(lines);
  const out = [];
  lines.forEach((line, i) => {
    if (mask[i]) return;
    const m = line.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/);
    if (m) out.push({ level: m[1].length, text: m[2].trim(), line: i });
  });
  return out;
}

// Front matter: a lenient reader. Claude Code skill files use plain
// `key: value` lines that strict YAML can reject (for example a colon in a
// description), so this reader splits each line on the first colon.
function matter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!m) return { data: {}, content: text };
  const data = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) data[kv[1]] = kv[2].replace(/^(["'])(.*)\1$/, '$2');
  }
  return { data, content: text.slice(m[0].length) };
}

function stripFrontMatter(text) {
  return matter(text).content;
}

// Return the named sections, each with its heading and its sub-sections.
function extractSections(lines, names, rel, skip = []) {
  const hs = headings(lines);
  const chunks = [];
  for (const name of names) {
    const h = hs.find((x) => x.text === name);
    if (!h) fail(`Heading "${name}" is not in ${rel} at ${SOURCE.tag}. Update content-map.mjs.`);
    const next = hs.find((x) => x.line > h.line && x.level <= h.level);
    let chunk = lines.slice(h.line, next ? next.line : lines.length);
    for (const s of skip) chunk = removeSection(chunk, s);
    chunks.push(normaliseLevels(chunk));
  }
  return chunks.flat();
}

function removeSection(lines, name) {
  const hs = headings(lines);
  const h = hs.find((x) => x.text === name);
  if (!h) return lines;
  const next = hs.find((x) => x.line > h.line && x.level <= h.level);
  return [...lines.slice(0, h.line), ...lines.slice(next ? next.line : lines.length)];
}

// Shift headings so that the top heading of the chunk is an h2.
function normaliseLevels(lines) {
  const hs = headings(lines);
  if (!hs.length) return lines;
  const min = Math.min(...hs.map((h) => h.level));
  const delta = 2 - min;
  if (!delta) return lines;
  const at = new Map(hs.map((h) => [h.line, h]));
  return lines.map((line, i) => {
    const h = at.get(i);
    if (!h) return line;
    const level = Math.max(2, Math.min(6, h.level + delta));
    return `${'#'.repeat(level)} ${h.text}`;
  });
}

function wholeFile(text) {
  let lines = stripFrontMatter(text).split('\n');
  const hs = headings(lines);
  const first = hs[0];
  if (first && first.level === 1) {
    lines = [...lines.slice(0, first.line), ...lines.slice(first.line + 1)];
  }
  return normaliseLevels(lines);
}

function firstH1(text) {
  const h = headings(stripFrontMatter(text).split('\n')).find((x) => x.level === 1);
  return h ? h.text : null;
}

function firstSentence(lines) {
  const mask = fenceMask(lines);
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i].trim();
    if (mask[i] || !l || l.startsWith('#') || l.startsWith('|') || l.startsWith('>') || l.startsWith('<') || l.startsWith('-') || l.startsWith('*') || /^\d+\./.test(l)) continue;
    const plain = l.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[*_`]/g, '');
    const m = plain.match(/^(.{20,220}?[.!?])(\s|$)/);
    return (m ? m[1] : plain).slice(0, 220);
  }
  return '';
}

// ---------------------------------------------------------------- callouts

const CALLOUT_TITLES = { note: 'Note', required: 'Required', advisory: 'Advisory', coming: 'Coming' };

function callout(type, body) {
  const title = CALLOUT_TITLES[type];
  return [
    `<div class="callout callout--${type}" role="note" aria-label="${title}">`,
    `<p class="callout__title">${title}</p>`,
    '',
    body.trim(),
    '',
    '</div>',
  ].join('\n');
}

// GitHub alert blockquotes become typed callouts.
const ALERT_TYPES = { NOTE: 'note', TIP: 'note', IMPORTANT: 'required', WARNING: 'advisory', CAUTION: 'advisory' };

function convertAlerts(lines) {
  const mask = fenceMask(lines);
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const m = !mask[i] && lines[i].match(/^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/);
    if (!m) {
      out.push(lines[i]);
      continue;
    }
    const body = [];
    let j = i + 1;
    while (j < lines.length && lines[j].startsWith('>')) {
      body.push(lines[j].replace(/^>\s?/, ''));
      j++;
    }
    out.push(...callout(ALERT_TYPES[m[1]], body.join('\n')).split('\n'));
    i = j - 1;
  }
  return out;
}

function fillTag(text) {
  return text.replaceAll('{tag}', SOURCE.tag);
}

// ---------------------------------------------------------------- deny terms

function loadPrivateTerms() {
  const file = process.env.DOCS_PRIVATE_TERMS;
  if (!file) return [];
  if (!fs.existsSync(file)) fail(`DOCS_PRIVATE_TERMS points at ${file}, which does not exist.`);
  return fs
    .readFileSync(file, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
}

const DENY = new RegExp(DENY_TERMS.join('|'), 'i');
const PRIVATE_TERMS = loadPrivateTerms();
// A term matches only as a whole name: me2resh/x must not match me2resh/x-y.
const PRIVATE = PRIVATE_TERMS.length ? new RegExp(`(?<![\\w./-])(?:${PRIVATE_TERMS.join('|')})(?![\\w-])`, 'i') : null;

function denyReason(text, slug) {
  if (PRIVATE && PRIVATE.test(text)) return 'Names a private repository or component (private term list).';
  const m = text.match(DENY);
  if (m && !DENY_ALLOW[slug]) return `Names a paid component or a price ("${m[0].toLowerCase()}").`;
  return null;
}

// ---------------------------------------------------------------- page build

const exclusions = { prefixes: EXCLUDED_PREFIXES, pages: [], changelogItems: 0 };

function editUrl(rel) {
  return `${SOURCE.url}/edit/${SOURCE.editBranch}/${rel}`;
}

function heredoc(text, fn) {
  const lines = text.split('\n');
  const start = lines.findIndex((l) => l.startsWith(`${fn}()`));
  if (start < 0) fail(`Function ${fn} is not in the CLI source.`);
  const open = lines.findIndex((l, i) => i > start && /<<'?EOF'?/.test(l));
  const close = lines.findIndex((l, i) => i > open && l.trim() === 'EOF');
  return lines.slice(open + 1, close).join('\n');
}

function buildPart(part) {
  // Site-authored text: a short lead or a link list. It has no source file.
  if (part.text !== undefined) {
    return { source: null, lines: fillTag(part.text).split('\n') };
  }
  // A table of skills, built from each SKILL.md front matter at the tag.
  if (part.skillList) {
    const rows = part.skillList.map((name) => {
      const rel = `.claude/skills/${name}/SKILL.md`;
      const fm = matter(readSource(rel)).data;
      const desc = String(fm.description || '').replace(/\|/g, '\\|').replace(/\s+/g, ' ').trim();
      return { rel, row: `| [\`/${fm.name || name}\`](${BASE}/reference/skills/${name}) | ${desc} |` };
    });
    const lines = [];
    if (part.heading) lines.push(`## ${part.heading}`, '');
    lines.push('| Skill | What it does |', '| --- | --- |', ...rows.map((r) => r.row));
    return { source: rows[0].rel, sources: rows.map((r) => r.rel), lines };
  }
  const text = readSource(part.source);
  let lines;
  if (part.code) {
    lines = [`## ${part.heading}`, '', `Source file: \`${part.source}\``, '', '```' + part.code, text.trimEnd(), '```'];
  } else if (part.heredoc) {
    lines = [`## ${part.heading}`, '', '```text', heredoc(text, part.heredoc), '```'];
  } else if (part.sections) {
    lines = extractSections(stripFrontMatter(text).split('\n'), part.sections, part.source, part.skip);
  } else {
    lines = wholeFile(text);
  }
  return { source: part.source, lines };
}

function mapPage(page) {
  const out = { ...page };
  if (page.coming) {
    const body = [callout('coming', fillTag(page.coming.text))];
    if (page.figure) {
      body.push(
        '',
        `<figure class="shot"><img src="${BASE}/${page.figure.src}" alt="${page.figure.alt}" width="${page.figure.width}" height="${page.figure.height}" loading="lazy" decoding="async"><figcaption>${page.figure.alt}.</figcaption></figure>`,
      );
    }
    out.body = body.join('\n');
    out.sources = [];
    return out;
  }
  const parts = page.parts.map(buildPart);
  const lines = [];
  for (const c of page.callouts || []) lines.push(callout(c.type, fillTag(c.text)), '');
  for (const p of parts) lines.push(...p.lines, '');
  out.sources = [...new Set(parts.flatMap((p) => p.sources || (p.source ? [p.source] : [])))];
  out.body = convertAlerts(lines).join('\n');
  return out;
}

function generateSkills() {
  const dir = path.join(CACHE, '.claude', 'skills');
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(dir, d.name, 'SKILL.md')))
    .map((d) => d.name)
    .sort()
    .map((name) => {
      const rel = `.claude/skills/${name}/SKILL.md`;
      const raw = readSource(rel);
      const fm = matter(raw).data || {};
      return {
        slug: `reference/skills/${name}`,
        title: `/${fm.name || name}`,
        description: String(fm.description || firstSentence(wholeFile(raw))).replace(/\s+/g, ' ').trim(),
        sources: [rel],
        body: convertAlerts(wholeFile(raw)).join('\n'),
      };
    });
}

function generateRules() {
  const dir = path.join(CACHE, '.claude', 'rules');
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.md'))
    .sort()
    .map((f) => {
      const rel = `.claude/rules/${f}`;
      const raw = readSource(rel);
      const body = wholeFile(raw);
      return {
        slug: `reference/rules/${f.replace(/\.md$/, '')}`,
        title: firstH1(raw) || f.replace(/\.md$/, ''),
        description: firstSentence(body),
        sources: [rel],
        body: convertAlerts(body).join('\n'),
      };
    });
}

function generateRoles() {
  const root = path.join(CACHE, 'roles');
  const pages = [];
  for (const dept of fs.readdirSync(root).sort()) {
    const d = path.join(root, dept);
    if (!fs.statSync(d).isDirectory()) continue;
    for (const f of fs.readdirSync(d).filter((x) => x.endsWith('.md')).sort()) {
      const rel = `roles/${dept}/${f}`;
      const raw = readSource(rel);
      const persona = (raw.match(/\*\*Persona name\*\*:\s*([^\n]+)/) || [])[1];
      const title = (firstH1(raw) || f).replace(/^Role:\s*/, '');
      const deptName = dept[0].toUpperCase() + dept.slice(1);
      pages.push({
        slug: `reference/roles/${dept}-${f.replace(/\.md$/, '')}`,
        title,
        description: persona ? `${deptName} role. Persona name: ${persona.trim()}.` : `${deptName} role.`,
        sources: [rel],
        body: convertAlerts(wholeFile(raw)).join('\n'),
      });
    }
  }
  return pages;
}

function hookIndex(page) {
  const dir = path.join(CACHE, '.claude', 'hooks');
  const rows = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.sh') && !f.startsWith('_'))
    .sort()
    .map((f) => {
      const lines = fs.readFileSync(path.join(dir, f), 'utf8').split('\n');
      let purpose = '';
      for (const l of lines.slice(1, 40)) {
        if (!l.startsWith('#')) {
          if (purpose) break;
          continue;
        }
        const t = l.replace(/^#+\s?/, '').trim();
        if (!t || /^[-=#*]+$/.test(t) || /^shellcheck/.test(t)) continue;
        purpose = t.replace(new RegExp(`^${f.replace('.', '\\.')}\\s*[—:-]+\\s*`), '');
        break;
      }
      return `| [\`${f}\`](${SOURCE.url}/blob/${SOURCE.tag}/.claude/hooks/${f}) | ${purpose.replace(/\|/g, '\\|') || 'No header comment.'} |`;
    });
  return {
    ...page,
    sources: ['.claude/hooks/'],
    body: [`The pinned release has ${rows.length} hook scripts. Shared libraries (names that start with \`_\`) are not listed.`, '', '| Hook | Header |', '| --- | --- |', ...rows, ''].join('\n'),
  };
}

function generateChangelog(group) {
  const rel = 'CHANGELOG.md';
  const lines = readSource(rel).split('\n');
  const hs = headings(lines).filter((h) => h.level === 2 && h.text.startsWith('['));
  return hs.slice(0, group.releases).map((h, i) => {
    const next = hs[i + 1];
    let chunk = lines.slice(h.line + 1, next ? next.line : lines.length);
    const kept = chunk.filter((l) => {
      if (/^\s*[-*]\s/.test(l) && (DENY.test(l) || (PRIVATE && PRIVATE.test(l)))) {
        exclusions.changelogItems++;
        return false;
      }
      return true;
    });
    const version = h.text.match(/\[([^\]]+)\]/)[1];
    const date = (h.text.match(/(\d{4}-\d{2}-\d{2})/) || [])[1];
    return {
      slug: `reference/changelog/${version.replace(/\./g, '-')}`,
      title: version,
      description: date ? `Changes in ${version}, released ${date}.` : `Changes in ${version}.`,
      sources: [rel],
      body: normaliseLevels(kept).join('\n'),
    };
  });
}

// ---------------------------------------------------------------- links

function buildLinkIndex(pages) {
  const bySource = new Map();
  for (const p of pages) {
    const slugger = new GithubSlugger();
    p.anchors = new Set(headings(p.body.split('\n')).map((h) => slugger.slug(h.text.replace(/`/g, ''))));
    const whole = !p.parts || p.parts.every((x) => x.source && !x.sections && !x.code && !x.heredoc);
    for (const s of p.sources) {
      if (!bySource.has(s)) bySource.set(s, []);
      bySource.get(s).push({ page: p, whole: whole && p.sources.length === 1 });
    }
  }
  return bySource;
}

function githubUrl(rel, hash) {
  const { files, dirs } = treeFiles();
  const kind = dirs.has(rel.replace(/\/$/, '')) && !files.has(rel) ? 'tree' : 'blob';
  return `${SOURCE.url}/${kind}/${SOURCE.tag}/${rel.replace(/\/$/, '')}${hash ? '#' + hash : ''}`;
}

function resolveLink(target, fromSource, page, bySource) {
  if (/^(https?:|mailto:|tel:|data:)/i.test(target) || target.startsWith('//')) return target;
  // Links that site-authored text writes to docs pages are already final.
  if (target === BASE || target.startsWith(`${BASE}/`) || target.startsWith(`${BASE}#`)) return target;
  if (target.startsWith('#')) {
    const hash = target.slice(1);
    if (page.anchors.has(hash)) return target;
    return githubUrl(fromSource, hash);
  }
  const [p, hash] = target.split('#');
  let rel = path.posix.normalize(path.posix.join(path.posix.dirname(fromSource), p));
  if (p.startsWith('/')) rel = p.slice(1);
  if (rel.startsWith('../')) return githubUrl(fromSource);
  const hits = bySource.get(rel) || [];
  if (hash) {
    const hit = hits.find((h) => h.page.anchors.has(hash));
    if (hit) return `${BASE}/${hit.page.slug}#${hash}`;
  } else {
    const hit = hits.find((h) => h.whole) || hits[0];
    if (hit) return `${BASE}/${hit.page.slug}`;
  }
  if (/\.(png|jpe?g|gif|svg|webp)$/i.test(rel)) return `https://raw.githubusercontent.com/${SOURCE.repo}/${SOURCE.tag}/${rel}`;
  return githubUrl(rel, hash);
}

function rewriteLinks(page, bySource) {
  const lines = page.body.split('\n');
  const mask = fenceMask(lines);
  const from = page.sources[0] || 'README.md';
  page.body = lines
    .map((line, i) => {
      if (mask[i]) return line;
      // Leave inline code alone: split on backtick spans.
      return line
        .split(/(`[^`]*`)/)
        .map((seg) =>
          seg.startsWith('`')
            ? seg
            : seg
                .replace(/\]\(\s*<?([^)\s>]+)>?(\s+"[^"]*")?\s*\)/g, (_, t, title = '') => `](${resolveLink(t, from, page, bySource)}${title})`)
                .replace(/(href|src)="([^"]+)"/g, (_, a, t) => `${a}="${resolveLink(t, from, page, bySource)}"`),
        )
        .join('');
    })
    .join('\n');
}

// ---------------------------------------------------------------- write

function yaml(obj) {
  return Object.entries(obj)
    .filter(([, v]) => v !== undefined && v !== null && v !== false)
    .map(([k, v]) => `${k}: ${JSON.stringify(v)}`)
    .join('\n');
}

function writeFile(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

function provenance(p) {
  if (!p.sources.length) return '';
  const list = p.sources.map((s) => `[\`${s}\`](${githubUrl(s)})`).join(', ');
  return `\n\n<p class="provenance">Generated from ${list} at ${SOURCE.tag}.</p>\n`;
}

function main() {
  fetchSource();
  for (const dir of [OUT_CONTENT, OUT_GEN]) fs.rmSync(dir, { recursive: true, force: true });
  fs.rmSync(path.join(OUT_PUBLIC, 'reference'), { recursive: true, force: true });
  for (const s of SECTIONS) for (const g of s.groups) fs.rmSync(path.join(OUT_PUBLIC, g.id), { recursive: true, force: true });

  const all = [];
  const nav = { source: SOURCE, sections: [] };
  for (const section of SECTIONS) {
    const navSection = { id: section.id, title: section.title, summary: section.summary, groups: [] };
    for (const group of section.groups) {
      let pages;
      if (group.generate === 'skills') pages = generateSkills();
      else if (group.generate === 'rules') pages = generateRules();
      else if (group.generate === 'roles') pages = generateRoles();
      else if (group.generate === 'changelog') pages = generateChangelog(group);
      else pages = group.pages.map((p) => (p.generate === 'hook-index' ? hookIndex(p) : mapPage(p)));

      const kept = [];
      for (const p of pages) {
        const reason = denyReason(`${p.title}\n${p.description}\n${p.body}`, p.slug);
        if (reason) {
          exclusions.pages.push({ slug: p.slug, title: p.title, sources: p.sources, reason });
          continue;
        }
        p.section = section;
        p.group = group;
        kept.push(p);
      }
      all.push(...kept);
      navSection.groups.push({
        id: group.id,
        title: group.title,
        icon: group.icon,
        summary: group.summary,
        collapsed: !!group.collapsed,
        pages: kept.map((p) => ({ slug: p.slug, title: p.title, description: p.description, coming: !!p.coming, sources: p.sources })),
      });
    }
    navSection.count = navSection.groups.reduce((n, g) => n + g.pages.length, 0);
    nav.sections.push(navSection);
  }
  nav.total = nav.sections.reduce((n, s) => n + s.count, 0);

  const bySource = buildLinkIndex(all);
  for (const p of all) rewriteLinks(p, bySource);

  const llms = [`# ApexYard docs`, '', `> Generated from ${SOURCE.repo} at ${SOURCE.tag}. Each page has a Markdown copy at the same path with a .md suffix.`, ''];
  for (const s of nav.sections) {
    llms.push(`## ${s.title}`, '');
    for (const g of s.groups) {
      for (const pg of g.pages) llms.push(`- [${g.title}: ${pg.title}](https://apexyard.ai${BASE}/${pg.slug}.md): ${pg.description}`);
    }
    llms.push('');
  }

  for (const p of all) {
    const fm = {
      title: p.title,
      description: p.description,
      editUrl: p.sources[0] && !p.sources[0].endsWith('/') ? editUrl(p.sources[0]) : false,
      sidebar: undefined,
    };
    const body = p.body.replace(/<!--[\s\S]*?-->/g, '').replace(/\n{3,}/g, '\n\n').trim();
    const head = `---\n${yaml({ title: fm.title, description: fm.description, editUrl: fm.editUrl })}\n---\n\n`;
    writeFile(path.join(OUT_CONTENT, `${p.slug}.md`), head + body + provenance(p));
    writeFile(path.join(OUT_PUBLIC, `${p.slug}.md`), `# ${p.title}\n\n> ${p.description}\n\n${body}\n\n---\nSource: ${p.sources.join(', ') || 'none yet'} at ${SOURCE.repo}@${SOURCE.tag}\n`);
  }
  writeFile(path.join(OUT_PUBLIC, 'llms.txt'), llms.join('\n'));
  // The site favicon lives at the site root. Starlight links it under /docs.
  fs.copyFileSync(path.join(ROOT, '..', 'favicon.svg'), path.join(OUT_PUBLIC, 'favicon.svg'));
  writeFile(path.join(OUT_GEN, 'nav.json'), JSON.stringify(nav, null, 2));
  writeFile(path.join(OUT_GEN, 'exclusions.json'), JSON.stringify(exclusions, null, 2));

  const counts = nav.sections.map((s) => `${s.title} ${s.count} (${s.groups.map((g) => `${g.title} ${g.pages.length}`).join(', ')})`);
  console.log(`sync-content: ${nav.total} pages from ${SOURCE.repo}@${SOURCE.tag}`);
  counts.forEach((c) => console.log(`  ${c}`));
  console.log(`  excluded pages: ${exclusions.pages.length}, changelog items removed: ${exclusions.changelogItems}`);
  // Log only the count and the path of the private list, never its terms.
  console.log(PRIVATE_TERMS.length ? `  private term list: ${PRIVATE_TERMS.length} terms from ${process.env.DOCS_PRIVATE_TERMS}` : '  private term list: not set (generic terms only)');
}

main();
