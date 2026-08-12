#!/usr/bin/env bash
# ====================================================================
# Reproducible OG-card render pipeline (Swiss Graphite).
#
#   templates/*.html  --(count substitution + headless Chromium)-->  *.png
#                     --(pngquant)-->  optimised <200KB PNG in place
#
# Framework-only component counts are derived from the apexyard ops-fork at a
# RELEASE TAG (default: the newest `v*` tag in that repo), EXCLUDING
# premium-injected items. Override the repo path with APEXYARD_REPO, the ref
# with APEXYARD_REF, or hard-pin counts with ROLES=/SKILLS=/HOOKS=.
#
# WHAT COUNTS AS A ROLE/SKILL/HOOK IS NOT DECIDED HERE. The definitions live in
# ../.github/scripts/derive-counts.sh, shared with the count verifier and the
# README's definition table, so a card can no longer disagree with the page it
# is the preview for (#72). This script owns finding the fork and picking the
# ref; that one owns the arithmetic.
#
# Two stale-count defences, both learned the hard way (see issue #49):
#   1. The repo path is DISCOVERED, not hardcoded — a hardcoded absolute path
#      goes stale the moment the fork moves, and the fallback was to hand-pin
#      counts, which then rot silently.
#   2. The default ref is an immutable release TAG, not `main` — a fork's local
#      `main` can lag upstream by dozens of commits and derive old counts
#      without any visible signal.
#
# Requires: node + playwright (chromium), pngquant. Install:
#   brew install pngquant
#   npx playwright install chromium
# ====================================================================
set -euo pipefail
cd "$(dirname "$0")"

# shellcheck source=../.github/scripts/derive-counts.sh
. ../.github/scripts/derive-counts.sh || {
  echo "ERROR: cannot source ../.github/scripts/derive-counts.sh — it holds the" >&2
  echo "  count definitions this script stamps onto the cards. Refusing to render." >&2
  exit 1
}

# --- Locate the apexyard ops fork -----------------------------------------
# A directory is the fork if it is a git repo carrying the framework's own
# layout. Walk up from this script and test each ancestor plus its `apexyard`
# child, so this works from a normal checkout AND from a git worktree (which
# sits several levels deeper under .claude/worktrees/).
is_apexyard_repo() {
  [[ -e "$1/.git" && -d "$1/roles" && -d "$1/.claude/skills" && -d "$1/.claude/hooks" ]]
}

discover_apexyard_repo() {
  local dir; dir="$(cd .. && pwd)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    is_apexyard_repo "$dir"            && { echo "$dir"; return 0; }
    is_apexyard_repo "$dir/apexyard"   && { echo "$dir/apexyard"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

APEXYARD_REPO="${APEXYARD_REPO:-$(discover_apexyard_repo || true)}"
if [[ -z "$APEXYARD_REPO" ]] || ! is_apexyard_repo "$APEXYARD_REPO"; then
  echo "ERROR: could not locate the apexyard ops fork." >&2
  echo "  Searched upward from $(pwd) for a git repo containing roles/," >&2
  echo "  .claude/skills/ and .claude/hooks/. Set APEXYARD_REPO=<path> to point" >&2
  echo "  at it explicitly." >&2
  exit 1
fi

# Default to the newest release tag — immutable and printed, so a stale ref is
# never silent the way a lagging local `main` was.
if [[ -z "${APEXYARD_REF:-}" ]]; then
  # `head -1` can SIGPIPE git, which set -o pipefail would turn into a silent
  # abort — read the sorted list into a var first, then take its first line.
  # Plain vX.Y.Z only: git's versionsort ranks `v5.5.0-rc1` ABOVE `v5.5.0`, so
  # an unfiltered list would quietly render the cards from a release candidate.
  all_tags=$(git -C "$APEXYARD_REPO" tag -l 'v*' --sort=-v:refname \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$') || true
  REF=${all_tags%%$'\n'*}
  if [[ -z "$REF" ]]; then
    echo "ERROR: no v* release tag found in $APEXYARD_REPO. Fetch tags, or set" >&2
    echo "  APEXYARD_REF=<ref> explicitly." >&2
    exit 1
  fi
else
  REF="$APEXYARD_REF"
fi
if ! git -C "$APEXYARD_REPO" rev-parse --verify --quiet "${REF}^{commit}" >/dev/null; then
  echo "ERROR: ref '$REF' does not resolve in $APEXYARD_REPO." >&2
  exit 1
fi

derive_counts() {
  if [[ -n "${ROLES:-}" && -n "${SKILLS:-}" && -n "${HOOKS:-}" ]]; then
    echo "WARNING: using hard-pinned counts ROLES=$ROLES SKILLS=$SKILLS HOOKS=$HOOKS" >&2
    echo "         Pinned counts do NOT track the framework and WILL go stale." >&2
    echo "         Unset ROLES/SKILLS/HOOKS to derive them from the repo." >&2
    return
  fi
  echo "Deriving framework-only counts from $APEXYARD_REPO @ $REF ..."

  # The zero-count guard, and the reason it is a string test rather than -eq,
  # both live in derive-counts.sh — as does the `|| true` that lets a
  # non-matching glob reach that guard instead of aborting the assignment under
  # `set -e`. All these three lines add is the render-specific verdict: a card
  # reading "0 skills" is worse than no card, so refuse rather than render.
  ROLES=$(apexyard_derive_count roles  "$APEXYARD_REPO" "$REF") || { echo "  Refusing to render." >&2; exit 1; }
  SKILLS=$(apexyard_derive_count skills "$APEXYARD_REPO" "$REF") || { echo "  Refusing to render." >&2; exit 1; }
  HOOKS=$(apexyard_derive_count hooks  "$APEXYARD_REPO" "$REF") || { echo "  Refusing to render." >&2; exit 1; }

  echo "Derived: ROLES=$ROLES SKILLS=$SKILLS HOOKS=$HOOKS"
}

derive_counts
export ROLES SKILLS HOOKS

echo "Rendering cards via headless Chromium ..."
node render.js

echo "Optimising with pngquant (--quality=70-90) ..."
for f in index architecture skills game; do
  pngquant --quality=70-90 --force --strip --output "${f}.png" "${f}.png" \
    || echo "  (pngquant skipped ${f}.png — already below quality floor)"
done

echo "Verifying dimensions + size ..."
fail=0
for f in index architecture skills game; do
  read -r w h < <(sips -g pixelWidth -g pixelHeight "${f}.png" 2>/dev/null \
    | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w, h}')
  bytes=$(stat -f%z "${f}.png" 2>/dev/null || stat -c%s "${f}.png")
  kb=$(( bytes / 1024 ))
  status="OK"
  if [[ "$w" != "1200" || "$h" != "630" ]]; then status="BAD-DIM"; fail=1; fi
  if (( bytes > 200*1024 )); then status="OVER-200KB"; fail=1; fi
  printf "  %-16s %sx%s  %sKB  [%s]\n" "${f}.png" "$w" "$h" "$kb" "$status"
done

if (( fail )); then echo "FAILED verification"; exit 1; fi
echo "All four cards verified: 1200x630, <200KB."
