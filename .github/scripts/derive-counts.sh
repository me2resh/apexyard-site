#!/usr/bin/env bash
#
# The one definition of every primitive count this site quotes — see
# me2resh/apexyard-site#72.
#
# WHY THIS EXISTS
# The definitions used to live in three places that had to be changed together:
# og/render.sh (stamps the social cards), .github/scripts/verify-counts.sh
# (asserts every page agrees), and the README's definition table (tells the next
# person what the numbers mean). verify-counts.sh said so in a comment — "change
# it in three places at once" — which is a note about rot, not a defence against
# it. The v5.4.0 audit exists because the counts themselves drifted for the same
# reason one level up: nothing derived them, so each sync fixed what someone
# noticed. Three hand-synced copies of the *derivation* is that same failure
# waiting one level down.
#
# They had in fact already drifted. Three differences on `main` at the time this
# was written, none of which changed a number at v5.4.0 and all of which would
# have eventually:
#   - roles: render.sh excluded premium `roles/growth/`; verify-counts.sh and
#     the README did not.
#   - releases: the README counted with `wc -l`, verify-counts.sh with
#     `grep -c .`.
#   - hooks: the README's sed left the leading dot unescaped.
#
# THE RECIPE IS THE DEFINITION
# Each count is stored once, as the text of the shell command that computes it.
# That single string is what gets evaluated to derive the number AND what gets
# printed for the README to quote. Documented and enforced cannot drift, because
# they are the same characters — test-derive-counts.sh asserts the README's block
# is byte-identical to `--recipes` output, so editing one without the other fails
# CI.
#
# The alternative — a function that computes, plus a comment that describes —
# is what was already here, in triplicate.
#
# TWO MODES
#   Sourced:  defines apexyard_derive_count / apexyard_count_recipe(s). Used by
#             og/render.sh and .github/scripts/verify-counts.sh.
#   Executed: --recipes            print every recipe (what the README quotes)
#             --print REPO REF     derive and print every tag-derived count
#
# Run locally:  .github/scripts/derive-counts.sh --print ~/apex/apexyard v5.4.0
#
# NOT COVERED HERE: `6 departments`. It is derivable and nothing checks it —
# adding a definition no caller consumes would be inventing a primitive rather
# than de-duplicating one. The README's gap list is where that is tracked.

# --- the recipes -------------------------------------------------------------
# Framework-only, derived from a RELEASE TAG of me2resh/apexyard. Both callers
# require a tag rather than a branch: a fork's local `main` can lag upstream by
# dozens of commits and derive old counts with no visible signal.
#
# `roles` excludes premium `roles/growth/`, carried over from og/render.sh —
# which is the stricter of the two definitions that were live, and the safe
# direction to unify in. It is a no-op at v5.4.0 (the framework repo tracks no
# roles/growth/ at that tag, so both spellings yield 20); it matters only if a
# fork ever commits premium roles under a release tag, in which case the site
# would otherwise advertise a count no reader of the open framework can
# reproduce.

apexyard_count_recipe() {
  case "$1" in
    skills) cat <<'RECIPE'
# skills — directories carrying a SKILL.md
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/skills | grep -c '/SKILL\.md$'
RECIPE
      ;;
    hooks) cat <<'RECIPE'
# hooks — top-level *.sh only; excludes _lib* helpers and the tests/ subdir
git -C "$REPO" ls-tree --name-only "$REF" -- .claude/hooks/ \
  | sed 's#\.claude/hooks/##' | grep '\.sh$' | grep -vc '^_lib'
RECIPE
      ;;
    agents) cat <<'RECIPE'
# agents — *.md under .claude/agents/
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/agents | grep -c '\.md$'
RECIPE
      ;;
    roles) cat <<'RECIPE'
# roles — *.md under roles/, excluding READMEs and premium roles/growth/
git -C "$REPO" ls-tree -r --name-only "$REF" -- roles \
  | grep '\.md$' | grep -v 'README.md' | grep -vc '^roles/growth/'
RECIPE
      ;;
    rules) cat <<'RECIPE'
# rules — *.md under .claude/rules/
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/rules | grep -c '\.md$'
RECIPE
      ;;
    releases) cat <<'RECIPE'
