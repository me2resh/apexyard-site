#!/usr/bin/env bash
#
# Regression guard for me2resh/apexyard-site#48 — the CloudFront invalidation
# step must not report success when it did not invalidate.
#
# Runs .github/scripts/invalidate-cloudfront.sh against a stubbed `aws` and
# `curl` so every branch is exercised without touching a real AWS account.
# Before #48 the three lookup outcomes below (absent / denied / throttled) all
# produced a byte-identical warning and exit 0; cases 1-2 now fail loudly.
#
# Run locally:  .github/tests/test-invalidation-guard.sh
#
# This file lives under .github/ deliberately: the deploy workflows sync the
# repo root to S3 and exclude ".github/*", so test scaffolding stays off the
# public site.

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/.github/scripts/invalidate-cloudfront.sh"
[ -x "$script" ] || { echo "FATAL: $script missing or not executable"; exit 1; }

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$workdir/bin"

# --- stubs ------------------------------------------------------------------
# STUB_LOOKUP: found | absent | denied | throttled
# STUB_INVALIDATE: ok | fail | noid
cat > "$workdir/bin/aws" <<'STUB'
#!/usr/bin/env bash
if [ "${2:-}" = "list-distributions" ]; then
  case "${STUB_LOOKUP:-found}" in
    found)     echo "E1EXAMPLE123"; exit 0 ;;
    absent)    echo "None"; exit 0 ;;
    denied)    echo "An error occurred (AccessDenied) when calling the ListDistributions operation" >&2; exit 254 ;;
    throttled) echo "An error occurred (Throttling) when calling the ListDistributions operation" >&2; exit 254 ;;
  esac
fi
if [ "${2:-}" = "create-invalidation" ]; then
  case "${STUB_INVALIDATE:-ok}" in
    ok)   echo "I2ABCDEF7890"; exit 0 ;;
    fail) echo "An error occurred (AccessDenied) when calling the CreateInvalidation operation" >&2; exit 254 ;;
    noid) echo "None"; exit 0 ;;
  esac
fi
exit 0
STUB

# STUB_CURL: cloudfront | other | unreachable
cat > "$workdir/bin/curl" <<'STUB'
#!/usr/bin/env bash
case "${STUB_CURL:-unreachable}" in
  cloudfront)  printf 'HTTP/2 200\r\nserver: AmazonS3\r\nx-cache: Hit from cloudfront\r\nx-amz-cf-id: abc123==\r\n'; exit 0 ;;
  other)       printf 'HTTP/2 200\r\nserver: Netlify\r\nx-nf-request-id: xyz\r\n'; exit 0 ;;
  unreachable) exit 6 ;;
esac
STUB
chmod +x "$workdir/bin/aws" "$workdir/bin/curl"

# --- harness ----------------------------------------------------------------
pass=0 fail=0

# run <name> <expect_rc: 0|nonzero> <lookup> <invalidate> <curl> [expected substring]
run() {
  local name=$1 expect=$2 lookup=$3 invalidate=$4 curlmode=$5 needle=${6:-}
  local out rc summary
  summary="$workdir/summary.md"; : > "$summary"

  out=$(PATH="$workdir/bin:$PATH" \
        SITE_DOMAIN="staging.yard.apexscript.com" \
        STACK_HINT="the instaloc-infra apexyard-site-staging stack" \
        GITHUB_STEP_SUMMARY="$summary" \
        STUB_LOOKUP="$lookup" STUB_INVALIDATE="$invalidate" STUB_CURL="$curlmode" \
        "$script" 2>&1)
  rc=$?

  local ok=1
  if [ "$expect" = "0" ]; then
    [ "$rc" -eq 0 ] || ok=0
  else
    [ "$rc" -ne 0 ] || ok=0
  fi
  if [ -n "$needle" ] && ! printf '%s' "$out$(cat "$summary")" | grep -qF "$needle"; then
    ok=0
  fi

  if [ "$ok" -eq 1 ]; then
    pass=$((pass + 1)); printf '  ok    %-46s (exit %s)\n' "$name" "$rc"
  else
    fail=$((fail + 1))
    printf '  FAIL  %-46s (exit %s, wanted %s)\n' "$name" "$rc" "$expect"
    printf '        output: %s\n' "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
  fi
}

echo "Invalidation guard — #48"

# The bug: a failed lookup must never look like an unprovisioned stack.
run "lookup denied fails the job"        nonzero denied    ok   unreachable "cloudfront:ListDistributions"
run "lookup throttled fails the job"     nonzero throttled ok   unreachable "aws exit 254"

# The legitimate warn-and-continue window, and its impostor.
run "unprovisioned stack warns, exits 0" 0       absent    ok   unreachable "pre-apply window"
run "alias mismatch fails the job"       nonzero absent    ok   cloudfront  "different alias"

# The happy path must produce evidence, not just a zero exit.
run "invalidation succeeds"              0       found     ok   unreachable "I2ABCDEF7890"
run "distribution id in job summary"     0       found     ok   unreachable "E1EXAMPLE123"

# A purge we cannot prove happened is not a success.
run "create-invalidation error fails"    nonzero found     fail unreachable "create-invalidation failed"
run "missing invalidation id fails"      nonzero found     noid unreachable "no evidence"

# Structural: neither workflow may re-grow its own inline copy of the lookup.
echo "Both workflows delegate to the shared script"
for wf in deploy-aws.yml deploy-aws-staging.yml; do
  f="$repo_root/.github/workflows/$wf"
  if grep -q 'invalidate-cloudfront.sh' "$f" && ! grep -q 'list-distributions' "$f"; then
    pass=$((pass + 1)); printf '  ok    %-46s\n' "$wf"
  else
    fail=$((fail + 1)); printf '  FAIL  %-46s still embeds its own lookup\n' "$wf"
  fi
done

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
