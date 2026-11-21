#!/usr/bin/env bash
# #202: the /docs build honours SITE_FEATURES. With a paid feature off, its
# sidebar group, its count, its pages, its search entries and every link to
# it must be gone. Builds the docs twice, so it needs docs-site/node_modules
# and network access to the framework tag. It skips when node_modules is absent;
# the docs-check workflow installs them first.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ ! -d "$root/docs-site/node_modules" ]; then
  echo 'SKIP docs feature test: run npm ci in docs-site first'
  exit 0
fi

check() {
  python3 -I - "$root/docs-site" "$1" <<'PY'
import json, re, sys
from pathlib import Path
site = Path(sys.argv[1]); enabled = set(filter(None, sys.argv[2].split(',')))
dist = site / 'dist'
# feature -> docs group id and the site path of the same area
areas = {'cockpit': 'cockpit', 'gate': 'hosted-gate', 'readiness': 'readiness'}
off = {f: g for f, g in areas.items() if f not in enabled}
nav = json.loads((site / 'src/generated/nav.json').read_text())
group_ids = {g['id'] for s in nav['sections'] for g in s['groups']}
home = (dist / 'index.html').read_text()
pages = list(dist.rglob('*.html')) + list(dist.rglob('*.md')) + [dist / 'llms.txt']
for feature, group in areas.items():
    present = feature in enabled and (feature != 'gate' or 'upcoming' in enabled)  # every hosted gate page is Coming
    assert (group in group_ids) == present, (feature, 'nav group')
    assert (dist / group).is_dir() == present, (feature, 'built pages')
    assert (len(re.findall(r'href="/docs/' + group + '/', home)) > 0) == present, (feature, 'sidebar links')
    assert (('/docs/' + group + '/') in (dist / 'llms.txt').read_text()) == present, (feature, 'llms.txt')
    for page in pages:
        text = page.read_text()
        if not present:
            assert '/docs/' + group + '/' not in text, (feature, page.name, 'link to a removed docs page')
            assert not re.search(r'(?:href="|\]\()(?:https://(?:staging\.)?apexyard\.ai)?/' + feature + r'(?:\.html|\.md)?["#?)]', text), (feature, page.name, 'link to a removed site page')
# Pages marked Coming sit behind `upcoming`. The GitHub App guide sits behind `gate`.
singles = {'upcoming': ['your-rules/knowledge-base', 'updating/drift-safe-updates'], 'gate': ['how-to/reviewer-github-app']}
slugs = {pg['slug'] for sec in nav['sections'] for g in sec['groups'] for pg in g['pages']}
for feature, items in singles.items():
    for slug in items:
        present = feature in enabled
        assert (slug in slugs) == present, (slug, 'nav page')
        assert (dist / (slug + '.html')).exists() == present, (slug, 'built page')
        assert (dist / (slug + '.md')).exists() == present, (slug, 'markdown copy')
        assert ('/docs/' + slug + '"' in home) == present, (slug, 'home card link')
        if not present:
            for page in pages:
                assert not re.search('/docs/' + slug + r'["#?) ]', page.read_text()), (slug, page.name, 'link to a removed page')
assert ('how-to' in group_ids) == ('gate' in enabled), 'how-to group'
# No page marked Coming stays without the upcoming flag.
if 'upcoming' not in enabled:
    for sec in nav['sections']:
        for g in sec['groups']:
            for pg in g['pages']:
                assert not pg['coming'], (pg['slug'], 'Coming page without the upcoming flag')
else:
    assert any(pg['coming'] for sec in nav['sections'] for g in sec['groups'] for pg in g['pages']) or 'gate' not in enabled, 'Coming gate pages missing with upcoming'
# The group counts on the docs home match nav.json.
for sec in nav['sections']:
    for g in sec['groups']:
        n = len(g['pages'])
        assert re.search(re.escape(g['title']) + r'.{0,2000}?' + str(n) + ' page' + ('' if n == 1 else 's'), home, re.S), (g['id'], 'count on home')
# The header link: /#product needs Gate, /build otherwise.
want = '/#product' if 'gate' in enabled else '/build'
assert ('href="' + want + '">Product<') in home, ('header link', want)
# The sidebar group labels and the group counts.
labels = {'cockpit': 'Cockpit (Preview)', 'gate': 'The hosted gate', 'readiness': 'Readiness'}
for feature, label in labels.items():
    assert ((label in home) == (feature in enabled and (feature != 'gate' or 'upcoming' in enabled))), (feature, label, 'sidebar label')
# The search index only lists built pages: Pagefind reads the same HTML.
assert (dist / 'pagefind/pagefind.js').exists()
print('PASS docs features: ' + (sys.argv[2] or 'none'))
PY
}

for flags in 'build' 'build,gate' 'build,upcoming' 'build,gate,upcoming' 'build,gate,readiness,pricing,cockpit,upcoming'; do
  (cd "$root/docs-site" && SITE_FEATURES="$flags" npm run build >/dev/null)
  check "$flags"
  # Pagefind stores the indexed text in compressed fragments, so assert on
  # the pages it was given: it indexes every built article exactly once.
  python3 -I - "$root/docs-site" <<'PY'
import json, sys
from pathlib import Path
site = Path(sys.argv[1]); dist = site / 'dist'
nav = json.loads((site / 'src/generated/nav.json').read_text())
articles = {p.relative_to(dist).as_posix().removesuffix('.html') for p in dist.rglob('*.html') if p.name != 'index.html' and '_astro' not in p.parts}
listed = {pg['slug'] for s in nav['sections'] for g in s['groups'] for pg in g['pages']}
assert articles == listed, (sorted(articles ^ listed))
meta = sorted((dist / 'pagefind').glob('pagefind-entry.json'))
assert meta, 'search index missing'
entry = json.loads(meta[0].read_text())
total = sum(l['page_count'] for l in entry['languages'].values())
assert total == len(articles), ('search index page count', total, len(articles))
print('PASS docs search index matches built pages')
PY
done
