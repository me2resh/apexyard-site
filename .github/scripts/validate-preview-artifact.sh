#!/usr/bin/env bash
#
# Validate an untrusted preview artifact before it is published (#91).
#
# The artifact comes from a pull request build, which can come from a fork.
# This script runs in the trusted deploy job, before AWS credentials are used.
# It never runs code from the artifact. It only inspects file names and types.
#
# Rejects:
#   - any symbolic link
#   - any entry that is not a regular file or a directory (device, fifo, socket)
#   - any name with a ".." path component
#   - any name with a backslash, a control character, or a leading "-"
#   - any real path that is outside the artifact folder
#   - an empty artifact
#
# Usage: validate-preview-artifact.sh <artifact-dir>
# Exit:  0 valid, 1 rejected, 2 usage error

set -uo pipefail

root_arg="${1:-}"
[ -n "$root_arg" ] || { echo "usage: $0 <artifact-dir>" >&2; exit 2; }
[ -d "$root_arg" ] || { echo "::error::artifact folder not found: $root_arg" >&2; exit 1; }
[ ! -L "$root_arg" ] || { echo "::error::artifact folder is a symlink" >&2; exit 1; }

root=$(cd "$root_arg" && pwd -P) || exit 1
fail() { echo "::error::preview artifact rejected: $*" >&2; exit 1; }

# 1. No symlinks anywhere.
links=$(find "$root" -type l -print | head -n 5)
[ -z "$links" ] || fail "symbolic link(s) found: $(printf '%s' "$links" | tr '\n' ' ')"

# 2. Only regular files and directories.
odd=$(find "$root" ! -type f ! -type d -print | head -n 5)
[ -z "$odd" ] || fail "non-regular entry found: $(printf '%s' "$odd" | tr '\n' ' ')"

# 3. Name checks and containment, one entry at a time (NUL separated).
count=0
while IFS= read -r -d '' path; do
  rel="${path#"$root"/}"
  case "/$rel/" in
    */../*) fail "path escapes the output folder: $rel" ;;
  esac
  case "$rel" in
    -*) fail "name starts with a dash: $rel" ;;
    *\\*) fail "name contains a backslash: $rel" ;;
  esac
  # Bash pattern, not grep: grep works per line and would miss a newline.
  if [[ "$rel" == *[[:cntrl:]]* ]]; then
    fail "name contains a control character"
  fi
  real=$(realpath -- "$path" 2>/dev/null) || fail "cannot resolve path: $rel"
  case "$real" in
    "$root"/*) ;;
    *) fail "real path is outside the output folder: $rel" ;;
  esac
  [ -f "$path" ] && count=$((count + 1))
done < <(find "$root" -mindepth 1 -print0)

[ "$count" -gt 0 ] || fail "artifact has no files"
echo "preview artifact ok: ${count} regular file(s)"
