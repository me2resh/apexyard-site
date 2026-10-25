#!/usr/bin/env bash
#
# Regression guard for #102: apply-overlay.sh fills placeholder tokens from
# OVERLAY_JSON, never prints a value outside the ::add-mask:: command, and
# fails closed. check-prod-overlay-free.sh finds a value on a page.
# Uses fake values and a temp dir only. No network.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
apply="$root/.github/scripts/apply-overlay.sh"
check="$root/.github/scripts/check-prod-overlay-free.sh"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

src="$tmp/src"
mkdir -p "$src/sub"
cat > "$src/page.html" <<'HTML'
<p><!--{{TOKEN_A}}-->Pricing to be announced<!--/{{TOKEN_A}}--></p>
<p><!--{{TOKEN_B}}-->To be announced<!--/{{TOKEN_B}}--></p>
HTML
cat > "$src/sub/two.html" <<'HTML'
<span><!--{{TOKEN_A}}-->Pricing to be announced<!--/{{TOKEN_A}}--></span>
HTML
printf 'plain text\n' > "$src/notes.txt"
# OG card templates use their own {{NAME}} slots and are not published.
mkdir -p "$src/og/templates"
printf '<b>{{HOOKS}}</b>\n' > "$src/og/templates/card.html"

good_json='{"TOKEN_A":"FakeValueAlpha <9>","TOKEN_B":"FakeValueBeta"}'

run_apply() { # <json> <out> -> sets rc, log
  log=$(OVERLAY_JSON="$1" "$apply" "$src" "$2" 2>&1)
  rc=$?
}

# --- happy path ---
run_apply "$good_json" "$tmp/out1"
assert "applies with a valid overlay"                 test "$rc" -eq 0
assert "html value is escaped"                        grep -q 'FakeValueAlpha &lt;9&gt;' "$tmp/out1/page.html"
assert "second token is replaced"                     grep -q 'FakeValueBeta' "$tmp/out1/page.html"
assert "nested file is replaced"                      grep -q 'FakeValueAlpha' "$tmp/out1/sub/two.html"
assert "no token remains in the output"               bash -c "! grep -rq --exclude-dir=templates '{{' '$tmp/out1'"
assert "no fallback remains where a value applied"    bash -c "! grep -rq 'to be announced' '$tmp/out1'"
assert "source tree is unchanged"                     grep -q '<!--{{TOKEN_A}}-->' "$src/page.html"
assert "og templates are skipped"                     grep -q '{{HOOKS}}' "$tmp/out1/og/templates/card.html"
assert "log names the token with a count"             bash -c "grep -q 'TOKEN_A replaced 2 time' <<<\"\$1\"" _ "$log"

# The only log lines that may carry a value are ::add-mask:: commands.
leaky=$(grep -v '^::add-mask::' <<<"$log" | grep -cE 'FakeValue' || true)
assert "no value outside ::add-mask:: lines"          test "$leaky" -eq 0
assert "each value is masked"                         bash -c "grep -qx '::add-mask::FakeValueBeta' <<<\"\$1\"" _ "$log"
assert "the escaped form is masked too"               bash -c "grep -qx '::add-mask::FakeValueAlpha &lt;9&gt;' <<<\"\$1\"" _ "$log"

# --- fail closed ---
run_apply "" "$tmp/out2"
assert "empty overlay fails with exit 2"              test "$rc" -eq 2

run_apply 'not json FakeValueSecret' "$tmp/out3"
assert "malformed JSON fails"                         test "$rc" -ne 0
assert "malformed JSON is not echoed"                 bash -c "! grep -q 'FakeValueSecret' <<<\"\$1\"" _ "$log"

run_apply '{"TOKEN_A":"FakeValueAlpha"}' "$tmp/out4"
assert "a token with no value fails"                  test "$rc" -ne 0
assert "the missing token is named"                   bash -c "grep -q 'token TOKEN_B has no value' <<<\"\$1\"" _ "$log"

run_apply '{"TOKEN_A":"a","TOKEN_B":"b","TOKEN_C":"FakeValueGamma"}' "$tmp/out5"
assert "an unused overlay key fails"                  test "$rc" -ne 0
assert "the unused key is named, not its value"       bash -c "grep -q 'TOKEN_C matches no token' <<<\"\$1\" && ! grep -v '^::add-mask::' <<<\"\$1\" | grep -q FakeValueGamma" _ "$log"

run_apply '{"TOKEN_A":"line1\nFakeValueLine2","TOKEN_B":"b"}' "$tmp/out6"
assert "a multi-line value fails"                     test "$rc" -ne 0
assert "a multi-line value is not echoed"             bash -c "! grep -v '^::add-mask::' <<<\"\$1\" | grep -q 'FakeValueLine2'" _ "$log"
assert "each line of a multi-line value is masked"    bash -c "grep -qx '::add-mask::FakeValueLine2' <<<\"\$1\" && grep -qx '::add-mask::line1' <<<\"\$1\"" _ "$log"
assert "the masks come before the one-line error"     bash -c "[ \"\$(grep -n 'must be one line' <<<\"\$1\" | cut -d: -f1)\" -gt \"\$(grep -n '^::add-mask::FakeValueLine2$' <<<\"\$1\" | head -n 1 | cut -d: -f1)\" ]" _ "$log"