# releases — published GitHub Releases (NOT git tags; the two differ).
# Needs network + gh auth, so it is opt-in everywhere: `verify-counts.sh --releases`.
gh api --paginate repos/me2resh/apexyard/releases --jq '.[].tag_name' | grep -c .
RECIPE
      ;;
    *) echo "derive-counts: unknown primitive '$1'" >&2; return 2 ;;
  esac
}

# The five derived from a git tag, in the order the README and the verifier
# report them. `releases` is deliberately absent: it needs the network, and a
# check that fails when you are offline stops being run.
APEXYARD_TAG_PRIMITIVES=(skills hooks agents roles rules)

# The preamble's `v5.4.0` is ILLUSTRATIVE and tracks nothing. It is there so the
# block below is copy-pasteable, and it is the one string in this file that can
# still go stale — an empty placeholder would be worse (paste it and every
# recipe silently fails). Nothing derives from it; both callers take the ref
# from their own environment.
apexyard_count_recipes() {
  local p
  echo 'REPO=/path/to/apexyard REF=v5.4.0'
  for p in "${APEXYARD_TAG_PRIMITIVES[@]}" releases; do
    echo
    apexyard_count_recipe "$p"
  done
}

# --- derivation --------------------------------------------------------------
# apexyard_derive_count <primitive> <repo> <ref>
#
# Echoes the count on success. On failure prints a diagnostic naming what could
# not be derived and returns 1 — the CALLER picks the exit code, because the two
# callers disagree on purpose: verify-counts.sh exits 2 ("cannot derive", a
# different outcome from "found drift"), render.sh exits 1.

apexyard_derive_count() {
  local what="$1" n
  # shellcheck disable=SC2034  # REPO/REF are read by the recipe inside eval below
  local REPO="$2" REF="$3" recipe

  recipe=$(apexyard_count_recipe "$what") || return 1

  # Every recipe ends in a counting grep (`grep -c` / `grep -vc`), which prints
  # 0 and exits 1 when nothing matches — precisely the case the guard below
  # exists to explain. `|| true` keeps that status from aborting this assignment
  # under a caller's `set -e`, so the 0 reaches the guard and gets named instead
  # of surfacing as a bare exit code.
  #
  # WHICH CALLER THIS ACTUALLY PROTECTS. Not the two shipped ones: both wrap the
  # call as `$(…)` on the left of a `||` list, and errexit is off in that whole
  # context — removing this line changes nothing for them. It is load-bearing
  # for a DIRECT, unguarded call under `set -e`:
  #
  #     set -e; apexyard_derive_count skills "$repo" "$ref"
  #
  # With this line the guard runs and names the problem; without it the shell
  # aborts inside the function and the caller gets silence. Verified by mutation
  # rather than assumed, and test-derive-counts.sh keeps checking it — including
  # a non-asserting mutant probe whose result is printed, so the answer on CI's
  # bash is recorded rather than inferred from this comment.
  #
  # Not a pipefail defence, despite the wording this replaced. That belonged to
  # render.sh's old pipelines, which ended in `tr` — a failing grep mid-pipe
  # needed pipefail to be seen at all. Here the counting grep is the last
  # command, so its status is the pipeline's either way.
  n=$(eval "$recipe") || true

  # A zero means a glob stopped matching because the framework layout moved.
  # Reporting "the site should say 0 skills" would be worse than refusing: it
  # invites rewriting every correct page to a wrong number.
  #
  # Tested as a string, not with -eq: a non-numeric value makes -eq raise an
  # arithmetic error and take the false branch, sliding past the guard.
  if [[ ! "$n" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: derived $what='$n' from $REPO @ $REF (expected a positive integer —" >&2
    echo "  either REPO/REF do not point where you think, or the framework layout" >&2
    echo "  moved and this script's globs need updating)." >&2
    return 1
  fi
  echo "$n"
}

# --- CLI ---------------------------------------------------------------------
# Only when executed directly; sourcing must have no side effects.

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    --recipes)
      apexyard_count_recipes
      ;;
    --print)
      [ $# -eq 3 ] || { echo "usage: $0 --print <repo> <ref>" >&2; exit 2; }
      for _p in "${APEXYARD_TAG_PRIMITIVES[@]}"; do
        _n=$(apexyard_derive_count "$_p" "$2" "$3") || exit 2
        printf '%-8s %s\n' "$_p" "$_n"
      done
      ;;
    *)
      echo "usage: $0 --recipes | --print <repo> <ref>" >&2
      exit 2
      ;;
  esac
fi
