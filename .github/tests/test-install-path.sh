#!/usr/bin/env bash
#
# #100. The install script is served at /install on staging only.
# This test checks three things:
#   - the file in the repo matches the SHA-256 in install.source;
#   - the staging workflow sets the content type and the cache for /install;
#   - the production workflow does not publish /install.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
staging="$wf/deploy-staging-v2.yml"
prod="$wf/deploy-aws.yml"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }
has() { grep -vE '^\s*#' "$1" | grep -Eq -- "$2"; }

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

recorded=$(sed -n 's/^sha256=//p' "$root/install.source")
actual=$(sha_of "$root/install")

assert "install.source records a SHA-256"        bash -c "[ '${#recorded}' -eq 64 ]"
assert "install.source records a commit"         grep -Eq '^commit=[0-9a-f]{40}$' "$root/install.source"
assert "served file equals the recorded SHA-256" test "$recorded" = "$actual"
assert "served file is a shell script"           bash -c "head -1 '$root/install' | grep -q '^#!'"

# Staging: the sync skips the key, then one copy sets type and cache.
assert "staging sync excludes install"           has "$staging" '--exclude "install"'
assert "staging copies install to its key"       has "$staging" 's3 cp .*/site/install" "s3://\$\{BUCKET\}/install"'
block=$(grep -A4 'site/install" "s3' "$staging")
assert "staging sets the content type"           grep -q 'content-type "text/plain; charset=utf-8"' <<<"$block"
assert "staging sets a short cache"              grep -q 'cache-control "max-age=300"' <<<"$block"

# Production: the sync excludes the key and nothing copies it.
assert "production excludes install"             has "$prod" '--exclude "install"'
assert "production excludes install.source"      has "$prod" '--exclude "install.source"'
assert "production never copies install"        bash -c "! grep -vE '^\s*#' '$prod' | grep -Eq 's3 cp .*[/ ]install[ \"]'"
excl=$(grep -cE -- '--exclude "install"' "$prod")
syncs=$(grep -cE 'aws s3 sync' "$prod")
assert "every production sync excludes install"  test "$excl" -eq "$syncs"
assert "no other workflow publishes /install"   bash -c "! grep -lE 's3 cp .*/install\"' '$wf'/*.yml | grep -v deploy-staging-v2.yml"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
