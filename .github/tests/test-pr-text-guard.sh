#!/usr/bin/env bash
#
# Tests for the PR text guard (#102): check-pr-text.sh and the local hooks.
# Fake terms only. Each case builds a throwaway git repository.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
assert() { local n="$1"; shift; if "$@"; then ok "$n"; else bad "$n"; fi; }

# A repo that holds the guard scripts and the hooks, plus a base commit.
repo="$tmp/repo"
mkdir -p "$repo/.github/scripts"
cp "$root/.github/scripts/check-private-terms.sh" "$root/.github/scripts/check-pr-text.sh" "$repo/.github/scripts/"
cp -R "$root/.githooks" "$repo/.githooks"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.invalid
git -C "$repo" config user.name t
git -C "$repo" config commit.gpgsign false
printf 'a\n' > "$repo/f.txt"
git -C "$repo" add f.txt
git -C "$repo" commit -q -m "base commit"
base=$(git -C "$repo" rev-parse HEAD)

commit() { # <message> : adds a commit
  printf '%s\n' "$RANDOM" >> "$repo/f.txt"
  git -C "$repo" add f.txt
  git -C "$repo" -c core.hooksPath=/dev/null commit -q -m "$1"
}
event() { # <title> <body> : writes the event payload
  jq -n --arg t "$1" --arg b "$2" '{pull_request:{title:$t,body:$b}}' > "$tmp/event.json"
}
run() { # [env assignments...] : sets $out and $rc
  local head
  head=$(git -C "$repo" rev-parse HEAD)
  out=$(cd "$repo" && env -u PRIVATE_TERMS GITHUB_ACTIONS=true "$@" .github/scripts/check-pr-text.sh "$tmp/event.json" "$base" "$head" 2>&1)
  rc=$?
}
visible() { grep -v '^::add-mask::' <<<"$out"; }

terms=$'Zebraquartz\nNinety-nine moons'

# --- clean ---
commit "add a line"
event "A clean title" "A clean body."
run PRIVATE_TERMS="$terms"
assert "clean title, body and commits pass"            test "$rc" -eq 0

# --- title ---
event "Add zebraQUARTZ page" "A clean body."
run PRIVATE_TERMS="$terms"
assert "a hit in the title fails"                      test "$rc" -eq 1
assert "the title hit names field and index"           grep -q '^HIT    title (term 1)$' <<<"$out"

# --- body ---
event "A clean title" $'Line one\nThe Ninety-nine moons offer'
run PRIVATE_TERMS="$terms"
assert "a hit in the body fails"                       test "$rc" -eq 1
assert "the body hit names field and index"            grep -q '^HIT    body (term 2)$' <<<"$out"

# --- commit message ---
event "A clean title" "A clean body."
commit "tidy ZEBRAQUARTZ"
sha=$(git -C "$repo" rev-parse --short=7 HEAD)
run PRIVATE_TERMS="$terms"
assert "a hit in a commit message fails"               test "$rc" -eq 1
assert "the commit hit names the short sha and index"  grep -q "^HIT    commit-$sha (term 1)\$" <<<"$out"
assert "the clean commit is not named"                 test "$(grep -c '^HIT' <<<"$out")" -eq 1
assert "no term reaches the visible log"               bash -c "! grep -qiE 'zebraquartz|moons' <<<\"\$1\"" _ "$(visible)"
assert "every term is masked first"                    bash -c "grep -q '^::add-mask::Zebraquartz\$' <<<\"\$1\"" _ "$out"

# --- multi-line term (an overlay-style value): found whole, every line masked ---
git -C "$repo" reset -q --hard "$base"
commit "plain message"
mkdir -p "$tmp/fields"
printf 'Intro\nCrimson otter\nVelvet harbour\nend\n' > "$tmp/fields/body"
out=$(cd "$repo" && env -u PRIVATE_TERMS -u OVERLAY_JSON GITHUB_ACTIONS=true OVERLAY_JSON='{"FAKE_MULTI":"Crimson otter\nVelvet harbour"}' \
  .github/scripts/check-private-terms.sh --text-dir "$tmp/fields" 2>&1)
rc=$?
assert "a multi-line term is found in a field"         test "$rc" -eq 1
assert "each line of the term is masked on its own"    bash -c "grep -qx '::add-mask::Crimson otter' <<<\"\$1\" && grep -qx '::add-mask::Velvet harbour' <<<\"\$1\"" _ "$out"
assert "no line of the term appears unmasked"          bash -c "! grep -v '^::add-mask::' <<<\"\$1\" | grep -qiE 'crimson|velvet'" _ "$out"

