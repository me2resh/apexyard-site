#!/usr/bin/env bash
# #204: with only the free flag on (SITE_FEATURES=build, the production value),
# the public site presents the open-source framework alone. With every flag on,
# the paid copy and the Build page return. Offline.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$root/.github/scripts/apply-features.sh" "$root" "$tmp/free" build >/dev/null
"$root/.github/scripts/apply-features.sh" "$root" "$tmp/all" build,buildpage,gate,readiness,pricing,cockpit,upcoming >/dev/null
python3 -I - "$tmp/free" "$tmp/all" "$root" <<'PY'
import html, re, sys
from pathlib import Path
free, full, src = (Path(a) for a in sys.argv[1:4])
def visible(path):
    text = re.sub(r'<(script|style)\b.*?</\1>', '', path.read_text(), flags=re.S)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', text)))
home, home_all = (free / 'index.html').read_text(), (full / 'index.html').read_text()
text, text_all = visible(free / 'index.html'), visible(full / 'index.html')
def check(name, ok):
    print(('  ok    ' if ok else '  FAIL  ') + name)
    if not ok: check.bad += 1
check.bad = 0
# Naming
check('main button says Install ApexYard', 'Install ApexYard' in text and 'Install Build' not in text)
check('home page never says Build as a product (free flag)', not re.search(r'\bBuild\b', text))
check('home page never says Build as a product (all flags: install heading)', 'Install Build' not in text_all)
check('Free to use replaces Always free', 'Open source. MIT. Free to use.' in text and 'Always free' not in text)
# Build page behind its own flag
check('Build page is not published with the free flag', not (free / 'build.html').exists())
check('Build page is published with the buildpage flag', (full / 'build.html').exists())
links = [p.name for p in free.rglob('*') if p.is_file() and p.suffix in {'.html', '.txt', '.md', '.xml', '.gen'} and re.search(r'(?:href="|\]\(|https://apexyard\.ai)/build(?![a-z0-9-])', p.read_text())]
check('no page links to /build with the free flag: ' + ','.join(links), not links)
check('nav and footer link to /build with every flag', 'href="/build"' in home_all)
# Stats
check('the building-itself row is gone (free)', not re.search(r'building itself|Counted on|\b699\b|\b289\b|\b334\b', text))
check('the building-itself row is gone (all flags)', not re.search(r'building itself|Counted on|\b699\b|\b289\b|\b334\b', text_all))
check('roles, skills, agents and hooks stay', all(re.search(r'\b' + n + r'\b', text) for n in ('roles', 'skills', 'agents', 'hooks')))
check('stars and forks badges share one row', len(re.findall(r'<div class="proof__repo">(?:(?!</div>).)*stars(?:(?!</div>).)*forks', home, re.S)) == 1)
css = (src / 'product.css').read_text()
check('the badge row has a gap', re.search(r'\.proof__repo \{[^}]*gap:', css) is not None)
check('three empty customer slots marked Preview', home.count('class="quote-slot"') >= 3 and home.count('mock__tag">Preview') >= 3 and 'blockquote' not in home)
check('the slots are public, not staging-only', 'data-staging-only' not in home)
# Hero
check('the free-checks hint is hidden (free)', 'class="hero__hint"' not in home)
check('the hosted parts are paid line is hidden (free)', 'The hosted parts are paid' not in text)
# Keel
keel = [p.name for p in free.rglob('*') if p.is_file() and p.suffix in {'.html', '.txt', '.md', '.gen'} and p.name != 'previews.html' and p.relative_to(free).parts[0] not in ('docs', 'apexdock') and re.search(r'\bKeel\b', visible(p) if p.suffix == '.html' else p.read_text())]
check('no visible Keel with the free flag: ' + ','.join(keel), not keel)
check('Keel returns with every flag', re.search(r'\bKeel\b', text_all) is not None)
# Moving line marker
js = (src / 'site.js').read_text()
read = js[js.index('function readTarget'):js.index('function paint')]
check('the marker rides at one third of the viewport', 'ANCHOR = 1 / 3' in js and 'vh * .6' not in read)
sys_exit = 1 if check.bad else 0
print('framework-only: %d problem(s)' % check.bad)
sys.exit(sys_exit)
PY
