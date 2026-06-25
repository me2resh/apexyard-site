#!/usr/bin/env bash
# ====================================================================
# Reproducible OG-card render pipeline (Swiss Graphite).
#
#   templates/*.html  --(count substitution + headless Chromium)-->  *.png
#                     --(pngquant)-->  optimised <200KB PNG in place
#
# Framework-only component counts are derived from the apexyard ops-fork's
# `main` ref (released), EXCLUDING premium-injected items. Override the repo
# path with APEXYARD_REPO, or hard-pin counts with ROLES=/SKILLS=/HOOKS=.
#
# Requires: node + playwright (chromium), pngquant. Install:
#   brew install pngquant
#   npx playwright install chromium
# ====================================================================
set -euo pipefail
cd "$(dirname "$0")"

APEXYARD_REPO="${APEXYARD_REPO:-/Users/ahmed/Projects/Apex/apexyard}"
REF="${APEXYARD_REF:-main}"   # released. use APEXYARD_REF=dev for pre-release.

derive_counts() {
  if [[ -n "${ROLES:-}" && -n "${SKILLS:-}" && -n "${HOOKS:-}" ]]; then
    echo "Using hard-pinned counts: ROLES=$ROLES SKILLS=$SKILLS HOOKS=$HOOKS"
    return
  fi
  if [[ ! -d "$APEXYARD_REPO/.git" ]]; then
    echo "ERROR: apexyard repo not found at $APEXYARD_REPO (set APEXYARD_REPO)" >&2
    exit 1
  fi
  echo "Deriving framework-only counts from $APEXYARD_REPO @ $REF ..."

  # roles: tracked *.md under roles/, minus README, minus premium roles/growth/*
  ROLES=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- roles \
    | grep '\.md$' | grep -v 'README.md' | grep -v '^roles/growth/' | wc -l | tr -d ' ')

  # skills: skill dirs (those carrying a SKILL.md) on the released ref.
  # Premium skills are never committed to the framework repo's main, so this
  # is framework-only by construction.
  SKILLS=$(git -C "$APEXYARD_REPO" ls-tree -r --name-only "$REF" -- .claude/skills \
    | grep '/SKILL\.md$' | wc -l | tr -d ' ')

  # hooks: top-level *.sh in .claude/hooks/, excluding _lib* helpers and the tests/ subdir.
  HOOKS=$(git -C "$APEXYARD_REPO" ls-tree --name-only "$REF" -- .claude/hooks/ \
    | sed 's#\.claude/hooks/##' | grep '\.sh$' | grep -v '^_lib' | wc -l | tr -d ' ')

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
