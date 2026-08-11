#!/usr/bin/env bash
#
# Verify every primitive count the site quotes against the framework's shipped
# tag — see me2resh/apexyard-site#69.
#
# WHY THIS EXISTS
# The site hard-codes primitive counts across ~10 surfaces and refreshes them by
# hand on each framework release. The README documents what each count means,
# but nothing checked that the pages agreed with the definitions. The result is
# recorded in the v5.4.0 audit: the rules count sat at 11 for two releases while
# the hook count next to it was kept current, because each sync only fixed what
# someone happened to notice. The framework repo has a cross-repo drift-guard,
# but it cannot reach into this repo — so the check has to live here.
#
# WHAT IT DOES DIFFERENTLY FROM A GREP
# It does not look for the numbers it expects. It finds every place the site
# states "<number> <primitive-noun>" and asserts that number is the derived one.
# That inverts the failure mode: a surface nobody remembered to update is
# reported, rather than silently passing because the grep never looked there.
# Adding a new page with a stale count fails this check without anyone
# extending a list of files.
#
# Env (same contract as og/render.sh, so the cards and the pages agree):
#   APEXYARD_REPO  (required) path to a clone of me2resh/apexyard
#   REF            (required) the released tag to derive from, e.g. v5.4.0
#   SITE_ROOT      (optional) defaults to this repo's root
#
# Run locally:  APEXYARD_REPO=~/apex/apexyard REF=v5.4.0 .github/scripts/verify-counts.sh
#
# Exit codes: 0 = every surface agrees · 1 = drift found · 2 = cannot derive
#
# The release count is deliberately NOT checked here: it needs the GitHub
# Releases API (network + auth), and a verifier that fails when you are offline
# stops being run. `--releases` opts into it.

set -uo pipefail

fail() { echo "ERROR: $*" >&2; exit 2; }

APEXYARD_REPO="${APEXYARD_REPO:-}"
REF="${REF:-}"
[ -n "$APEXYARD_REPO" ] || fail "APEXYARD_REPO is unset — point it at a clone of me2resh/apexyard."
[ -n "$REF" ] || fail "REF is unset — set it to the released tag, e.g. REF=v5.4.0."
[ -d "$APEXYARD_REPO/.git" ] || fail "APEXYARD_REPO='$APEXYARD_REPO' is not a git repository."
git -C "$APEXYARD_REPO" rev-parse --verify "$REF^{commit}" >/dev/null 2>&1 \
  || fail "REF='$REF' does not resolve in $APEXYARD_REPO. Fetch tags first: git -C '$APEXYARD_REPO' fetch --tags"

SITE_ROOT="${SITE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$SITE_ROOT" || fail "cannot cd to SITE_ROOT='$SITE_ROOT'"

check_releases=0
[ "${1:-}" = "--releases" ] && check_releases=1

# --- derive from the tag ----------------------------------------------------
# These are the README's definitions verbatim. If you change one, change it in
# three places at once: here, the README table, and og/render.sh — they are the
# same contract, and the audit exists because they once drifted apart.

derive() {
  local what="$1" n
  case "$what" in
    skills) n=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- .claude/skills \
                 | grep -c '/SKILL\.md$') ;;
    hooks)  n=$(git -C "$APEXYARD_REPO" ls-tree --name-only "$REF" -- .claude/hooks/ \
                 | sed 's#\.claude/hooks/##' | grep '\.sh$' | grep -vc '^_lib') ;;
    agents) n=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- .claude/agents \
                 | grep -c '\.md$') ;;
    roles)  n=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- roles \
                 | grep '\.md$' | grep -vc 'README.md') ;;
    rules)  n=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- .claude/rules \
                 | grep -c '\.md$') ;;
    *) fail "unknown primitive '$what'" ;;
  esac
  # A zero means a glob stopped matching because the framework layout moved.
  # Reporting "the site should say 0 skills" would be worse than refusing.
  # Tested as a string: a non-numeric value makes -eq raise an arithmetic error
  # and take the false branch, sliding past the guard.
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || fail "derived $what='$n' from $APEXYARD_REPO @ $REF (expected a positive integer — the framework layout likely moved and this script's globs need updating)."
  echo "$n"
}

# --- the noun phrases each primitive is quoted with --------------------------
# Extend these when a page introduces new wording. A phrase listed here is
# checked everywhere it appears; a phrase missing from here is not checked at
# all, so prefer over-listing.

nouns_skills='slash commands?|active skills?|skills'
nouns_hooks='shell hooks?|shell gates|small scripts|enforcement scripts|hooks'
nouns_agents='specialised (sub-)?agents?|specialised reviewer agents?|sub-agents?|agents'
nouns_roles='role definitions?|roles'
nouns_rules='modular rule files|modular self-discipline guides|rules'

