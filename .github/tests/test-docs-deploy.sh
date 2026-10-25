#!/usr/bin/env bash
# #107: the staging deploy builds the /docs sub-build and publishes it.
# Static checks on deploy-staging-v2.yml and build-docs.sh.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
wf="$root/.github/workflows/deploy-staging-v2.yml"
script="$root/.github/scripts/build-docs.sh"

pass=0
fail=0
assert() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
    echo "  ok    $name"
  else
    fail=$((fail + 1))
    echo "  FAIL  $name"
  fi
}
has() { grep -qE -- "$2" "$1"; }

# Print one job block: from "  <name>:" to the next two-space job key.
job() {
  awk -v name="  $1:" '
    $0 == name { on = 1; print; next }
    on && /^  [a-z][a-z0-9_-]*:$/ { exit }
    on { print }
  ' "$wf"
}

docs_job="$(mktemp)"
deploy_job="$(mktemp)"
trap 'rm -f "$docs_job" "$deploy_job"' EXIT
job docs >"$docs_job"
job deploy >"$deploy_job"

assert "a docs job exists"                          test -s "$docs_job"
assert "docs job is contents: read only"            has "$docs_job" '^      contents: read'
assert "docs job has no id-token permission"        bash -c "! grep -q 'id-token' '$docs_job'"
assert "docs job has no AWS step"                   bash -c "! grep -qi 'aws' '$docs_job'"
assert "docs job does not read the overlay secret"  bash -c "! grep -q 'STAGING_OVERLAY' '$docs_job'"
assert "docs job runs build-docs.sh"                has "$docs_job" 'build-docs\.sh'
assert "docs job uploads the built docs"            has "$docs_job" 'name: docs-site'
assert "deploy needs the docs job"                  has "$deploy_job" '^    needs: docs'
assert "deploy downloads the built docs"            has "$deploy_job" 'actions/download-artifact'
assert "site sync excludes docs.html"               has "$deploy_job" '--exclude "docs\.html"'
assert "site sync excludes docs-site source"        has "$deploy_job" '--exclude "docs-site/\*"'
assert "site sync still excludes internal docs/"    has "$deploy_job" '--exclude "docs/\*"'
assert "deploy syncs docs to the /docs prefix"      has "$deploy_job" 's3://\$\{BUCKET\}/docs"'
assert "deploy publishes the docs home"             has "$deploy_job" 's3://\$\{BUCKET\}/docs\.html"'
assert "deploy checks the search index exists"      has "$deploy_job" 'pagefind/pagefind\.js'
assert "deploy removes uploaded docs-site source"   has "$deploy_job" 'aws s3 rm "s3://\$\{BUCKET\}/docs-site/"'
# shellcheck disable=SC2016 # the pattern matches a literal $out
assert "build-docs writes the docs home"            has "$script" 'mv "\$out/docs/index\.html" "\$out/docs\.html"'
assert "build-docs runs the checks"                 has "$script" 'npm run check'
assert "build-docs checks the upload layout"        has "$script" "check-layout.mjs"
assert "repo has no old docs.html at the root"      test ! -e "$root/docs.html"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
