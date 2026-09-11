#!/usr/bin/env bash
#
# Regression guard for me2resh/apexyard-site#72 — the shared derive library.
#
# Two things are under test, and the second is the point of the ticket:
#
#   1. The library derives what it says it derives, and refuses rather than
#      guesses when it cannot. This is the behaviour og/render.sh and
#      verify-counts.sh used to each own a copy of.
#   2. The README's definition block is byte-identical to `--recipes`. That
#      assertion is what makes the README a contract instead of a description.
#      Without it, unifying the three copies just moves the drift from
#      "three scripts" to "one script and one README".
#
# Runs against a synthetic framework repo built in a tempdir — nothing here
# touches the real framework clone, the network, or GitHub. The `releases`
# recipe is therefore never executed, only compared as text; it needs both.
#
# Run locally:  .github/tests/test-derive-counts.sh
#
# Lives under .github/ deliberately: the deploy workflows sync the repo root to
# S3 and exclude ".github/*", so test scaffolding stays off the public site.

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
lib="$repo_root/.github/scripts/derive-counts.sh"
readme="$repo_root/README.md"
[ -x "$lib" ] || { echo "FATAL: $lib missing or not executable"; exit 1; }

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

# shellcheck source=../scripts/derive-counts.sh
. "$lib"

echo "derive-counts.sh"

# --- synthetic framework repo ------------------------------------------------
# Deliberately mirrors test-verify-counts.sh's fixture so the two suites agree
# on what the definitions mean:
#   2 skills · 3 hooks (a _lib helper and a tests/ entry must not count) ·
#   1 agent · 2 roles (a README and a premium roles/growth/ entry must not
#   count) · 1 rule.

fw="$workdir/framework"
mkdir -p "$fw"/.claude/{skills/alpha,skills/beta,hooks/tests,agents,rules} \
         "$fw"/roles/eng "$fw"/roles/growth
(
  cd "$fw" || exit 1
  git init -q . && git config user.email t@t.t && git config user.name t
  touch .claude/skills/alpha/SKILL.md .claude/skills/beta/SKILL.md
  touch .claude/hooks/one.sh .claude/hooks/two.sh .claude/hooks/three.sh
  touch .claude/hooks/_lib-helper.sh .claude/hooks/tests/test-x.sh
  touch .claude/agents/rex.md
  touch roles/eng/dev.md roles/eng/lead.md roles/eng/README.md
  touch roles/growth/head-of-growth.md
  touch .claude/rules/one.md
  git add -A && git commit -qm init && git tag v9.9.9
) || { echo "FATAL: could not build synthetic framework"; exit 1; }

# --- case 1: each primitive derives what the recipe says ---------------------

check_count() {
  local what="$1" want="$2" got
  got=$(apexyard_derive_count "$what" "$fw" v9.9.9 2>&1)
  if [ "$got" = "$want" ]; then ok "$what derives $want"
  else bad "$what derives $want" "got '$got'"; fi
}

check_count skills 2
check_count hooks  3
check_count agents 1
check_count rules  1

# The load-bearing half of the roles definition. og/render.sh excluded premium
# roles/growth/ and the other two copies did not; the unified recipe keeps the
# exclusion, so the fixture carries a growth role that must NOT be counted. If
# someone "simplifies" the recipe back to the looser spelling, this reads 3.
check_count roles 2

# --- case 2: a vanished primitive refuses, and says which one ----------------
# Reporting "the site should say 0 skills" would be worse than refusing: it
# invites rewriting every correct page to a wrong number.

fw2="$workdir/framework-moved"
mkdir -p "$fw2"/.claude/rules
(
  cd "$fw2" || exit 1
  git init -q . && git config user.email t@t.t && git config user.name t
  touch .claude/rules/one.md
  git add -A && git commit -qm init && git tag v9.9.9
) || { echo "FATAL: could not build moved-layout framework"; exit 1; }

out=$(apexyard_derive_count skills "$fw2" v9.9.9 2>&1); rc=$?
if [ "$rc" != 0 ]; then ok "a vanished primitive returns non-zero"
else bad "a vanished primitive returns non-zero" "got rc=$rc out='$out'"; fi
case "$out" in
  *"skills='0'"*) ok "the refusal names the primitive and the bad value" ;;
  *) bad "the refusal names the primitive and the bad value" "$out" ;;
