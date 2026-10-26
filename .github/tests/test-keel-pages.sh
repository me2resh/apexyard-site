#!/usr/bin/env bash
#
# Guard for #102: Build, Gate and Readiness connect pages link Keel to /#product.
# index.html must keep id="product" for that anchor.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fail=0

pass() { printf 'PASS  %s\n' "$1"; }
fail_msg() { printf 'FAIL  %s\n' "$1"; fail=1; }

keel_anchor='<a href="/#product">Keel</a>'

connects_section() {
  local file="$1"
  # Cut the How it connects section: from connects-title label to </section>.
  awk '/aria-labelledby="connects-title"/,/<\/section>/' "$file"
}

check_keel_link() {
  local page="$1"
  local file="$root/$page"
  local section

  if [ ! -f "$file" ]; then
    fail_msg "$page missing"
    return
  fi

  section=$(connects_section "$file")
  if [ -z "$section" ]; then
    fail_msg "$page has no connects-title section"
    return
  fi

  if printf '%s\n' "$section" | grep -F "$keel_anchor" >/dev/null; then
    pass "$page connects section links Keel to /#product"
  else
    fail_msg "$page connects section missing $keel_anchor"
  fi
}

check_keel_link build.html
check_keel_link gate.html
check_keel_link readiness.html

if grep -F 'id="product"' "$root/index.html" >/dev/null; then
  pass 'index.html has id="product"'
else
  fail_msg 'index.html missing id="product"'
fi

if [ "$fail" -ne 0 ]; then
  echo "keel-pages: FAIL"
  exit 1
fi
echo "keel-pages: PASS"
exit 0
