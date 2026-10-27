#!/usr/bin/env bash
#
# Write GitHub stars and forks for the home page (#137, AgDR-0011).
#
# Usage: write-github-stats.sh <out-file>
#
# Reads https://api.github.com/repos/me2resh/apexyard (public, no token).
# For tests, set GITHUB_STATS_INPUT to a local JSON file instead of the
# network. Writes {"stars": N, "forks": N, "asOf": "YYYY-MM-DD"} to
# <out-file>. asOf is the UTC date of the run, or GITHUB_STATS_DATE when set.
#
# On any failure (network, HTTP error, bad JSON, missing or bad numbers) it
# prints one line to stderr, removes a partial <out-file>, and exits 0 so
# the deploy continues. The home page hides the numbers when the file is
# absent.

set -euo pipefail

out=${1:?usage: write-github-stats.sh <out-file>}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

fail() {
  echo "write-github-stats: not written ($1)" >&2
  rm -f "$out"
  exit 0
}

if [ -n "${GITHUB_STATS_INPUT:-}" ]; then
  if [ ! -f "$GITHUB_STATS_INPUT" ]; then
    fail "input file missing"
  fi
  cp "$GITHUB_STATS_INPUT" "$tmp" || fail "input copy failed"
else
  if ! curl -fsS --max-time 10 \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/me2resh/apexyard" \
      >"$tmp"; then
    fail "network or HTTP error"
  fi
fi

as_of="${GITHUB_STATS_DATE:-}"
if [ -z "$as_of" ]; then
  as_of=$(date -u +%Y-%m-%d) || fail "date failed"
fi

# Parse from a temp file path (argv), not from a command-line JSON value.
if ! parsed=$(python3 -I - "$tmp" "$as_of" <<'PY'
import json
import sys

path, as_of = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(2)

try:
    stars = data["stargazers_count"]
    forks = data["forks_count"]
except (KeyError, TypeError):
    sys.exit(3)

if not isinstance(stars, int) or not isinstance(forks, int):
    sys.exit(4)
if stars < 0 or forks < 0:
    sys.exit(5)

print(json.dumps({"stars": stars, "forks": forks, "asOf": as_of}, separators=(",", ": ")))
PY
); then
  fail "bad JSON or counts"
fi

if ! printf '%s\n' "$parsed" >"$out"; then
  fail "write failed"
fi

echo "write-github-stats: wrote stars and forks as of ${as_of}"
exit 0