esac

# It must not print a number to stdout on the failure path — a caller doing
# `n=$(apexyard_derive_count ...) || exit 1` in a pipeline that swallows the
# status would otherwise stamp the diagnostic onto a card.
out_stdout=$(apexyard_derive_count skills "$fw2" v9.9.9 2>/dev/null)
if [ -z "$out_stdout" ]; then ok "nothing reaches stdout when derivation fails"
else bad "nothing reaches stdout when derivation fails" "got '$out_stdout'"; fi

# --- case 3: an unknown primitive is refused, not silently zero -------------
out=$(apexyard_derive_count nonsense "$fw" v9.9.9 2>&1); rc=$?
if [ "$rc" != 0 ]; then ok "an unknown primitive returns non-zero"
else bad "an unknown primitive returns non-zero" "got rc=$rc out='$out'"; fi

# --- case 4: every recipe is individually runnable ---------------------------
# `--recipes` prints text; `apexyard_derive_count` evaluates it. If a recipe is
# only ever exercised through the derive path, a copy-paste of the documented
# command could still be broken. Run each printed recipe standalone, the way a
# reader of the README would, and require the same answer.
#
# `releases` is excluded: it needs network + gh auth.

for p in "${APEXYARD_TAG_PRIMITIVES[@]}"; do
  recipe=$(apexyard_count_recipe "$p")
  standalone=$(REPO="$fw" REF=v9.9.9 bash -c "$recipe" 2>/dev/null)
  derived=$(apexyard_derive_count "$p" "$fw" v9.9.9 2>/dev/null)
  if [ "$standalone" = "$derived" ] && [ -n "$derived" ]; then
    ok "the printed $p recipe runs standalone and agrees ($derived)"
  else
    bad "the printed $p recipe runs standalone and agrees" \
        "standalone='$standalone' derived='$derived'"
  fi
done

# --- case 5: the README block matches --recipes, byte for byte --------------
# The assertion the ticket is actually about. Extract what sits between the
# sentinels, drop the two markdown fence lines, and diff.

extract_readme_block() {
  sed -n '/^<!-- BEGIN derive-counts\.sh --recipes/,/^<!-- END derive-counts\.sh --recipes/p' "$readme" \
    | sed '1d;$d' \
    | sed '/^```/d'
}

block=$(extract_readme_block)
if [ -n "$block" ]; then ok "the README carries a sentinel-marked definition block"
else bad "the README carries a sentinel-marked definition block" "extracted nothing — sentinels missing or renamed"; fi

recipes=$("$lib" --recipes)
if [ "$block" = "$recipes" ]; then
  ok "the README block is byte-identical to --recipes"
else
  bad "the README block is byte-identical to --recipes" \
      "$(diff <(printf '%s\n' "$recipes") <(printf '%s\n' "$block") | head -20)"
fi

# The guard has to be able to fail, or it is decoration. Mutate one character of
# the extracted block and require the comparison to reject it.
mutated=${block//SKILL/SKILLZ}
if [ "$mutated" != "$recipes" ]; then ok "a one-word README edit would be rejected"
else bad "a one-word README edit would be rejected" "mutation did not change the block"; fi

# --- case 6: --print reports every tag-derived primitive --------------------
out=$("$lib" --print "$fw" v9.9.9 2>&1); rc=$?
if [ "$rc" = 0 ]; then ok "--print exits 0 on a derivable repo"
else bad "--print exits 0 on a derivable repo" "got $rc: $out"; fi
# Report once, but only if every primitive was actually present — an
# unconditional ok() after a loop that can fail inflates the pass count and
# makes the suite's own tally untrustworthy.
missing=""
for p in "${APEXYARD_TAG_PRIMITIVES[@]}"; do
  case "$out" in
    *"$p"*) ;;
    *) missing="$missing $p" ;;
  esac
done
if [ -z "$missing" ]; then ok "--print reports every tag-derived primitive"
else bad "--print reports every tag-derived primitive" "missing:$missing"; fi

out=$("$lib" --print "$fw2" v9.9.9 2>&1); rc=$?
if [ "$rc" = 2 ]; then ok "--print exits 2 when it cannot derive"
else bad "--print exits 2 when it cannot derive" "got $rc: $out"; fi

