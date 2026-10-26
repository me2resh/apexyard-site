#!/usr/bin/env bash
#
# ::add-mask:: must not print values outside GitHub Actions (#102).
# Fake terms and overlay values only.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check="$root/.github/scripts/check-private-terms.sh"
apply="$root/.github/scripts/apply-overlay.sh"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkrepo() { # <dir> : a git repo with one clean tracked page
  mkdir -p "$1"
  git -C "$1" init -q
  printf '<p>Free to start.</p>\n' > "$1/index.html"
  git -C "$1" add index.html
}

terms=$'Zebraquartz\nNinety-nine moons'
fake_re='zebraquartz|ninety-nine moons|FakeValueAlpha|FakeValueBeta'

# --- check-private-terms: local (GITHUB_ACTIONS unset) ---
mkrepo "$tmp/clean"
out=$(env -u GITHUB_ACTIONS -u OVERLAY_JSON PRIVATE_TERMS="$terms" "$check" "$tmp/clean" 2>&1)
rc=$?
assert "local clean check passes"                         test "$rc" -eq 0
assert "local clean prints the summary counts"            grep -q 'check-private-terms: 2 term(s), 1 file(s), 0 hit(s)' <<<"$out"
assert "local clean output holds no fake term"            bash -c "! grep -qiE '$fake_re' <<<\"\$1\"" _ "$out"
assert "local clean emits no add-mask line"               bash -c "! grep -q '^::add-mask::' <<<\"\$1\"" _ "$out"

mkrepo "$tmp/hit"
printf 'note: zebraQUARTZ appears here\n' > "$tmp/hit/notes.md"
git -C "$tmp/hit" add notes.md
out=$(env -u GITHUB_ACTIONS -u OVERLAY_JSON PRIVATE_TERMS="$terms" "$check" "$tmp/hit" 2>&1)
rc=$?
assert "local hit check fails"                            test "$rc" -eq 1
assert "local hit names the file"                         grep -q '^HIT    notes.md (term 1)$' <<<"$out"
assert "local hit prints the summary counts"              grep -q 'check-private-terms: 2 term(s), 2 file(s), 1 hit(s)' <<<"$out"
assert "local hit output holds no fake term"              bash -c "! grep -qiE '$fake_re' <<<\"\$1\"" _ "$out"
assert "local hit emits no add-mask line"                 bash -c "! grep -q '^::add-mask::' <<<\"\$1\"" _ "$out"

# --- check-private-terms: CI (GITHUB_ACTIONS=true) ---
out=$(env -u OVERLAY_JSON GITHUB_ACTIONS=true PRIVATE_TERMS="$terms" "$check" "$tmp/hit" 2>&1)
rc=$?
assert "CI hit check still fails"                         test "$rc" -eq 1
assert "CI hit masks Zebraquartz"                         bash -c "grep -q '^::add-mask::Zebraquartz$' <<<\"\$1\"" _ "$out"
assert "CI hit masks Ninety-nine moons"                   bash -c "grep -q '^::add-mask::Ninety-nine moons$' <<<\"\$1\"" _ "$out"

# --- apply-overlay: local (GITHUB_ACTIONS unset) ---
src="$tmp/src"
mkdir -p "$src"
cat > "$src/page.html" <<'HTML'
<p><!--{{TOKEN_A}}-->Pricing to be announced<!--/{{TOKEN_A}}--></p>
<p><!--{{TOKEN_B}}-->To be announced<!--/{{TOKEN_B}}--></p>
HTML
good_json='{"TOKEN_A":"FakeValueAlpha <9>","TOKEN_B":"FakeValueBeta"}'

log=$(env -u GITHUB_ACTIONS OVERLAY_JSON="$good_json" "$apply" "$src" "$tmp/out-local" 2>&1)
rc=$?
assert "local apply succeeds"                             test "$rc" -eq 0
assert "local apply prints token counts"                  bash -c "grep -q 'TOKEN_A replaced 1 time' <<<\"\$1\" && grep -q 'TOKEN_B replaced 1 time' <<<\"\$1\"" _ "$log"
assert "local apply output holds no fake value"           bash -c "! grep -qiE 'FakeValueAlpha|FakeValueBeta' <<<\"\$1\"" _ "$log"
assert "local apply emits no add-mask line"               bash -c "! grep -q '^::add-mask::' <<<\"\$1\"" _ "$log"

# --- apply-overlay: CI (GITHUB_ACTIONS=true) ---
log=$(OVERLAY_JSON="$good_json" GITHUB_ACTIONS=true "$apply" "$src" "$tmp/out-ci" 2>&1)
rc=$?
assert "CI apply succeeds"                                test "$rc" -eq 0
assert "CI apply masks FakeValueBeta"                     bash -c "grep -qx '::add-mask::FakeValueBeta' <<<\"\$1\"" _ "$log"
assert "CI apply masks the escaped FakeValueAlpha"        bash -c "grep -qx '::add-mask::FakeValueAlpha &lt;9&gt;' <<<\"\$1\"" _ "$log"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