# --- fail closed on a bad range ---
head=$(git -C "$repo" rev-parse HEAD)
out=$(cd "$repo" && PRIVATE_TERMS="$terms" GITHUB_ACTIONS=true .github/scripts/check-pr-text.sh "$tmp/event.json" 1111111111111111111111111111111111111111 "$head" 2>&1); rc=$?
assert "an unresolvable range fails closed"            test "$rc" -eq 1
assert "the range error is generic"                    grep -q 'failed closed' <<<"$out"
out=$(cd "$repo" && PRIVATE_TERMS="$terms" GITHUB_ACTIONS=true .github/scripts/check-pr-text.sh "$tmp/event.json" "$head" "$base" 2>&1); rc=$?
assert "an empty range for a non-empty PR fails closed" test "$rc" -eq 1

# --- no secret ---
event "Add zebraQUARTZ page" "A clean body."
run
assert "no secret skips with exit 0"                   test "$rc" -eq 0
assert "the skip prints a notice"                      grep -q '^::notice::check-pr-text: no private terms secret' <<<"$out"

# --- output never holds the term, on a hit with everything dirty ---
event "zebraquartz" "ninety-nine MOONS"
commit "zebraquartz again"
run PRIVATE_TERMS="$terms"
assert "all fields hit"                                test "$(grep -c '^HIT' <<<"$out")" -ge 3
assert "output never holds a term on any hit"          bash -c "! grep -v '^::add-mask::' <<<\"\$1\" | grep -qiE 'zebraquartz|moons'" _ "$out"

# --- local hooks ---
tf="$tmp/terms.txt"
printf '# comment\nZebraquartz\nNinety-nine moons\n' > "$tf"
msg="$tmp/msg"
printf 'subject with zebraquartz inside\n' > "$msg"
hout=$(cd "$repo" && PRIVATE_TERMS_FILE="$tf" .githooks/commit-msg "$msg" 2>&1); hrc=$?
assert "commit-msg blocks a message with a term"       test "$hrc" -ne 0
assert "commit-msg prints the index only"              grep -q 'HIT    commit-message (term 1)' <<<"$hout"
assert "commit-msg output never holds the term"        bash -c "! grep -qiE 'zebraquartz|moons' <<<\"\$1\"" _ "$hout"
printf 'a clean subject\n' > "$msg"
hout=$(cd "$repo" && PRIVATE_TERMS_FILE="$tf" .githooks/commit-msg "$msg" 2>&1); hrc=$?
assert "commit-msg allows a clean message"             test "$hrc" -eq 0
printf 'subject with zebraquartz inside\n' > "$msg"
hout=$(cd "$repo" && PRIVATE_TERMS_FILE="$tmp/missing.txt" .githooks/commit-msg "$msg" 2>&1); hrc=$?
assert "commit-msg skips silently with no terms file"  bash -c "test $hrc -eq 0 && test -z \"\$1\"" _ "$hout"

# pre-push: HEAD holds dirty commits not on any remote
head=$(git -C "$repo" rev-parse HEAD)
zero=0000000000000000000000000000000000000000
hout=$(cd "$repo" && echo "refs/heads/x $head refs/heads/x $zero" | PRIVATE_TERMS_FILE="$tf" .githooks/pre-push 2>&1); hrc=$?
assert "pre-push blocks an outgoing dirty commit"      test "$hrc" -ne 0
assert "pre-push names the commit and index"           grep -q 'HIT    commit-.* (term 1)' <<<"$hout"
assert "pre-push output never holds the term"          bash -c "! grep -qiE 'zebraquartz|moons' <<<\"\$1\"" _ "$hout"
hout=$(cd "$repo" && echo "refs/heads/x $base refs/heads/x $zero" | PRIVATE_TERMS_FILE="$tf" .githooks/pre-push 2>&1); hrc=$?
assert "pre-push allows a clean outgoing range"        test "$hrc" -eq 0
hout=$(cd "$repo" && echo "refs/heads/x $head refs/heads/x $zero" | PRIVATE_TERMS_FILE="$tmp/missing.txt" .githooks/pre-push 2>&1); hrc=$?
assert "pre-push skips silently with no terms file"    bash -c "test $hrc -eq 0 && test -z \"\$1\"" _ "$hout"

# --- static rules ---
wf="$root/.github/workflows/private-terms-pr-text.yml"
assert "the workflow runs on the four PR event types"  grep -q 'types: \[opened, edited, synchronize, reopened\]' "$wf"
assert "the workflow reads PRIVATE_TERMS from a secret" grep -qE '^\s*PRIVATE_TERMS: \$\{\{ secrets\.PRIVATE_TERMS \}\}\s*$' "$wf"
assert "the PR text scripts have no set -x"            bash -c "! cat '$root/.github/scripts/check-pr-text.sh' '$root'/.githooks/* | grep -vE '^\s*#' | grep -qE 'set -[a-z]*x'"
assert "the PR template names the rules"               grep -q '0 hits' "$root/.github/pull_request_template.md"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
