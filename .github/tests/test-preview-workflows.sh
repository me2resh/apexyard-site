#!/usr/bin/env bash
#
# Regression guard for #91: the PR preview must not run pull request code next
# to AWS credentials, and AWS jobs must not declare `environment:` (the shared
# deploy role trusts the main branch subject only).

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wf="$root/.github/workflows"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
has() { grep -Eq -- "$2" "$1"; }
# assert <name> <command...>
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

build="$wf/preview-build.yml"
deploy="$wf/preview-deploy.yml"

assert "old pull_request_target workflow is gone"   test ! -e "$wf/deploy-aws-staging-pr.yml"
assert "no workflow uses pull_request_target"       bash -c "! grep -lE '^\s*pull_request_target:' '$wf'/*.yml"
assert "build runs on pull_request"                 has "$build" '^\s*pull_request:'
# Comment lines are stripped: the file headers name these words on purpose.
code_has() { grep -vE '^\s*#' "$1" | grep -qiE -- "$2"; }
code_lacks() { ! code_has "$1" "$2"; }
assert "build has no id-token"                      code_lacks "$build" 'id-token'
assert "build has no secrets"                       code_lacks "$build" 'secrets\.'
assert "build has no AWS step"                      code_lacks "$build" 'aws'
assert "build is contents: read only"               has "$build" '^  contents: read'
assert "build checkout drops credentials"           has "$build" 'persist-credentials: false'
assert "deploy triggers on workflow_run"            has "$deploy" '^\s*workflow_run:'
assert "deploy checkout has no ref override"        bash -c "! grep -qE '^\s*ref:' '$deploy'"
assert "deploy validates the artifact"              has "$deploy" 'validate-preview-artifact.sh'
assert "deploy syncs to the staging bucket root"    has "$deploy" 'aws s3 sync artifact "s3://\$\{BUCKET\}"'
assert "deploy sync does not follow symlinks"       has "$deploy" '--no-follow-symlinks'
assert "deploy publishes staging robots.txt"        has "$deploy" 'Disallow: /'
assert "deploy has no PR prefix"                    bash -c "! grep -q 'pr-\${PR_NUMBER}/' '$deploy'"
assert "deploy invalidates with the shared script"  has "$deploy" '^\s*run: \.github/scripts/invalidate-cloudfront\.sh'
assert "deploy never touches the prod bucket"       bash -c "! grep -q 'apexyard-site-prod' '$deploy'"
assert "deploy validates PR number as digits"       has "$deploy" '\^\[0-9\]\+\$'
assert "deploy does not use pull request head"      bash -c "! grep -q 'pull_request.head' '$deploy'"

# No job that assumes the role may declare environment:.
envcheck() {
  python3 - "$@" <<'PY'
import sys, yaml
bad = []
for path in sys.argv[1:]:
    doc = yaml.safe_load(open(path))
    for name, job in (doc.get("jobs") or {}).items():
        text = yaml.safe_dump(job)
        if "role-to-assume" in text and "environment" in job:
            bad.append(f"{path}:{name}")
if bad:
    print("jobs with AWS role and environment:", bad)
    sys.exit(1)
PY
}
if python3 -c 'import yaml' 2>/dev/null; then
  assert "no AWS-assuming job declares environment" envcheck "$wf"/*.yml
else
  echo "  skip  environment check (PyYAML not installed)"
fi

# deploy-production must need approve-production and have no if: that can bypass it.
prod_needs_approval() {
  python3 - "$wf/deploy-aws.yml" <<'PY'
import sys, yaml
job = yaml.safe_load(open(sys.argv[1]))["jobs"]["deploy-production"]
needs = job.get("needs")
needs = [needs] if isinstance(needs, str) else (needs or [])
cond = str(job.get("if", ""))
if "approve-production" not in needs or "always()" in cond or "cancelled()" in cond:
    sys.exit(1)
PY
}

assert "staging dispatch is manual only"            bash -c "! grep -qE '^\s*push:' '$wf/deploy-aws-staging.yml'"
assert "staging dispatch guarded to main"           has "$wf/deploy-aws-staging.yml" "github.ref == 'refs/heads/main'"
assert "deploy-production needs approve-production" prod_needs_approval
assert "deploy uses one fixed concurrency group"    has "$deploy" 'group: apexyard-staging-preview'
assert "deploy cancels older previews"              has "$deploy" 'cancel-in-progress: true'
assert "fork PR lookup lists open PRs"              has "$deploy" 'pulls\?state=open'
assert "fork PR lookup matches head repository"     has "$deploy" 'head\.repo\.full_name'
assert "unknown PR number does not fail the job"    has "$deploy" 'PR number unknown'
assert "production approval is its own job"         has "$wf/deploy-aws.yml" '^  approve-production:'

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
