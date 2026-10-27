#!/usr/bin/env bash
#
# Guard for #102: "Works with" list includes Pi and omp.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fail=0

pass() { printf 'PASS  %s\n' "$1"; }
fail_msg() { printf 'FAIL  %s\n' "$1"; fail=1; }

want='Claude Code, Codex, Cursor, OpenCode, Pi and omp'
old='Claude Code, Codex, Cursor and OpenCode'

for f in index.html index.md.gen creators.html llms.txt llms-full.txt creator-brief.md; do
  if grep -F "$want" "$root/$f" >/dev/null; then
    pass "$f has updated works-with list"
  else
    fail_msg "$f missing updated works-with list"
  fi
done

if grep -w omp "$root/skill.md" >/dev/null; then
  pass "skill.md names omp"
else
  fail_msg "skill.md does not name omp"
fi

hits=0
for f in "$root"/*.html "$root"/*.md.gen "$root"/*.txt "$root"/creator-brief.md; do
  [ -f "$f" ] || continue
  if grep -F "$old" "$f" >/dev/null; then
    fail_msg "$(basename "$f") still has '$old'"
    hits=1
  fi
done
if [ "$hits" -eq 0 ]; then
  pass "no root page still has '$old'"
fi

if [ "$fail" -ne 0 ]; then
  echo "works-with: FAIL"
  exit 1
fi
echo "works-with: PASS"
exit 0
