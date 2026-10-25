#!/usr/bin/env bash
#
# Tests for .github/scripts/check-private-terms.sh (#102), with fake terms
# only. Each case builds a throwaway git repository in a tempdir.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check="$root/.github/scripts/check-private-terms.sh"
wf="$root/.github/workflows"
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

run() { # <repo> [env assignments...] : sets $out and $rc
  local repo=$1; shift
  out=$(env -u PRIVATE_TERMS -u OVERLAY_JSON -u REQUIRE_PRIVATE_TERMS "$@" "$check" "$repo" 2>&1)
  rc=$?
}
visible() { grep -v '^::add-mask::' <<<"$out"; }

terms=$'# a comment line\nZebraquartz\n\nPlumcrest &amp; Co\nNinety-nine moons'

# --- clean repo ---
mkrepo "$tmp/clean"
run "$tmp/clean" PRIVATE_TERMS="$terms"
assert "a clean repo passes"                              test "$rc" -eq 0
assert "the summary counts three terms"                   grep -q 'check-private-terms: 3 term(s), 1 file(s), 0 hit(s)' <<<"$out"

# --- a hit fails, names the file and index, never the term ---
mkrepo "$tmp/hit"
printf 'note: zebraQUARTZ appears here\n' > "$tmp/hit/notes.md"
mkdir -p "$tmp/hit/sub"
printf 'Ninety-nine moons\n' > "$tmp/hit/sub/fixture.txt"
printf 'Zebraquartz but not tracked\n' > "$tmp/hit/untracked.txt"
git -C "$tmp/hit" add notes.md sub/fixture.txt
run "$tmp/hit" PRIVATE_TERMS="$terms"
assert "a tracked term fails the check"                   test "$rc" -eq 1
assert "the hit names the file and term index"            grep -q '^HIT    notes.md (term 1)$' <<<"$out"
assert "a nested file is checked"                         grep -q '^HIT    sub/fixture.txt (term 3)$' <<<"$out"
assert "an untracked file is not checked"                 bash -c "! grep -q 'untracked.txt' <<<\"\$1\"" _ "$out"
assert "no term reaches the visible log"                  bash -c "! grep -qiE 'zebraquartz|plumcrest|moons' <<<\"\$1\"" _ "$(visible)"
assert "every term is masked"                             bash -c "grep -q '^::add-mask::Zebraquartz$' <<<\"\$1\" && grep -q '^::add-mask::Ninety-nine moons$' <<<\"\$1\"" _ "$out"
assert "masks come before any other output"               test "$(head -n 1 <<<"$out" | cut -c1-13)" = "::add-mask::Z"

# --- the HTML-escaped form is found ---
mkrepo "$tmp/esc"
printf '<p>Plumcrest &amp;amp; Co</p>\n' > "$tmp/esc/page.html"
git -C "$tmp/esc" add page.html
run "$tmp/esc" PRIVATE_TERMS="$terms"
assert "the HTML-escaped form of a term is found"         test "$rc" -eq 1

# --- binary files are skipped ---
mkrepo "$tmp/bin"
printf 'Zebraquartz\0\1\2' > "$tmp/bin/img.bin"
git -C "$tmp/bin" add img.bin
run "$tmp/bin" PRIVATE_TERMS="$terms"
assert "a binary file is skipped"                         test "$rc" -eq 0

# --- overlay values are terms, reported by token name ---
mkrepo "$tmp/ov"
printf 'Sapphire ledger plan\n' > "$tmp/ov/README.md"
git -C "$tmp/ov" add README.md
run "$tmp/ov" OVERLAY_JSON='{"FAKE_TOKEN":"Sapphire ledger plan","OTHER":"Unused value"}'
assert "an overlay value in a tracked file fails"         test "$rc" -eq 1
assert "the overlay hit names the token, not the value"   grep -q '^HIT    README.md (overlay FAKE_TOKEN)$' <<<"$out"
assert "no overlay value reaches the visible log"         bash -c "! grep -qi 'sapphire' <<<\"\$1\"" _ "$(visible)"
# --- a multi-line value: every line is masked, no line leaks ---
mkrepo "$tmp/ml"
printf 'Crimson otter\nVelvet harbour\n' > "$tmp/ml/page.md"
git -C "$tmp/ml" add page.md
run "$tmp/ml" OVERLAY_JSON='{"FAKE_MULTI":"Crimson otter\nVelvet harbour"}' PRIVATE_TERMS=$'Amber walrus'
assert "a multi-line overlay value is found"              test "$rc" -eq 1
assert "each line of the value is masked on its own"      bash -c "grep -qx '::add-mask::Crimson otter' <<<\"\$1\" && grep -qx '::add-mask::Velvet harbour' <<<\"\$1\"" _ "$out"
assert "no line of the value appears unmasked"            bash -c "! grep -v '^::add-mask::' <<<\"\$1\" | grep -qiE 'crimson|velvet|amber'" _ "$out"
assert "every output line with the value is a mask"       bash -c "! grep -iE 'crimson|velvet' <<<\"\$1\" | grep -qv '^::add-mask::'" _ "$out"

run "$tmp/ov" OVERLAY_JSON='not json'
assert "a malformed overlay exits 2"                      test "$rc" -eq 2

# --- no secret ---
run "$tmp/clean"
assert "no secret skips with exit 0"                      test "$rc" -eq 0
assert "the skip prints a notice"                         grep -q '^::notice::check-private-terms: no private terms secret' <<<"$out"
run "$tmp/clean" REQUIRE_PRIVATE_TERMS=true
assert "no secret fails when the check is required"       test "$rc" -eq 1
run "$tmp/clean" PRIVATE_TERMS=$'# only a comment\n\n'
assert "a secret with no terms exits 2"                   test "$rc" -eq 2

# --- static rules ---
assert "the script has no set -x"                         bash -c "! grep -vE '^\s*#' '$check' | grep -qE 'set -[a-z]*x|set -o xtrace'"
assert "no term is passed on a command line"              bash -c "! grep -vE '^\s*#' '$check' | grep -qE 'python3[^|]*\\\$(PRIVATE_TERMS|OVERLAY_JSON)'"
assert "the private-terms workflow runs the check"        grep -q 'check-private-terms.sh' "$wf/private-terms.yml"
assert "the workflow reads PRIVATE_TERMS from a secret"   grep -qE '^\s*PRIVATE_TERMS: \$\{\{ secrets\.PRIVATE_TERMS \}\}\s*$' "$wf/private-terms.yml"
assert "the workflow has no path filter"                  bash -c "! grep -q 'paths:' '$wf/private-terms.yml'"
assert "the staging deploy checks the overlay values"     grep -q 'check-private-terms.sh' "$wf/deploy-staging-v2.yml"
assert "the repo holds no term list file"                 bash -c "! git -C '$root' ls-files | grep -qiE 'private-terms\.(txt|list|json)$'"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
