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
# WHERE THE DEFINITIONS LIVE
# Not here. Every count is derived by .github/scripts/derive-counts.sh, which
# og/render.sh and the README's definition table also read from — so the cards,
# the pages, and the docs cannot disagree about what a count means (#72). This
# script owns the SCANNING; that one owns the ARITHMETIC.
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

# shellcheck source=derive-counts.sh
. "$(dirname "${BASH_SOURCE[0]}")/derive-counts.sh" \
  || fail "cannot source derive-counts.sh next to this script."

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
# The arithmetic lives in derive-counts.sh so this script, og/render.sh, and the
# README quote one definition rather than three hand-synced copies (#72). All
# this wrapper adds is THIS script's exit code: "cannot derive" is exit 2, a
# different outcome from "found drift", which is exit 1.

derive() {
  local n
  n=$(apexyard_derive_count "$1" "$APEXYARD_REPO" "$REF") \
    || fail "cannot derive '$1' — see the diagnostic above."
  echo "$n"
}

# --- the noun phrases each primitive is quoted with --------------------------
# A phrase is matched only where it starts IMMEDIATELY after the number, so an
# adjective in between defeats it: "66 active slash commands" is not matched by
# "slash commands". List the full phrase the page actually uses, longest first.
#
# Getting this wrong is not a theoretical risk — it shipped. The first version
# of this script omitted "active slash commands" and left 9 of the 10 skill
# claims on skills.html unchecked, on the page whose entire subject is that
# count. Hence the unverified sweep below: a phrase missing from these lists is
# now reported, not silently skipped.

nouns_skills='active slash commands?|slash commands?|active skills?|skills'
nouns_hooks='mechanical enforcement scripts|shell hooks?|shell gates|small scripts|enforcement scripts|hooks'
nouns_agents='specialised (sub-)?agents?|specialised reviewer agents?|sub-agents?|agents'
nouns_roles='role definitions?|roles'
nouns_rules='modular rule files|modular self-discipline guides|rule files|rules'

# --- things that look like counts but are not -------------------------------
# Two lists below: one scoped to a matched PHRASE, one to a whole LINE. Every
# entry needs a reason, and the reason has to be the one actually doing the
# work — a comment describing an effect an entry does not have is worse than no
# comment, because the next person trusts it. Two entries here are annotated as
# inert precisely so nobody assumes otherwise.

# Phrase-scoped exclusions, applied to ONE matched phrase rather than a whole
# line. These exist because line-scoping is dangerous where a line carries more
# than one claim: excluding the line to silence a sub-total also stops checking
# the total sitting beside it. That is not hypothetical — an earlier revision of
# this file excluded the line containing "18 department agents" and thereby
# un-checked the "23 specialised sub-agents" on the same line, so setting the 23
# to any value passed. Caught in review; hence the split.
#
# Use this list for phrases that are only ever reached by the sweep. A phrase
# the STRICT pass matches has to be handled in is_excluded() below, because by
# then the number has already been compared.
is_excluded_phrase() {
  local m="$1" file="${2:-}"

  # The README's worked example of this script's own UNVERIFIED output. Without
  # this, documenting the feature permanently trips it — the same shape as the
  # "55 → 56 hooks" quote below, where the warning against a check would
  # otherwise fail the check. Scoped to README.md so the phrase is still
  # reported if it ever appears on an actual page.
  [[ "$file" == "README.md" && "$m" == *"core rules"* ]] && return 0

  # "18 department agents" is a COMPONENT of a total, not a total: the sentence
  # reads "23 specialised sub-agents: 4 utility + Tariq + 18 department agents".
  # 4 + 1 + 18 = 23, verified against the agent files at v5.4.0. The 23 on the
  # same line is checked normally — that is the point of scoping this to the
  # phrase.
  [[ "$m" == *"department agents"* ]] && return 0

  # "4 named rules" counts the rules named in one callout paragraph, not the
  # framework's rule files.
  [[ "$m" == *"named rules"* ]] && return 0

  return 1
}