# --- lines that look like counts but are not --------------------------------
# Every entry needs a reason. These are the two the v5.4.0 audit identified,
# plus the harness that renders them.

is_excluded() {
  local file="$1" line="$2"

  # The #gate-replay terminal counts hook WIRING ENTRIES in .claude/settings.json
  # at PR #787's merge commit (55 before, 56 after) — a different metric at a
  # fixed point in history, not today's hook-file count. The section promises
  # every line is checkable, so syncing it to the current count would falsify
  # the one line a reader can verify. It carries an inline HTML comment saying so.
  [[ "$line" == *"settings.json diff:"* ]] && return 0

  # The README's own prose about the line above, which quotes it verbatim in
  # order to tell the next person not to sync it. Excluding the thing and not
  # its documentation would fail the check on the warning against the check.
  [[ "$line" == *'55 → 56 hooks'* ]] && return 0

  # "5-20 structured tickets" in the /tickets-batch description is a range.
  [[ "$line" == *"structured tickets"* ]] && return 0

  # The scripted fan-out demo narrates "Spawning 3 agents..." — that is how many
  # agents the demo scenario spawns for three tickets, not how many the
  # framework ships. It is illustrative copy inside a JS transcript array.
  [[ "$line" == *"Spawning "*" agents"* ]] && return 0

  # og/render.sh and this script derive the counts; they quote the nouns in
  # comments and shell code, not as site claims.
  [[ "$file" == "og/render.sh" || "$file" == ".github/scripts/verify-counts.sh" ]] && return 0

  return 1
}

# --- scan --------------------------------------------------------------------

drift=0
checked=0

scan_primitive() {
  local what="$1" nouns="$2" want="$3"
  local hits file lineno line num

  # Tracked text files only. .github/ is excluded from the S3 sync (it is
  # scaffolding, not site content) and would otherwise match this script's
  # own documentation.
  # -H is load-bearing: without it grep omits the filename whenever xargs hands
  # it a single file, and the "file:line:text" parsing below silently shifts by
  # one field — reporting a line number as the filename. The real site always
  # has many matches so it never showed there; the test suite's one-file case
  # is what caught it.
  hits=$(git ls-files -z \
    | xargs -0 grep -HIniE "\b[0-9]+ (${nouns})\b" 2>/dev/null \
    | grep -vE '^(\.github/|og/README\.md)' || true)

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; hit="${hit#*:}"
    lineno="${hit%%:*}"; line="${hit#*:}"

    is_excluded "$file" "$line" && continue

    # Pull every "<n> <noun>" pair on the line — a line can carry two.
    while read -r num; do
      [ -n "$num" ] || continue
      checked=$((checked + 1))
      if [ "$num" != "$want" ]; then
        printf '  DRIFT  %-22s %s:%s  says %s %s, tag says %s\n' \
          "[$what]" "$file" "$lineno" "$num" "$what" "$want" >&2
        drift=$((drift + 1))
      fi
    done < <(printf '%s\n' "$line" | grep -oiE "\b[0-9]+ (${nouns})\b" | grep -oE '^[0-9]+')
  done <<< "$hits"
}

echo "Verifying site counts against $APEXYARD_REPO @ $REF"
echo

for p in skills hooks agents roles rules; do
  case "$p" in
    skills) nouns="$nouns_skills" ;;
    hooks)  nouns="$nouns_hooks" ;;
    agents) nouns="$nouns_agents" ;;
    roles)  nouns="$nouns_roles" ;;
    rules)  nouns="$nouns_rules" ;;
  esac
  want=$(derive "$p") || exit 2
  printf '  %-8s tag says %s\n' "$p" "$want"
  scan_primitive "$p" "$nouns" "$want"
done

# --- releases (opt-in; needs network + gh auth) ------------------------------

if [ "$check_releases" = 1 ]; then
  echo
  if ! command -v gh >/dev/null 2>&1; then
    echo "  releases  SKIPPED — gh not installed" >&2
  else
    rel=$(gh api --paginate repos/me2resh/apexyard/releases --jq '.[].tag_name' 2>/dev/null | grep -c . || true)
    if [[ "$rel" =~ ^[1-9][0-9]*$ ]]; then
      printf '  %-8s API says %s (published Releases, NOT git tags)\n' "releases" "$rel"
      scan_primitive "releases" 'production releases shipped|published releases|releases' "$rel"
    else
      echo "  releases  SKIPPED — could not reach the Releases API" >&2
    fi
  fi
fi

# --- verdict -----------------------------------------------------------------

echo
if [ "$drift" -gt 0 ]; then
  echo "FAIL: $drift stale count(s) across the site; $checked claim(s) checked." >&2
  echo "      Refresh from the tag — do not copy forward the last sync's numbers." >&2
  exit 1
fi
echo "OK: $checked count claim(s) checked, all agree with $REF."
