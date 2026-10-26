#!/usr/bin/env bash
#
# #100. The install script is served at /install on staging only.
# The edge function rewrites /install to /install.html, so the S3 key is
# install.html. This test checks:
#   - the file in the repo matches the SHA-256 in install.source;
#   - the staging workflow copies to install.html with type and cache;
#   - every bucket-writing sync excludes install, install.html and
#     install.source (docs sync in deploy-staging-v2.yml is exempt);
#   - the production workflow does not publish install or install.html.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
staging="$wf/deploy-staging-v2.yml"
prod="$wf/deploy-aws.yml"
staging_manual="$wf/deploy-aws-staging.yml"
preview="$wf/preview-deploy.yml"
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

# Check one sync command text for the three install excludes.
check_one_sync() {
  local label="$1"
  local block="$2"
  local ex
  for ex in install install.html install.source; do
    if printf '%s\n' "$block" | grep -Fq -- "--exclude \"$ex\""; then
      ok "$label excludes $ex"
    else
      bad "$label excludes $ex"
    fi
  done
}

# Walk a workflow. For each `aws s3 sync` block (text from that line up to the
# first blank line or the next `- name:`), require the three excludes.
# Optional third arg: if the sync line matches this ERE, skip the block
# (deploy-staging-v2 docs sync).
assert_syncs_exclude_install() {
  local file="$1"
  local label="$2"
  local skip_re="${3:-}"
  local collecting=0
  local block=""
  local sync_n=0
  local line
  local sync_line=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$collecting" -eq 1 ]; then
      if [ -z "$line" ] || printf '%s\n' "$line" | grep -Eq '^[[:space:]]*-[[:space:]]name:'; then
        sync_n=$((sync_n + 1))
        if [ -n "$skip_re" ] && printf '%s\n' "$sync_line" | grep -Eq -- "$skip_re"; then
          :
        else
          check_one_sync "$label sync $sync_n" "$block"
        fi
        block=""
        sync_line=""
        collecting=0
      else
        block="$block
$line"
      fi
      continue
    fi
    if printf '%s\n' "$line" | grep -Eq 'aws s3 sync'; then
      collecting=1
      block="$line"
      sync_line="$line"
    fi
  done < "$file"

  if [ "$collecting" -eq 1 ]; then
    sync_n=$((sync_n + 1))
    if [ -n "$skip_re" ] && printf '%s\n' "$sync_line" | grep -Eq -- "$skip_re"; then
      :
    else
      check_one_sync "$label sync $sync_n" "$block"
    fi
  fi
}

recorded=$(sed -n 's/^sha256=//p' "$root/install.source")
actual=$(sha_of "$root/install")

assert "install.source records a SHA-256"        bash -c "[ '${#recorded}' -eq 64 ]"
assert "install.source records a commit"         grep -Eq '^commit=[0-9a-f]{40}$' "$root/install.source"
assert "served file equals the recorded SHA-256" test "$recorded" = "$actual"
assert "served file is a shell script"           bash -c "head -1 '$root/install' | grep -q '^#!'"

# Staging: copy repo file install to key install.html with type and cache.
assert "staging copies install to install.html" \
  has "$staging" 's3 cp .*/site/install" "s3://\$\{BUCKET\}/install.html"'
block=$(grep -A4 'site/install" "s3' "$staging")
assert "staging sets the content type"           grep -q 'content-type "text/plain; charset=utf-8"' <<<"$block"
assert "staging sets a short cache"              grep -q 'cache-control "max-age=300"' <<<"$block"
assert "staging has no s3 cp to key /install" \
  bash -c "! grep -vE '^\s*#' '$staging' | grep -Eq 's3 cp .*\$\{BUCKET\}/install\"'"

# Every bucket-writing sync excludes the three keys. Docs sync is exempt.
assert_syncs_exclude_install "$staging" "staging-v2" "\\\$out/docs"
assert_syncs_exclude_install "$prod" "deploy-aws"
assert_syncs_exclude_install "$staging_manual" "deploy-aws-staging"
assert_syncs_exclude_install "$preview" "preview-deploy"

# Production: nothing copies install or install.html.
assert "production never copies install" \
  bash -c "! grep -vE '^\s*#' '$prod' | grep -Eq 's3 cp .*[/ ]install[ \"]'"
assert "production never copies install.html" \
  bash -c "! grep -vE '^\s*#' '$prod' | grep -Eq 's3 cp .*[/ ]install\.html[ \"]'"
assert "no other workflow publishes install.html" \
  bash -c "! grep -lE 's3 cp .*/install\.html\"' '$wf'/*.yml | grep -v deploy-staging-v2.yml"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
