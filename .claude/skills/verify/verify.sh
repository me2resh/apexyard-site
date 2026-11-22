#!/usr/bin/env bash
# Verify this static site. Prints one markdown evidence block on stdout.
# Progress goes to stderr. Changes no tracked file. Writes temp files under mktemp.
#   VERIFY_NO_BROWSER=1  skip the server and browser checks
#   VERIFY_SKIP_TESTS=1  skip the .github/tests/*.sh checks
#   VERIFY_PLAYWRIGHT_DIR=<dir>  use this Playwright install
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.." || exit 1
root=$(pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/verify.XXXXXX")
server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null; wait "$server_pid" 2>/dev/null; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

rows="$tmp/rows"; : > "$rows"
fails=0; skips=0
add() { # status name detail
  printf '| %s | %s | %s |\n' "$2" "$1" "$3" >> "$rows"
  case "$1" in FAIL) fails=$((fails + 1));; SKIPPED) skips=$((skips + 1));; esac
  echo "  $1  $2" >&2
}

rev=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
branch=$(git branch --show-current 2>/dev/null)
before=$(git status --porcelain)
dirty=$(printf '%s' "$before" | grep -c . || true)

# 1. Repository tests
if [ "${VERIFY_SKIP_TESTS:-}" = "1" ]; then
  add SKIPPED "tests: .github/tests/*.sh" "VERIFY_SKIP_TESTS=1"
else
  for t in .github/tests/*.sh; do
    [ -e "$t" ] || continue
    if out=$(bash "$t" 2>&1); then
      add PASS "test: $(basename "$t")" "exit 0"
    else
      code=$?
      add FAIL "test: $(basename "$t")" "exit $code; $(printf '%s' "$out" | tail -n 1 | tr '|' '/' | cut -c1-120)"
    fi
  done
fi

# 2. Browser checks
browser="none"
page_skip() { # reason
  for p in index how-it-works pricing skills; do
    add SKIPPED "page: $p.html loads, no console error" "$1"
    add SKIPPED "scroll sweep: $p.html marker in view" "$1"
  done
}
if [ "${VERIFY_NO_BROWSER:-}" = "1" ]; then
  page_skip "VERIFY_NO_BROWSER=1"
elif ! command -v python3 >/dev/null 2>&1; then
  page_skip "python3 is not installed, so the site cannot be served"
else
  port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root" >"$tmp/server.log" 2>&1 &
  server_pid=$!
  url="http://127.0.0.1:$port"
  ready=0
  for _ in $(seq 1 50); do
    if curl -fsS -o /dev/null "$url/index.html" 2>/dev/null; then ready=1; break; fi
    sleep 0.1
  done
  if [ "$ready" != 1 ]; then
    add FAIL "serve repo root" "server on $url not ready after 5 s"
  else
    add PASS "serve repo root" "python3 -m http.server on $url"
    pwdir=""
    for d in "${VERIFY_PLAYWRIGHT_DIR:-}" \
      "$(npm root -g 2>/dev/null)/playwright" \
      $(ls -d "$HOME"/.npm/_npx/*/node_modules/playwright 2>/dev/null); do
      if [ -n "$d" ] && [ -f "$d/package.json" ]; then pwdir="$d"; break; fi
    done
    done_browser=0
    if [ "${VERIFY_FORCE_FALLBACK:-}" != "1" ] && [ -n "$pwdir" ] && command -v node >/dev/null 2>&1; then
      if node "$root/.claude/skills/verify/sweep.js" "$pwdir" "$url" >"$tmp/sweep.out" 2>"$tmp/sweep.err" \
         && grep -q '^RESULT|' "$tmp/sweep.out"; then
        browser="Playwright (headless Chromium)"
        done_browser=1
        while IFS='|' read -r _ page status detail; do
          add "$status" "page: $page loads, no console error, marker in view during 25-step sweep" "$detail"
        done < <(grep '^RESULT|' "$tmp/sweep.out")
      else
        echo "  Playwright failed: $(head -c 200 "$tmp/sweep.err" "$tmp/sweep.out" | tr '\n' ' ')" >&2
      fi
    fi
    if [ "$done_browser" = 0 ]; then
      chrome=""
      for c in "${CHROME_BIN:-}" google-chrome chromium chromium-browser \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
        [ -z "$c" ] && continue
        if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then chrome="$c"; break; fi
      done
      if [ -z "$chrome" ]; then
        page_skip "no browser: no Playwright install and no Chrome or Chromium found"
      else
        browser="Chrome headless (--dump-dom)"
        for p in index how-it-works pricing skills; do
          log="$tmp/chrome-$p.log"
          dom="$tmp/dom-$p.html"
          "$chrome" --headless --use-mock-keychain --password-store=basic --disable-gpu --no-sandbox --enable-logging=stderr --v=0 \
            --virtual-time-budget=5000 --user-data-dir="$tmp/profile-$p" \
            --dump-dom "$url/$p.html" >"$dom" 2>"$log"
          if ! grep -q '<html' "$dom"; then
            add FAIL "page: $p.html loads (DOM returned)" "no DOM returned"
          else
            add PASS "page: $p.html loads (DOM returned)" "DOM dumped"
          fi
          add SKIPPED "console check: $p.html" "Chrome --dump-dom cannot tell console.error from console.log; needs Playwright"
          add SKIPPED "scroll sweep: $p.html marker in view" "Chrome --dump-dom cannot scroll; needs Playwright"
        done
      fi
    fi
  fi
  kill "$server_pid" 2>/dev/null; wait "$server_pid" 2>/dev/null; server_pid=""
fi

# 3. No tracked file changed
after=$(git status --porcelain)
if [ "$rev" = "unknown" ]; then
  add SKIPPED "no tracked file changed" "git cannot run here (no repository), so the tree state is unknown"
elif [ "$before" = "$after" ]; then
  add PASS "no tracked file changed" "git status --porcelain identical before and after"
else
  add FAIL "no tracked file changed" "git status --porcelain differs"
fi

if [ "$fails" -gt 0 ]; then result="Failed"
elif [ "$skips" -gt 0 ]; then result="Partial: $skips check(s) SKIPPED, not verified"
else result="Passed"; fi

{
  echo "## Verify evidence"
  echo
  echo "- Result: $result"
  echo "- Revision: $rev on ${branch:-detached HEAD}; $dirty uncommitted path(s) at start"
  echo "- Environment: $(uname -s) $(uname -m); node $(node -v 2>/dev/null || echo none); python3 $(python3 -V 2>&1 | cut -d' ' -f2); browser: $browser"
  echo "- Command: bash .claude/skills/verify/verify.sh (working directory: repo root)"
  echo
  echo "| Check | Status | Detail |"
  echo "|---|---|---|"
  cat "$rows"
  echo
  echo "- Cleanup: server stopped, temp directory removed on exit"
  if [ "$skips" -gt 0 ]; then echo "- Unverified: every check marked SKIPPED above"; else echo "- Unverified: none"; fi
}
[ "$fails" -eq 0 ]
