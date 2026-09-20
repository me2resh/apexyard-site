#!/usr/bin/env bash
# Regression guard for the PR-only staging preview workflow.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
WORKFLOW="$ROOT/.github/workflows/deploy-aws-staging-pr.yml"
PASS=0
FAIL=0

ok() { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  not ok %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
contains() { grep -Fq -- "$1" "$WORKFLOW"; }

if contains 'pull_request_target:'; then ok 'PR previews use pull_request_target'; else bad 'PR previews use pull_request_target'; fi
if contains 'types: [opened, synchronize, reopened]'; then ok 'PR updates trigger preview deploys'; else bad 'PR updates trigger preview deploys'; fi
if contains 'BUCKET: apexyard-site-staging'; then ok 'workflow targets the staging bucket'; else bad 'workflow targets the staging bucket'; fi
if contains 'path: base' && contains 'path: preview'; then ok 'base workflow and preview source use separate checkouts'; else bad 'base workflow and preview source use separate checkouts'; fi
if contains 'working-directory: base' && contains '.github/scripts/invalidate-cloudfront.sh'; then ok 'invalidation runs from the trusted base checkout'; else bad 'invalidation runs from the trusted base checkout'; fi
if contains 'apexyard-site-prod'; then bad 'PR workflow contains no production bucket'; else ok 'PR workflow contains no production bucket'; fi
if contains 'deploy-aws.yml'; then bad 'PR workflow does not invoke production workflow'; else ok 'PR workflow does not invoke production workflow'; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