run_apply '{"bad-key":"x"}' "$tmp/out7"
assert "an invalid key name fails"                    test "$rc" -ne 0

# --- static rules on both scripts ---
for s in "$apply" "$check"; do
  n=$(basename "$s")
  assert "$n has no set -x"                           bash -c "! grep -vE '^\s*#' '$s' | grep -qE 'set -[a-z]*x|set -o xtrace'"
  assert "$n never echoes OVERLAY_JSON"               bash -c "! grep -vE '^\s*#' '$s' | grep -qE '(echo|printf|cat|tee).*[\$]\{?OVERLAY_JSON'"
  assert "$n passes no value on a command line"       bash -c "! grep -vE '^\s*#' '$s' | grep -qE 'python3[^|]*\\\$OVERLAY_JSON'"
done

# --- the real site accepts an overlay with the documented tokens ---
real_json='{"PLAN_HINT":"FakeValueH","FREE_REPO_LIMIT":"FakeValueFreeRepoLimit","STARTUP_PRICE":"FakeValueStartupPrice","STARTUP_LIMITS":"FakeValueStartupLimits","STARTUP_SUMMARY":"FakeValueStartupSummary","TEAM_REPO_LIMIT":"FakeValueTeamRepoLimit","TEAM_PRICE":"FakeValueP","TEAM_PRICE_NOTE":"FakeValueTeamPriceNote","FREE_BULLET_1":"FakeValueFreeBullet1","STARTUP_BULLET_1":"FakeValueStartupBullet1","STARTUP_BULLET_2":"FakeValueStartupBullet2","TEAM_SUPPORT":"FakeValueTeamSupport","ENTERPRISE_LIMITS":"FakeValueEnterpriseLimits","ENTERPRISE_SUMMARY":"FakeValueEnterpriseSummary","REVIEW_LITE_NAME":"FakeValueReviewLiteName","REVIEW_LITE_OFFER":"FakeValueReviewLiteOffer","REVIEW_LITE_PRICE":"FakeValueReviewLitePrice","REVIEW_NAME":"FakeValueReviewName","REVIEW_OFFER":"FakeValueReviewOffer","REVIEW_DETAILS":"FakeValueReviewDetails","REVIEW_PRICE":"FakeValueReviewPrice","REVIEW_TIERS":"FakeValueReviewTiers","REVIEW_GUARANTEE":"FakeValueReviewGuarantee","COCKPIT_PLAN_NAME":"FakeValueCockpitPlanName","COCKPIT_PRICE":"FakeValueCockpitPrice","READINESS_REPORT_PRICE":"FakeValueReadinessReportPrice","READINESS_SCHEDULE_NAME":"FakeValueReadinessScheduleName","READINESS_SCHEDULE_PRICE":"FakeValueReadinessSchedulePrice","REVIEWS_SUMMARY":"FakeValueReviewsSummary"}'
rlog=$(OVERLAY_JSON="$real_json" "$apply" "$root" "$tmp/real" 2>&1)
rrc=$?
assert "the real site applies the documented tokens"  test "$rrc" -eq 0
assert "the real pricing page gets the values"        grep -q 'FakeValueP' "$tmp/real/pricing.html"
assert "the real home page gets the plan hint"        grep -q 'FakeValueH' "$tmp/real/index.html"
assert "no Placeholder price label is left"           bash -c "! grep -q 'Placeholder price' \"\$1\"/*.html" _ "$tmp/real"
[ "$rrc" -eq 0 ] || grep -v '^::add-mask::' <<<"$rlog" | sed 's/^/    /'

# --- the production check finds a value ---
prod="$tmp/prod"
mkdir -p "$prod"
printf '<p>Pricing to be announced</p>\n' > "$prod/clean.html"
printf '<p>FakeValueAlpha &lt;9&gt;</p>\n' > "$prod/leak.html"
clog=$(OVERLAY_JSON="$good_json" PROD_BASE="file://$prod" "$check" "$tmp/out1" /clean.html 2>&1)
assert "clean production page passes"               test $? -eq 0
clog=$(OVERLAY_JSON="$good_json" PROD_BASE="file://$prod" "$check" "$tmp/out1" /leak.html 2>&1)
crc=$?
assert "a value on production fails the check"      test "$crc" -ne 0
assert "the leak names the token"                   bash -c "grep -q 'LEAK   /leak.html (token TOKEN_A)' <<<\"\$1\"" _ "$clog"
assert "the leak log has no value"                  bash -c "! grep -q 'FakeValue' <<<\"\$1\"" _ "$clog"
clog=$(OVERLAY_JSON="$good_json" PROD_BASE="file://$prod" "$check" "$tmp/out1" /missing.html 2>&1)
assert "an unreadable page fails the check"         test $? -ne 0

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
