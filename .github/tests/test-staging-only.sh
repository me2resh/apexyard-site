#!/usr/bin/env bash
#
# #137. Staging-only files and deploy-time GitHub stats (AgDR-0011).
# Checks:
#   - production sync excludes previews.html and staging-only.js;
#   - staging deploy writes github-stats.json after the overlay;
#   - Netlify _redirects 404 the staging-only paths;
#   - write-github-stats.sh writes valid JSON from a fixture and
#     exits 0 without creating the out file on bad input.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
prod="$wf/deploy-aws.yml"
staging="$wf/deploy-staging-v2.yml"
redirects="$root/_redirects"
script="$root/.github/scripts/write-github-stats.sh"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

assert "previews.html exists"          test -f "$root/previews.html"
assert "staging-only.js exists"        test -f "$root/staging-only.js"
assert "write-github-stats.sh exists"  test -x "$script" -o -f "$script"

assert "prod sync excludes previews.html" \
  grep -Fq -- '--exclude "previews.html"' "$prod"
assert "prod sync excludes staging-only.js" \
  grep -Fq -- '--exclude "staging-only.js"' "$prod"

# shellcheck disable=SC2016 # the literal workflow text holds $RUNNER_TEMP
assert "staging writes github-stats.json" \
  grep -Fq 'write-github-stats.sh "$RUNNER_TEMP/site/github-stats.json"' "$staging"

assert "_redirects 404 /previews" \
  grep -Eq '^/previews[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /previews.html" \
  grep -Eq '^/previews\.html[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"
assert "_redirects 404 /staging-only.js" \
  grep -Eq '^/staging-only\.js[[:space:]]+/404\.html[[:space:]]+404!' "$redirects"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/good.json" <<'EOF'
{"stargazers_count": 12, "forks_count": 3}
EOF

out="$tmp/out.json"
rm -f "$out"
if GITHUB_STATS_INPUT="$tmp/good.json" GITHUB_STATS_DATE=2026-10-27 \
    bash "$script" "$out" >/dev/null; then
  if [ -f "$out" ] && grep -Fq '"stars": 12' "$out" \
      && grep -Fq '"forks": 3' "$out" \
      && grep -Fq '"asOf": "2026-10-27"' "$out"; then
    ok "write-github-stats writes dated JSON"
  else
    bad "write-github-stats writes dated JSON"
  fi
else
  bad "write-github-stats writes dated JSON"
fi

bad_out="$tmp/bad-out.json"
printf 'partial' >"$bad_out"
cat >"$tmp/bad.json" <<'EOF'
{"stargazers_count": "nope", "forks_count": 1}
EOF
if GITHUB_STATS_INPUT="$tmp/bad.json" bash "$script" "$bad_out" >/dev/null 2>"$tmp/err"; then
  if [ ! -f "$bad_out" ] && grep -Fq 'write-github-stats: not written' "$tmp/err"; then
    ok "write-github-stats fails soft on bad counts"
  else
    bad "write-github-stats fails soft on bad counts"
  fi
else
  bad "write-github-stats fails soft on bad counts"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