# --- case 6b: the zero-count guard is reachable under `set -e` --------------
# derive-counts.sh keeps a `|| true` so a failing counting grep cannot abort the
# assignment before the guard runs. Which caller that protects is a claim about
# bash's errexit rules, and this repo does not keep those in comments — so it is
# asserted here, against whatever bash is running the suite.
#
# Three shapes, and only one of them has teeth:
#
#   direct      the shape `|| true` actually protects. Strip the fallback and
#               this assertion fails — that is the mutation sensitivity the
#               first version of this case lacked.
#   subst-or    what all six shipped call sites look like: a `$( )` on the LHS
#               of a `||`, where errexit is off regardless. Smoke test.
#   subst-bare  mirrors no shipped caller. Kept because it is the shape someone
#               would most plausibly add next, and it is the one whose result
#               is bash-dependent — on 3.2 errexit does not propagate into a
#               `$( )` subshell at all.
#
# All three ASSERT yes against the shipped library, on any bash: `|| true`
# guarantees the diagnostic reaches stderr before the `return 1`. The probe
# below is what varies, and `subst-bare=NO` appearing there is a real result,
# not a contradiction of the assertion above it.
#
# `$BASH` rather than `bash`: probe the interpreter actually running this suite.
# The two CAN differ — e.g. a Homebrew bash 5 ahead of macOS's /bin/bash on
# PATH, or an explicit `bash5 test-derive-counts.sh` — though on a stock macOS
# with no second bash installed they resolve to the same binary.

# The $( ) below must survive as literal text into the inner shell; expanding it
# here would run the derivation in THIS shell, which has no errexit.
# shellcheck disable=SC2016
guard_shape() {
  case "$1" in
    direct)     printf 'apexyard_derive_count skills "%s" v9.9.9' "$fw2" ;;
    subst-bare) printf 'n=$(apexyard_derive_count skills "%s" v9.9.9)' "$fw2" ;;
    subst-or)   printf 'n=$(apexyard_derive_count skills "%s" v9.9.9) || :' "$fw2" ;;
  esac
}

guard_reached() { # $1=lib $2=shape -> "YES"/"NO"
  local out
  out=$("$BASH" -c "set -euo pipefail; . '$1'; $(guard_shape "$2")" 2>&1)
  case "$out" in *"expected a positive integer"*) echo YES ;; *) echo NO ;; esac
}

for shape in direct subst-bare subst-or; do
  if [ "$(guard_reached "$lib" "$shape")" = YES ]; then
    ok "the zero-count guard is reached from a $shape set -e caller"
  else
    bad "the zero-count guard is reached from a $shape set -e caller" \
        "no diagnostic — errexit aborted before the guard on $("$BASH" --version | head -1)"
  fi
done

# Mutant probe — REPORTS, does not assert. Strip `|| true` and print which
# shapes still reach the guard. If a future bash makes the line inert
# everywhere, that is worth knowing (delete it), not worth failing a build over
# — so this records the answer in the CI log instead of turning a non-defect
# into a red run.
mutant="$workdir/derive-counts-mutant.sh"

# Both patterns below are deliberately literal: they match the SHELL SOURCE of
# derive-counts.sh, so `$(eval "$recipe")` must reach sed/grep unexpanded.
# shellcheck disable=SC2016
{
  sed 's/n=$(eval "$recipe") || true/n=$(eval "$recipe")/' "$lib" > "$mutant"
  mutated=no
  grep -q 'n=\$(eval "\$recipe")$' "$mutant" && mutated=yes
}

if [ "$mutated" = yes ]; then
  printf '  note  with the fallback stripped, guard reached:'
  for shape in direct subst-bare subst-or; do
    printf ' %s=%s' "$shape" "$(guard_reached "$mutant" "$shape")"
  done
  printf '  (on %s)\n' "$("$BASH" --version | head -1 | sed 's/ (.*//')"
else
  printf '  note  mutant probe skipped — the fallback line was not found to strip\n'
fi

# --- case 7: sourcing the library has no side effects -----------------------
# Both callers source it before doing their own argument handling. If it ever
# starts writing to stdout or exiting on source, render.sh stamps garbage.
out=$(bash -c ". '$lib'" 2>&1); rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then ok "sourcing is silent and exits 0"
else bad "sourcing is silent and exits 0" "got rc=$rc out='$out'"; fi

# --- verdict -----------------------------------------------------------------
echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
