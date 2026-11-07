#!/usr/bin/env bash
#
# Checks:
#   - production sync excludes previews.html and staging-only.js;
#   - Netlify _redirects 404 the staging-only paths;
#   - the home page has both live GitHub badge images.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
prod="$wf/deploy-aws.yml"
redirects="$root/_redirects"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

assert "previews.html exists"          test -f "$root/previews.html"
assert "staging-only.js exists"        test -f "$root/staging-only.js"

index_lacks_staging_script() {
  ! grep -Eq '<script[^>]+src=["'\'']/staging-only\.js["'\'']' "$root/index.html"
}
assert "index.html has no staging-only.js script tag" index_lacks_staging_script
assert "product.js loads staging-only.js only on staging.apexyard.ai" \
  awk '
    /location\.hostname[[:space:]]*===[[:space:]]*['\''"]staging\.apexyard\.ai['\''"]/ { gated = 1 }
    gated && /staging-only\.js/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$root/product.js"

assert "prod sync excludes previews.html" \
  grep -Fq -- '--exclude "previews.html"' "$prod"
assert "prod sync excludes staging-only.js" \
  grep -Fq -- '--exclude "staging-only.js"' "$prod"

assert "_redirects 404 /previews" \
  grep -Eq '^/previews[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /previews.html" \
  grep -Eq '^/previews\.html[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /staging-only.js" \
  grep -Eq '^/staging-only\.js[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"

live_badges() {
  grep -Fq 'src="https://img.shields.io/github/stars/me2resh/apexyard?' "$root/index.html" &&
    grep -Fq 'src="https://img.shields.io/github/forks/me2resh/apexyard?' "$root/index.html"
}
assert "index.html has both live GitHub badge images" live_badges

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
