#!/usr/bin/env bash
#
# Invalidate the CloudFront distribution fronting $SITE_DOMAIN, and fail the
# job when it cannot — see me2resh/apexyard-site#48.
#
# WHY A SCRIPT INSTEAD OF AN INLINE `run:` BLOCK
# deploy-aws.yml and deploy-aws-staging.yml need byte-identical behaviour here.
# They previously held two hand-maintained copies of the same block, which is
# how the bug reached both at once. One script, called twice, makes "the same
# treatment on both workflows" structural rather than a copy-paste promise.
#
# THE BUG THIS REPLACES
# The old block was:
#
#   DIST_ID=$(aws cloudfront list-distributions --query ... 2>/dev/null || true)
#   if [ -z "$DIST_ID" ] || [ "$DIST_ID" = "None" ]; then
#     echo "::warning::No CloudFront distribution ... yet"; exit 0
#   fi
#
# `2>/dev/null || true` discarded both the error text and the exit code, so a
# missing cloudfront:ListDistributions permission, a throttled API call, and a
# genuinely-unprovisioned stack all produced the same warning and the same
# exit 0. The deploy reported success while never invalidating anything, and
# CloudFront kept serving stale pages until TTL expiry.
#
# WHAT IT DOES NOW — the lookup has three outcomes, not two:
#
#   1. lookup errored (permission / throttle / network)  -> FAIL loudly
#   2. lookup succeeded, distribution found              -> invalidate, assert an ID
#   3. lookup succeeded, matched nothing                 -> see below
#
# Case 3 is itself two different worlds, and conflating them is the other half
# of #48. Either the stack genuinely isn't applied yet (the documented pre-apply
# window — warn and continue), or a distribution IS serving this domain and our
# alias query simply didn't match it (an alias mismatch — a real fault that must
# not pass as "not provisioned yet"). We tell them apart by asking the domain
# itself whether CloudFront is answering for it.
#
# Env:
#   SITE_DOMAIN          (required) the distribution's alias, e.g. apexyard.ai
#   STACK_HINT           (optional) named in the pre-apply warning
#   INVALIDATION_PATHS   (optional) defaults to /*

# NOT `set -e`: every failure below is handled explicitly so it can carry a
# diagnostic. `-e` would abort at the first non-zero with no explanation, which
# is the failure mode this script exists to remove.
set -uo pipefail

: "${SITE_DOMAIN:?SITE_DOMAIN must be set}"
STACK_HINT="${STACK_HINT:-the instaloc-infra stack for ${SITE_DOMAIN}}"
INVALIDATION_PATHS="${INVALIDATION_PATHS:-/*}"

summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "::error::$*" >&2
  exit 1
}

# Append a row-shaped record of what happened to the job summary, so a green
# run is legible after the fact instead of requiring a log dig.
summarise() {
  {
    echo "### CloudFront invalidation — \`${SITE_DOMAIN}\`"
    echo
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Outcome | $1 |"
    echo "| Distribution | \`${2:-—}\` |"
    echo "| Invalidation | \`${3:-—}\` |"
    echo "| Paths | \`${INVALIDATION_PATHS}\` |"
  } >> "$summary_file"
}

# Does a CloudFront edge answer for this domain right now? Used only to
# distinguish "genuinely not provisioned" from "provisioned but our alias query
# missed it". CloudFront always stamps x-amz-cf-id; via/x-cache name it too.
serving_via_cloudfront() {
  local headers
  headers=$(curl -sS -I --max-time 15 "https://${1}/" 2>/dev/null) || return 1
  # Here-string, not `printf | grep`: under `pipefail`, grep -q short-circuits on
  # a match and the writer takes EPIPE, which pipefail then promotes to a
  # non-zero status for a pattern that DID match. Here that would read as "not
  # CloudFront" and fall through to warn-and-skip — reintroducing #48 inside the
  # function written to prevent it. Same construct measurably flaked in the test
  # harness (11/20 runs); this avoids the pipe entirely.
  grep -qiE '^x-amz-cf-id:|^(via|x-cache):.*cloudfront' <<< "$headers"
}

