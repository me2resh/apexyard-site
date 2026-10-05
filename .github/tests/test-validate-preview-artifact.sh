#!/usr/bin/env bash
#
# Regression guard for #91: the deploy job must reject hostile preview
# artifacts (symlinks, escaping paths, special files) before publishing.
# Builds synthetic artifacts in a tempdir. Touches no network and no AWS.

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/.github/scripts/validate-preview-artifact.sh"
[ -x "$script" ] || { echo "FATAL: $script missing or not executable"; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0
fail=0

# check <name> <expect: ok|reject> <dir>
check() {
  local name="$1" expect="$2" dir="$3" rc
  "$script" "$dir" >/dev/null 2>&1
  rc=$?
  if { [ "$expect" = ok ] && [ "$rc" -eq 0 ]; } || { [ "$expect" = reject ] && [ "$rc" -eq 1 ]; }; then
    pass=$((pass + 1)); printf '  ok    %s\n' "$name"
  else
    fail=$((fail + 1)); printf '  FAIL  %s (exit %s)\n' "$name" "$rc"
  fi
}

mk() { rm -rf "$work/a"; mkdir -p "$work/a/sub"; echo hi > "$work/a/index.html"; echo hi > "$work/a/sub/page.html"; }

mk;                                                          check "regular files pass" ok "$work/a"
mk; ln -s /etc/passwd "$work/a/link.html";                   check "symlink to a file is rejected" reject "$work/a"
mk; ln -s /etc "$work/a/dir";                                check "symlink to a directory is rejected" reject "$work/a"
mk; ln -s index.html "$work/a/sub/inner.html";               check "symlink inside the folder is rejected" reject "$work/a"
mk; ln -s nowhere "$work/a/dangling.html";                   check "dangling symlink is rejected" reject "$work/a"
mk; mkfifo "$work/a/pipe";                                   check "fifo is rejected" reject "$work/a"
mk; : > "$work/a/-rf";                                       check "name starting with a dash is rejected" reject "$work/a"
mk; : > "$work/a/back\\slash";                               check "name with a backslash is rejected" reject "$work/a"
mk; : > "$work/a/$(printf 'bad\001name')";                   check "name with a control character is rejected" reject "$work/a"
mk; : > "$work/a/$(printf 'new\nline')";                     check "name with a newline is rejected" reject "$work/a"
rm -rf "$work/a"; mkdir -p "$work/a";                        check "empty artifact is rejected" reject "$work/a"
rm -rf "$work/a"; mkdir -p "$work/a/empty";                  check "directories only is rejected" reject "$work/a"
check "missing folder is rejected" reject "$work/none"
mk; ln -s "$work/a" "$work/root-link";                       check "folder that is a symlink is rejected" reject "$work/root-link"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
