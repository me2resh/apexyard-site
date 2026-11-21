#!/usr/bin/env bash
# Deploy-time feature matrix and nested-parser regression guards. Offline.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for flags in 'build,gate,readiness,pricing,cockpit' '' build; do
  out="$tmp/out-${flags:-none}"
  "$root/.github/scripts/apply-features.sh" "$root" "$out" "$flags"
  python3 -I - "$out" "$flags" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit
import re, sys
root=Path(sys.argv[1]); enabled=set(sys.argv[2].split(',')); features=set('build gate readiness pricing cockpit'.split())
removed=features-enabled
for f in features:
    assert (root/(f+'.html')).exists() == (f in enabled), f
class Scan(HTMLParser):
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'data-feature' in a:
            assert set(a['data-feature'].split())&enabled, (page,a)
        for key in ('href','action','data-waitlist'):
            url=urlsplit(a.get(key,''))
            if url.netloc and url.netloc not in ('apexyard.ai','staging.apexyard.ai'): continue
            target=url.path.strip('/').removesuffix('.html').removesuffix('.md')
            assert target not in removed, (page,target)
            assert target!='waitlist' or 'gate' in enabled, page
for page in root.rglob('*.html'):
    if any(p.startswith('.') for p in page.relative_to(root).parts) or 'docs-site' in page.parts or 'og' in page.parts or 'docs' in page.parts: continue
    Scan().feed(page.read_text())
for page in [root/'llms.txt',root/'llms-full.txt',root/'sitemap.xml',*root.glob('*.md.gen')]:
    text=page.read_text()
    for f in removed:
        assert not re.search(r'https://apexyard.ai/'+f+r'(?:[\s/#<)]|$)',text), (page,f)
print('PASS feature output: '+(sys.argv[2] or 'all off'))
PY
done
mkdir "$tmp/fixture"
printf '%s' '<body><div data-feature="gate"><div>nested</div>secret</div><p data-feature="build pricing">keep</p><img data-feature="gate" src="secret"><p>end</p></body>' > "$tmp/fixture/index.html"
"$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/nested" build
if grep -q secret "$tmp/nested/index.html"; then exit 1; fi
grep -q keep "$tmp/nested/index.html"
grep -q end "$tmp/nested/index.html"
if "$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/unknown" typo >"$tmp/error" 2>&1; then
  echo 'FAIL unknown feature accepted'; exit 1
fi
grep -q 'unknown feature name: typo' "$tmp/error"
echo 'PASS nested, ANY, void elements and unknown name guards'

# Overlay values for removed tokens are valid only against the source tree.
printf '%s' '<body><p data-feature="gate"><!--{{TEAM_PRICE}}-->Price on request<!--/{{TEAM_PRICE}}--></p></body>' > "$tmp/fixture/index.html"
"$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/overlay-filtered" build
FEATURE_SOURCE="$tmp/fixture" OVERLAY_JSON='{"TEAM_PRICE":"fixture"}' \
  "$root/.github/scripts/apply-overlay.sh" "$tmp/overlay-filtered" "$tmp/overlaid"
if FEATURE_SOURCE="$tmp/fixture" OVERLAY_JSON='{"TYPO":"fixture"}' \
  "$root/.github/scripts/apply-overlay.sh" "$tmp/overlay-filtered" "$tmp/typo-overlay" >"$tmp/error" 2>&1; then
  echo 'FAIL unknown overlay key accepted'; exit 1
fi
echo 'PASS overlay after filtering keeps unknown-key validation'

printf '%s' 'start<!-- feature:gate -->secret<!-- feature:build -->nested<!-- /feature:build --><!-- /feature:gate --><!-- feature:build pricing -->keep<!-- /feature:build pricing -->end' > "$tmp/fixture/llms.txt"
"$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/regions" build
[ "$(cat "$tmp/regions/llms.txt")" = startkeepend ]
"$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/missing"
[ "$(cat "$tmp/missing/llms.txt")" = startend ]
echo 'PASS nested text regions and missing list'