# ---------------------------------------------------------------- 1. lookup --
# stdout and the exit code are captured separately; stderr is kept, not
# dropped, because it carries the reason the operator needs.
# `Aliases.Items &&` is load-bearing, not defensive noise. CloudFront omits
# Aliases.Items entirely when Quantity == 0, and contains(null, …) is a
# JMESPath TYPE ERROR, not a non-match — verified against jmespath 1.1.0, the
# library the AWS CLI uses. A single alias-less distribution anywhere in the
# account therefore made the whole call exit non-zero. Under the old
# `2>/dev/null || true` that surfaced as "no distribution yet" + exit 0, which
# is a third candidate root cause for #48 the ticket doesn't list; without this
# guard the new fail-loudly path would break every deploy in the account.
dist_id=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items && contains(Aliases.Items, '${SITE_DOMAIN}')].Id | [0]" \
  --output text 2>"$tmp/lookup.err")
lookup_rc=$?
lookup_err=$(tr -d '\r' < "$tmp/lookup.err")

if [ "$lookup_rc" -ne 0 ]; then
  summarise "❌ lookup failed" "" ""
  fail "CloudFront distribution lookup for ${SITE_DOMAIN} failed (aws exit ${lookup_rc}). This is NOT the 'stack not applied yet' case — the API call itself did not succeed, so this deploy cannot know whether it needed to invalidate. Check, in order: the deploy role may be missing cloudfront:ListDistributions (#23); the call may have been throttled; or the --query may have hit a JMESPath type error. Read the stderr below before assuming which. aws stderr: ${lookup_err:-<empty>}"
fi

# ------------------------------------------------- 2. lookup matched nothing --
if [ -z "$dist_id" ] || [ "$dist_id" = "None" ]; then
  if serving_via_cloudfront "$SITE_DOMAIN"; then
    summarise "❌ alias mismatch" "" ""
    fail "No distribution matched alias ${SITE_DOMAIN}, but CloudFront is already answering for that domain — so a distribution IS serving it under a different alias, and skipping invalidation here would serve stale content behind a green build. Check the distribution's Aliases against SITE_DOMAIN."
  fi
  echo "::warning::No CloudFront distribution is serving ${SITE_DOMAIN}, and the domain is not answering from a CloudFront edge — treating this as the pre-apply window. Apply ${STACK_HINT} first. Skipping invalidation."
  summarise "⚠️ skipped — not provisioned yet" "" ""
  exit 0
fi

# ------------------------------------------------------------ 3. invalidate --
echo "Invalidating ${INVALIDATION_PATHS} on distribution ${dist_id} (${SITE_DOMAIN})"
# Split on whitespace so INVALIDATION_PATHS can carry more than one path;
# --paths takes a list, and passing the whole string as one argument would send
# CloudFront a single nonsense path.
read -ra invalidation_paths <<< "$INVALIDATION_PATHS"
inv_id=$(aws cloudfront create-invalidation \
  --distribution-id "$dist_id" \
  --paths "${invalidation_paths[@]}" \
  --query 'Invalidation.Id' \
  --output text 2>"$tmp/inv.err")
inv_rc=$?
inv_err=$(tr -d '\r' < "$tmp/inv.err")

if [ "$inv_rc" -ne 0 ]; then
  summarise "❌ invalidation failed" "$dist_id" ""
  fail "create-invalidation failed on distribution ${dist_id} (aws exit ${inv_rc}). aws stderr: ${inv_err:-<empty>}"
fi

# A zero exit with no ID would mean "we asked, nothing came back" — treat the
# missing receipt as a failure rather than assuming the purge happened.
if [ -z "$inv_id" ] || [ "$inv_id" = "None" ]; then
  summarise "❌ no invalidation ID returned" "$dist_id" ""
  fail "create-invalidation returned no Invalidation Id for distribution ${dist_id}, so there is no evidence the purge was accepted. Refusing to report a successful deploy."
fi

echo "Invalidation ${inv_id} created on distribution ${dist_id}"
summarise "✅ invalidated" "$dist_id" "$inv_id"
# Explicit: without this the script exits with summarise's status (the `>>`
# redirect), which is not what "the invalidation succeeded" should hinge on.
exit 0