is_excluded() {
  local file="$1" line="$2"

  # The #gate-replay terminal counts hook WIRING ENTRIES in .claude/settings.json
  # at PR #787's merge commit (55 before, 56 after) — a different metric at a
  # fixed point in history, not today's hook-file count. The section promises
  # every line is checkable, so syncing it to the current count would falsify
  # the one line a reader can verify. It carries an inline HTML comment saying so.
  #
  # INERT ON THE SITE TODAY: index.html renders that line with an en-dash, which
  # the next entry catches first. This one matches the ASCII-arrow spelling, and
  # is currently load-bearing only in test-verify-counts.sh case 4. Kept so the
  # exclusion survives a re-render that changes the arrow.
  [[ "$line" == *"settings.json diff:"* ]] && return 0

  # The same claim in its en-dash spelling. Two places use it: the README's own
  # prose quoting the line above to tell the next person not to sync it, and any
  # rendering that uses "→" rather than "->". Excluding the thing but not its
  # documentation would fail the check on the warning against the check.
  [[ "$line" == *'55 → 56 hooks'* ]] && return 0

  # "5-20 structured tickets" in the /tickets-batch description is a range.
  # INERT TODAY, kept deliberately: no noun list contains "tickets", so nothing
  # currently reaches this line. It fires only if "tickets" is ever added as a
  # primitive noun — at which point a range would start reading as a count.
  [[ "$line" == *"structured tickets"* ]] && return 0

  # The scripted fan-out demo narrates "Spawning 3 agents..." — that is how many
  # agents the demo scenario spawns for three tickets, not how many the
  # framework ships. It is illustrative copy inside a JS transcript array.
  [[ "$line" == *"Spawning "*" agents"* ]] && return 0

  # og/render.sh quotes the primitive nouns in comments and shell code, not as
  # site claims. It no longer carries the derivations themselves (#72 moved
  # those to derive-counts.sh), but the exclusion stays: it is not the file's
  # arithmetic that matched here, it is its prose.
  #
  # Nothing under .github/ needs listing — the scan's own filter drops that
  # whole tree, which is why derive-counts.sh and this script are not named.
  [[ "$file" == "og/render.sh" ]] && return 0

  # apexdock/ is a different product's docs. Its pages describe ApexYard skills
  # in prose ("2-5 role agents in a debate") but carry none of the proof claims
  # this script guards, and their numbers are ranges and examples rather than
  # counts of anything at the tag.
  [[ "$file" == apexdock/* ]] && return 0

  return 1
}

# --- scan --------------------------------------------------------------------

drift=0
checked=0
unverified=0


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

# --- the unverified sweep ----------------------------------------------------
# The strict pass above only sees a number when a listed phrase follows it
# immediately. This finds the near-misses — a number, then up to four words,
# then a known noun — and reports any whose line the strict pass did not
# already cover for that primitive.
#
# It does NOT fail the run: these are claims of unknown correctness, not known
# drift, and failing on them would make the script something people stop
# running. It prints them, and the verdict line carries the count, so "the
# check passed" can never quietly mean "the check didn't look".
#
# The fix for an entry appearing here is to add the page's actual phrase to the
# noun list above — or to reword the page, if it is the odd one out.

sweep_unverified() {
  local what="$1" nouns="$2"
  local hits file lineno line

  hits=$(git ls-files -z \
    | xargs -0 grep -HIniE "\b[0-9]+( [a-zA-Z][a-zA-Z-]*){1,2} (${nouns})\b" 2>/dev/null \
    | grep -vE '^(\.github/|og/README\.md)' || true)

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; hit="${hit#*:}"
    lineno="${hit%%:*}"; line="${hit#*:}"

    is_excluded "$file" "$line" && continue

    # Judge each near-miss on its own text, not by whether the LINE was seen.
    # Two traps a line-level test falls into: the loose pattern re-matches a
    # claim the strict pass already caught (a listed phrase that itself starts
    # with a word — "66 active slash commands" is matched strictly, and loosely
    # by treating "active" as filler), and a line can carry one covered claim
    # beside one uncovered one, which is exactly the case that would hide a
    # stale count sitting next to a correct one.
    #
    # So: re-test each matched phrase against the STRICT pattern anchored whole.
    # If it passes, the strict pass already owns it. If not, nothing checked it.
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      printf '%s' "$m" | grep -qiE "^[0-9]+ (${nouns})$" && continue
      is_excluded_phrase "$m" "$file" && continue
      printf '  UNVERIFIED %-19s %s:%s  "%s" — no listed phrase matches\n' \
        "[$what]" "$file" "$lineno" "$m" >&2
      unverified=$((unverified + 1))
    done < <(printf '%s\n' "$line" \
      | grep -oiE "\b[0-9]+( [a-zA-Z][a-zA-Z-]*){1,2} (${nouns})\b" || true)
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
  sweep_unverified "$p" "$nouns"
done

# --- releases (opt-in; needs network + gh auth) ------------------------------

if [ "$check_releases" = 1 ]; then
  echo
  if ! command -v gh >/dev/null 2>&1; then
    echo "  releases  SKIPPED — gh not installed" >&2
  else
    # Same library, same recipe as the README quotes. Its "cannot derive"
    # diagnostic is suppressed here on purpose: for the release count, failing
    # to derive is the ordinary offline case, and this script reports that as
    # SKIPPED rather than as an error. The five tag-derived counts keep the
    # loud diagnostic — for those, not deriving IS the anomaly.
    rel=$(apexyard_derive_count releases "" "" 2>/dev/null) || rel=""
    if [ -n "$rel" ]; then
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
  echo "FAIL: $drift stale count(s) across the site; $checked claim(s) checked, $unverified unverified." >&2
  echo "      Refresh from the tag — do not copy forward the last sync's numbers." >&2
  exit 1
fi
if [ "$unverified" -gt 0 ]; then
  echo "OK (with gaps): $checked count claim(s) checked and agreeing with $REF," >&2
  echo "                but $unverified unverified claim(s) above matched no listed phrase." >&2
  echo "                Add each page's actual wording to the noun lists before trusting this as a full pass." >&2
  exit 0
fi
echo "OK: $checked count claim(s) checked, all agree with $REF. No unverified claims."
