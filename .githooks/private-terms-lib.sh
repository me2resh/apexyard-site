#!/usr/bin/env bash
# Shared by the local commit-msg and pre-push hooks (#102).
# Reads terms from ~/.claude/apexyard/private/private-terms.txt. Without
# that file the hooks skip silently. Prints only field names and term
# indexes, never a term. Never add `set -x`.

pt_file=${PRIVATE_TERMS_FILE:-$HOME/.claude/apexyard/private/private-terms.txt}

# pt_scan <dir> : return 0 clean, 1 on a hit (message on stderr)
pt_scan() {
  [ -r "$pt_file" ] || return 0
  local root out rc
  root=$(git rev-parse --show-toplevel) || return 0
  [ -x "$root/.github/scripts/check-private-terms.sh" ] || return 0
  rc=0
  out=$(PRIVATE_TERMS=$(cat "$pt_file") "$root/.github/scripts/check-private-terms.sh" --text-dir "$1" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" | grep -v '^::add-mask::' >&2
    echo "private-terms: blocked. Remove the term from the message." >&2
    return 1
  fi
  return 0
}
