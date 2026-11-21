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
# Regression: Markdown, autolinks and href delimiters all end the product path.
def link_pattern(feature):
    return r'(?:https://(?:staging\.)?apexyard\.ai)?/'+feature+r'(?:\.html|\.md)?(?![a-z0-9-])'
for end in ('>', ')', '"', "'", '#details', '?source=test'):
    assert re.search(link_pattern('pricing'), 'https://apexyard.ai/pricing'+end)
assert not re.search(link_pattern('gate'), '/gatekeeper')
if 'gate' not in enabled:
    assert not (root/'img/check-pr9.webp').exists()
if not {'gate','readiness'} <= enabled:
    assert not (root/'og/architecture.png').exists()
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
# Every non-hidden text asset in the deploy tree, including Markdown alternates.
for page in root.rglob('*'):
    if not page.is_file() or any(p.startswith('.') for p in page.relative_to(root).parts): continue
    # Internal docs source is excluded by site sync; built docs are tested below.
    if page.relative_to(root).parts[0] == 'docs': continue
    if page.suffix not in {'.html','.md','.txt','.xml','.json'} and not page.name.endswith('.md.gen'): continue
    text=page.read_text()
    for f in removed:
        assert not re.search(link_pattern(f),text,re.I), (page,f,'disabled link')
    if sys.argv[2]=='build':
        # No generic-word exceptions: all disabled product names are forbidden.
        assert not re.search(r'\b(?:gate|readiness|pricing|cockpit)\b',text,re.I), (page,'disabled product name')
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

# Authoring typos must fail closed, including malformed region values.
for markup in '<div data-feature>secret</div>' '<div data-feature="">secret</div>' '<div data-feature="gate"/>secret' '<!-- feature:Gate -->secret<!-- /feature:Gate -->'; do
  printf '%s' "$markup" > "$tmp/fixture/index.html"
  rm -rf "$tmp/malformed"
  if "$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/malformed" build >"$tmp/error" 2>&1; then
    echo "FAIL malformed feature markup accepted: $markup"; exit 1
  fi
done
echo 'PASS bare/empty attributes, self-closing HTML and malformed region guards'

# Both no-environment jobs rehearse/use the repository live list.
python3 -I - "$root/.github/workflows/deploy-aws.yml" <<'PYCODE'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text()
assert text.count('SITE_FEATURES: ${{ vars.SITE_FEATURES_PRODUCTION }}') == 2
assert 'SITE_FEATURES: ${{ vars.SITE_FEATURES }}' not in text
print('PASS main staging and production read the live feature list')
PYCODE

# The same shared filter runs on the built docs sub-tree before its sync.
mkdir -p "$tmp/docs-fixture/docs/pagefind"
printf '%s' '<body>Docs</body>' > "$tmp/docs-fixture/docs.html"
printf '%s' 'search index' > "$tmp/docs-fixture/docs/pagefind/pagefind.js"
printf '%s' '<body><p data-feature="gate">Hosted check</p><p>Docs</p></body>' > "$tmp/docs-fixture/docs/guide.html"
for flags in build,gate,readiness,pricing,cockpit build; do
  out="$tmp/docs-$flags"
  "$root/.github/scripts/apply-features.sh" "$tmp/docs-fixture" "$out" "$flags"
  cmp "$tmp/docs-fixture/docs/pagefind/pagefind.js" "$out/docs/pagefind/pagefind.js"
  test -f "$out/docs/guide.html"
  if [ "$flags" = build ]; then
    if grep -q 'Hosted check' "$out/docs/guide.html"; then
      echo 'FAIL disabled docs content survived'; exit 1
    fi
  fi
  echo "PASS docs assets survive: $flags"
done

# ALL and its inverse must partition every partial state, with nesting intact.
printf '%s' '<!-- feature-all:gate readiness -->original<!-- /feature-all:gate readiness --><!-- feature-off:gate readiness --><!-- feature:build -->Build alternative<!-- /feature:build --><!-- /feature-off:gate readiness -->' > "$tmp/fixture/llms.txt"
printf '%s' '<body>fixture</body>' > "$tmp/fixture/index.html"
for flags in build build,gate build,readiness build,gate,readiness; do
  "$root/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/alternative-$flags" "$flags"
  if [ "$flags" = build,gate,readiness ]; then expected=original; else expected='Build alternative'; fi
  [ "$(cat "$tmp/alternative-$flags/llms.txt")" = "$expected" ]
done
echo 'PASS ALL and feature-off alternatives across partial states'
