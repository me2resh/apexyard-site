#!/usr/bin/env bash
# #214: the verify skill prints one evidence block, never reports a pass for a
# skipped check, and changes no tracked file. This run skips the browser and
# the test runner (the runner would call this test again).
set -uo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root" || exit 1
fail=0
ok() { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; fail=1; }

before=$(git status --porcelain)
out=$(VERIFY_NO_BROWSER=1 VERIFY_SKIP_TESTS=1 bash .claude/skills/verify/verify.sh 2>/dev/null)
code=$?
after=$(git status --porcelain)

if [ "$code" -eq 0 ]; then ok "verify.sh exits 0 when nothing fails"; else bad "verify.sh exit code $code"; fi
if [ "$(printf '%s\n' "$out" | grep -c '^## Verify evidence$')" -eq 1 ]; then ok "one evidence heading"; else bad "evidence heading count"; fi
for f in '^- Result: ' '^- Revision: ' '^- Environment: ' '^- Command: ' '^| Check | Status | Detail |$' '^- Cleanup: ' '^- Unverified: '; do
  if printf '%s\n' "$out" | grep -q -- "$f"; then ok "has $f"; else bad "missing $f"; fi
done
if printf '%s\n' "$out" | grep -q '^- Result: Partial'; then ok "result is Partial, not Passed"; else bad "skipped checks must not give Passed"; fi
if printf '%s\n' "$out" | grep -q '| SKIPPED |'; then ok "skipped checks are labelled SKIPPED"; else bad "no SKIPPED label"; fi
if printf '%s\n' "$out" | grep 'scroll sweep' | grep -q '| PASS |'; then bad "a skipped sweep reported PASS"; else ok "no pass for a skipped sweep"; fi
if printf '%s\n' "$out" | grep -q 'no tracked file changed | PASS'; then ok "tracked-file check passes"; else bad "tracked-file check missing"; fi
if [ "$before" = "$after" ]; then ok "git status --porcelain unchanged"; else bad "git status changed"; fi
exit "$fail"
