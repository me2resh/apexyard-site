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

# Regression rows (Rex, PR 215): no check may PASS when the tool cannot observe it.
work=$(mktemp -d "${TMPDIR:-/tmp}/verify-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Stub Playwright. MODE=nomarker: no .marker element. MODE=zero: marker exists, line never on screen.
mkdir -p "$work/pw"
echo '{"name":"stub","main":"index.js"}' > "$work/pw/package.json"
cat > "$work/pw/index.js" <<'JS'
const mode = process.env.STUB_MODE;
const page = {
  on() {}, goto: async () => ({ status: () => 200 }), waitForTimeout: async () => {}, close: async () => {},
  evaluate: async (fn) => {
    const t = String(fn);
    if (t.includes('!!document.querySelector')) return mode !== 'nomarker';
    if (t.includes('scrollHeight')) return 800;
    if (t.includes('style.transform')) return 'x';
    if (t.includes('getBoundingClientRect')) return { cy: 300, vh: 800, lineOn: false };
    return undefined;
  },
};
exports.chromium = { launch: async () => ({ newPage: async () => page, close: async () => {} }) };
JS
for mode in nomarker zero; do
  res=$(STUB_MODE=$mode node .claude/skills/verify/sweep.js "$work/pw" http://127.0.0.1:1 2>&1)
  if printf '%s\n' "$res" | grep -q '^RESULT|[^|]*|PASS|'; then bad "sweep PASS with $mode"; else ok "sweep does not PASS with $mode"; fi
  if printf '%s\n' "$res" | grep -q '^RESULT|[^|]*|FAIL|'; then ok "sweep FAILs with $mode"; else bad "sweep did not FAIL with $mode"; fi
done

# Chrome fallback: stub browser logs a console.error line. No console row may PASS.
if command -v python3 >/dev/null 2>&1; then
  printf '#!/bin/sh\necho "<html><body>stub</body></html>"\necho "INFO:CONSOLE:1] \\"boom\\"" >&2\n' > "$work/chrome"
  chmod +x "$work/chrome"
  fb=$(VERIFY_FORCE_FALLBACK=1 CHROME_BIN="$work/chrome" VERIFY_SKIP_TESTS=1 bash .claude/skills/verify/verify.sh 2>/dev/null)
  if printf '%s\n' "$fb" | grep -i 'console' | grep -q '| PASS |'; then bad "fallback printed PASS for a console check"; else ok "fallback never PASSes a console check"; fi
  if printf '%s\n' "$fb" | grep -q 'console check: .*| SKIPPED |'; then ok "fallback labels the console check SKIPPED"; else bad "fallback console check not SKIPPED"; fi
  if printf '%s\n' "$fb" | grep -q '^- Result: Partial'; then ok "fallback result is Partial"; else bad "fallback result not Partial"; fi
else
  echo "SKIP  fallback rows: python3 missing"
fi

# Every browser launch must keep Chrome away from the real keychain.
if grep -n 'chromium.launch' .claude/skills/verify/sweep.js | grep -v -- 'ARGS' >/dev/null; then bad "a chromium.launch call lacks ARGS"; else ok "every chromium.launch passes ARGS"; fi
if grep -q -- "'--use-mock-keychain'" .claude/skills/verify/sweep.js && grep -q -- "'--password-store=basic'" .claude/skills/verify/sweep.js; then ok "sweep.js ARGS has the mock keychain flags"; else bad "sweep.js lacks the mock keychain flags"; fi
if grep -n '^ *"\$chrome" --' .claude/skills/verify/verify.sh | grep -v -- '--use-mock-keychain' | grep -q .; then bad "a Chrome launch in verify.sh lacks --use-mock-keychain"; else ok "verify.sh Chrome launch has --use-mock-keychain"; fi
exit "$fail"
