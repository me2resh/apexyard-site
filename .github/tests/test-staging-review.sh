#!/usr/bin/env bash
#
# #137. Staging review guards: copy, Keel, stats, previews, architecture
# redirect, overlay-free pricing tokens, and docs changelog size.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
prod="$root/.github/workflows/deploy-aws.yml"
staging="$root/.github/workflows/deploy-staging-v2.yml"
redirects="$root/_redirects"
script="$root/.github/scripts/write-github-stats.sh"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

holds() { printf '%s' "$1" | grep -Fq -- "$2"; }
lacks() { ! printf '%s' "$1" | grep -Fq -- "$2"; }
file_lacks() { ! grep -Fq -- "$2" "$1"; }

# Public file set for banned-phrase scans (items 1 and 2).
public_files() {
  local f
  for f in "$root"/*.html "$root"/*.md.gen "$root"/*.txt; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  for f in skill.md creator-brief.md docs-site/content-map.mjs; do
    [ -f "$root/$f" ] && printf '%s\n' "$root/$f"
  done
}

none_hold() { # <needle>
  local needle="$1" f hits=""
  while IFS= read -r f; do
    if grep -Fq -- "$needle" "$f"; then
      hits="$hits ${f#"$root"/}"
    fi
  done < <(public_files)
  [ -z "$hits" ] || { echo "    found in:$hits"; return 1; }
}

assert "no public file holds Every change starts from a ticket" \
  none_hold 'Every change starts from a ticket'
assert "no public file holds brew install jq" \
  none_hold 'brew install jq'

# --- 3. Install block ---
qs=$(awk '/id="quickstart"/,/<\/section>/' "$root/index.html")
assert "quickstart holds works-with list" \
  holds "$qs" 'Claude Code, Codex, Cursor, OpenCode, Pi and omp'
assert "quickstart holds brew install me2resh/tap/apexyard" \
  holds "$qs" 'brew install me2resh/tap/apexyard'
assert "quickstart holds npx create-apexyard command" \
  holds "$qs" 'npx create-apexyard --org &lt;your-org&gt; --name ops --private'
assert "quickstart holds You need git." \
  holds "$qs" 'You need git.'
assert "quickstart holds no git clone" lacks "$qs" 'git clone'
assert "quickstart holds no Fork " lacks "$qs" 'Fork '

assert "index.md.gen holds works-with list" \
  grep -Fq 'Claude Code, Codex, Cursor, OpenCode, Pi and omp' "$root/index.md.gen"
assert "index.md.gen holds brew install me2resh/tap/apexyard" \
  grep -Fq 'brew install me2resh/tap/apexyard' "$root/index.md.gen"
assert "index.md.gen holds npx create-apexyard command" \
  grep -Fq 'npx create-apexyard --org <your-org> --name ops --private' "$root/index.md.gen"
assert "index.md.gen holds no git clone" file_lacks "$root/index.md.gen" 'git clone'

assert "content-map holds brew install me2resh/tap/apexyard" \
  grep -Fq 'brew install me2resh/tap/apexyard' "$root/docs-site/content-map.mjs"
assert "content-map holds npx create-apexyard command" \
  grep -Fq 'npx create-apexyard --org <your-org> --name ops --private' "$root/docs-site/content-map.mjs"

# --- 4. Keel component ---
keel_pages=(index.html build.html gate.html readiness.html creators.html)
keel_sentences=(
  'Every API endpoint checks who is calling.'
  'A rule your team adds to the knowledge base, marked blocking.'
  'Before an agent writes code, it loads your rules. It writes each new endpoint with an auth check.'
  'Rex, the review agent, checks each pull request against the rule. A blocking rule that fails stops the merge.'
  'When a person finds a miss in review, /codify-rule turns the comment into a draft rule. You approve it before it is saved.'
)
pause_btn='<button type="button" class="keel__pause" aria-pressed="false" hidden>'

for page in "${keel_pages[@]}"; do
  assert "$page holds data-keel" grep -Fq 'data-keel' "$root/$page"
  assert "$page holds keel pause button" grep -Fq "$pause_btn" "$root/$page"
  assert "$page loads /keel-loop.js" grep -Fq '/keel-loop.js' "$root/$page"
  for s in "${keel_sentences[@]}"; do
    assert "$page holds keel sentence: ${s:0:40}..." grep -Fq "$s" "$root/$page"
  done
done

assert "build.html has data-keel-highlight=build" \
  grep -Fq 'data-keel-highlight="build"' "$root/build.html"
assert "gate.html has data-keel-highlight=gate" \
  grep -Fq 'data-keel-highlight="gate"' "$root/gate.html"
assert "readiness.html has data-keel-highlight=readiness" \
  grep -Fq 'data-keel-highlight="readiness"' "$root/readiness.html"

assert "keel-loop.js holds prefers-reduced-motion: reduce" \
  grep -Fq 'prefers-reduced-motion: reduce' "$root/keel-loop.js"
assert "keel-loop.js holds aria-pressed" \
  grep -Fq 'aria-pressed' "$root/keel-loop.js"

keel_css_reduce() {
  python3 - "$root/product.css" <<'PY'
import re, sys
css = open(sys.argv[1], encoding="utf-8").read()
for m in re.finditer(
    r"@media\s*\(prefers-reduced-motion:\s*reduce\)\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}",
    css,
):
    if ".keel" in m.group(0):
        sys.exit(0)
sys.exit(1)
PY
}
assert "product.css reduced-motion block names .keel" keel_css_reduce

no_rule_map_refs() {
  # Exclude this test file: it names the string under test.
  ! grep -rFq --exclude-dir=.git --exclude-dir=node_modules \
    --exclude='test-staging-review.sh' 'rule-map.js' "$root"
}
assert "no file references rule-map.js" no_rule_map_refs
assert "rule-map.js does not exist" test ! -e "$root/rule-map.js"

# --- 5. No sample metrics ---
no_sample() {
  local f="$1" needle
  for needle in '00%' '0.0 h' 'proof__sample' '>Sample<'; do
    if grep -Fq -- "$needle" "$f"; then
      echo "    $needle in ${f#"$root"/}"
      return 1
    fi
  done
}
assert "index.html holds no sample metrics" no_sample "$root/index.html"
assert "index.md.gen holds no sample metrics" no_sample "$root/index.md.gen"
assert "index.html holds data-gh-stats hidden" \
  grep -Fq 'data-gh-stats hidden' "$root/index.html"
assert "index.html holds data-staging-only hidden" \
  grep -Fq 'data-staging-only hidden' "$root/index.html"

# --- 6. Review page ---
assert "previews.html exists" test -f "$root/previews.html"
assert "previews.html holds robots noindex, nofollow" \
  grep -Fq '<meta name="robots" content="noindex, nofollow">' "$root/previews.html"
assert "previews.html has no rel=canonical" \
  file_lacks "$root/previews.html" 'rel="canonical"'

assert "sitemap.xml does not name previews" file_lacks "$root/sitemap.xml" 'previews'
assert "llms.txt does not name previews" file_lacks "$root/llms.txt" 'previews'
assert "llms-full.txt does not name previews" file_lacks "$root/llms-full.txt" 'previews'

no_previews_href() {
  local f hits=""
  for f in "$root"/*.html; do
    [ "$(basename "$f")" = "previews.html" ] && continue
    if grep -Fq 'href="/previews' "$f"; then
      hits="$hits $(basename "$f")"
    fi
  done
  [ -z "$hits" ] || { echo "    found in:$hits"; return 1; }
}
assert "no other root html links /previews" no_previews_href

prod_job() {
  awk '
    $0 == "  deploy-production:" { on = 1; next }
    on && /^  [a-z][a-z0-9_-]*:$/ { exit }
    on
  ' "$prod"
}
prod_excludes() {
  local needle="$1"
  prod_job | grep -vE '^\s*#' | grep -Fq -- "$needle"
}

assert "deploy-production sync excludes previews.html" \
  prod_excludes '--exclude "previews.html"'
assert "deploy-production sync excludes staging-only.js" \
  prod_excludes '--exclude "staging-only.js"'

assert "_redirects 404 /previews" \
  grep -Eq '^/previews[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /previews.html" \
  grep -Eq '^/previews\.html[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /staging-only.js" \
  grep -Eq '^/staging-only\.js[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"

assert "staging deploy has no exclude for previews.html" \
  file_lacks "$staging" '--exclude "previews.html"'
assert "staging deploy has no exclude for staging-only.js" \
  file_lacks "$staging" '--exclude "staging-only.js"'

# --- 7. Architecture redirect ---
arch_refresh() {
  grep -Fq 'http-equiv="refresh"' "$root/architecture.html" \
    && grep -Fq 'url=/docs/quickstart/architecture' "$root/architecture.html"
}
assert "architecture.html holds refresh to docs architecture" arch_refresh
assert "architecture.html holds canonical to docs architecture" \
  grep -Fq '<link rel="canonical" href="https://apexyard.ai/docs/quickstart/architecture">' "$root/architecture.html"
assert "_redirects 301 /architecture to docs" \
  grep -Eq '^/architecture[[:space:]]+/docs/quickstart/architecture[[:space:]]+301$' "$redirects"
assert "sitemap.xml has no /architecture URL" \
  file_lacks "$root/sitemap.xml" 'https://apexyard.ai/architecture<'
assert "content-map has slug quickstart/architecture" \
  grep -Fq "slug: 'quickstart/architecture'" "$root/docs-site/content-map.mjs"

arch_text_clean() {
  python3 - "$root/docs-site/content-map.mjs" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(
    r"slug:\s*'quickstart/architecture',[\s\S]*?text:\s*\[([\s\S]*?)\],",
    text,
)
if not m:
    print("    architecture text block not found")
    sys.exit(1)
body = m.group(1)
bad = [w for w in ("Members", "verified") if w in body]
if bad:
    print("    found: " + ", ".join(bad))
    sys.exit(1)
sys.exit(0)
PY
}
assert "architecture text has no Members or verified" arch_text_clean

# --- 8. write-github-stats.sh ---
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/good.json" <<'EOF'
{"stargazers_count": 1234, "forks_count": 56}
EOF
out="$tmp/out.json"
rm -f "$out"
GITHUB_STATS_INPUT="$tmp/good.json" GITHUB_STATS_DATE=2026-10-27 \
  bash "$script" "$out" >/dev/null 2>"$tmp/good.err"
good_rc=$?
stats_ok() {
  [ "$good_rc" -eq 0 ] && [ -f "$out" ] && python3 -I - "$out" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data == {"stars": 1234, "forks": 56, "asOf": "2026-10-27"}, data
PY
}
assert "write-github-stats writes 1234/56 dated JSON" stats_ok

soft_no_out() { # <rc> <out>
  [ "$1" -eq 0 ] && [ ! -f "$2" ]
}

cat >"$tmp/bad-count.json" <<'EOF'
{"stargazers_count": "x"}
EOF
bad_out="$tmp/bad-out.json"
rm -f "$bad_out"
GITHUB_STATS_INPUT="$tmp/bad-count.json" bash "$script" "$bad_out" >/dev/null 2>"$tmp/bad.err"
bad_rc=$?
assert "write-github-stats soft-fails on bad counts" soft_no_out "$bad_rc" "$bad_out"

printf 'not json at all\n' >"$tmp/not-json.txt"
nj_out="$tmp/nj-out.json"
rm -f "$nj_out"
GITHUB_STATS_INPUT="$tmp/not-json.txt" bash "$script" "$nj_out" >/dev/null 2>"$tmp/nj.err"
nj_rc=$?
assert "write-github-stats soft-fails on non-JSON" soft_no_out "$nj_rc" "$nj_out"

miss_out="$tmp/miss-out.json"
rm -f "$miss_out"
GITHUB_STATS_INPUT="$tmp/missing-input.json" bash "$script" "$miss_out" >/dev/null 2>"$tmp/miss.err"
miss_rc=$?
assert "write-github-stats soft-fails on missing input" soft_no_out "$miss_rc" "$miss_out"

stats_run_needle=$(printf '%s%s%s' \
  '.github/scripts/write-github-stats.sh "' '$' 'RUNNER_TEMP/site/github-stats.json"')
assert "staging runs write-github-stats.sh on github-stats.json" \
  grep -Fq "$stats_run_needle" "$staging"

stats_step_order() {
  python3 - "$staging" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
needle = '.github/scripts/write-github-stats.sh "$RUNNER_TEMP/site/github-stats.json"'
overlay = stats = sync = None
for i, line in enumerate(lines):
    if "Apply the private overlay" in line:
        overlay = i
    if needle in line:
        stats = i
    if sync is None and "aws s3 sync" in line:
        sync = i
if overlay is None or stats is None or sync is None:
    print(f"    markers missing: overlay={overlay} stats={stats} sync={sync}")
    sys.exit(1)
if not (overlay < stats < sync):
    print(f"    order wrong: overlay={overlay} stats={stats} sync={sync}")
    sys.exit(1)
sys.exit(0)
PY
}
assert "write-github-stats runs after overlay and before s3 sync" stats_step_order

# --- 9. Copy checks ---
assert "gate.html holds agent does not review it" \
  grep -Fq 'The agent that wrote a change does not review it.' "$root/gate.html"
assert "gate.html holds agent never gives final sign-off" \
  grep -Fq 'An agent never gives the final sign-off.' "$root/gate.html"

plans_line='Build is free and open source. Every paid plan includes Build, Gate and Readiness. Plans differ by repositories, seats and evidence retention.'
for page in build.html gate.html readiness.html; do
  assert "$page holds Build is free plans line" grep -Fq "$plans_line" "$root/$page"
  assert "$page links /pricing" grep -Fq 'href="/pricing"' "$root/$page"
done

assert "build.html holds Install Build" grep -Fq 'Install Build' "$root/build.html"
assert "build.html holds Open source. MIT. Always free." \
  grep -Fq 'Open source. MIT. Always free.' "$root/build.html"
assert "build.html holds By default, that is the merge." \
  grep -Fq 'By default, that is the merge.' "$root/build.html"
assert "build.html holds Lean" grep -Fq 'Lean' "$root/build.html"
assert "build.html holds Standard" grep -Fq 'Standard' "$root/build.html"
assert "build.html holds Heavy" grep -Fq 'Heavy' "$root/build.html"
assert "build.html holds /handover" grep -Fq '/handover' "$root/build.html"
assert "build.html holds /scaffold" grep -Fq '/scaffold' "$root/build.html"

banned_free() {
  local f hits=""
  for f in "$root"/*.html; do
    [ "$(basename "$f")" = "game.html" ] && continue
    if grep -Eiq -- 'for[[:space:]]+free\b' "$f"; then
      hits="$hits $(basename "$f"):for free"
    fi
    if grep -Fq -- 'Each step has a person who signs it off' "$f"; then
      hits="$hits $(basename "$f"):person-signs"
    fi
    if grep -Fq -- 'A developer writes the rule. A second developer approves it.' "$f"; then
      hits="$hits $(basename "$f"):developer-writes"
    fi
  done
  [ -z "$hits" ] || { echo "    found in:$hits"; return 1; }
}
assert "no root html (except game) holds banned free/sign-off copy" banned_free

assert "pricing.html holds id=plans" grep -Fq 'id="plans"' "$root/pricing.html"
one_table() {
  local n
  n=$(grep -c '<table' "$root/pricing.html")
  [ "$n" -eq 1 ]
}
assert "pricing.html holds one table" one_table

no_old_tokens() {
  local f hits="" t
  for f in "$root"/*.html; do
    for t in COCKPIT_PLAN_NAME COCKPIT_PRICE COCKPIT_POINT_3 \
        READINESS_SCHEDULE_NAME READINESS_SCHEDULE_PRICE READINESS_SCHEDULE_POINT_3; do
      if grep -Fq -- "$t" "$f"; then
        hits="$hits $(basename "$f"):$t"
      fi
    done
  done
  [ -z "$hits" ] || { echo "    found in:$hits"; return 1; }
}
assert "no root html holds removed cockpit/schedule tokens" no_old_tokens

# --- 10. Docs changelog ---
changelog_releases_five() {
  awk "/id: 'changelog'/,/^  },/" "$root/docs-site/content-map.mjs" | grep -Fq 'releases: 5'
}
assert "content-map changelog has releases: 5" changelog_releases_five
assert "astro.config.mjs holds All releases" \
  grep -Fq 'All releases' "$root/docs-site/astro.config.mjs"
assert "astro.config.mjs holds github releases URL" \
  grep -Fq 'https://github.com/me2resh/apexyard/releases' "$root/docs-site/astro.config.mjs"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
