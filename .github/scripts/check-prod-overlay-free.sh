#!/usr/bin/env bash
#
# Prove that production does not serve any staging overlay value (#102).
#
# Usage: check-prod-overlay-free.sh <site-dir> [<url-path> ...]
#
# Runs in the staging deploy job, the only job that holds the overlay. It
# fetches each production page and fails if any overlay value appears in it,
# raw or HTML-escaped. With no <url-path> arguments it checks every page the
# site serves: each top-level *.html file at its clean URL, each *.md.gen at
# its .md key, llms.txt, and llms-full.txt.
#
# Input: OVERLAY_JSON (the same masked secret apply-overlay.sh reads) and
# PROD_BASE (default https://apexyard.ai). A 404 counts as clean: the page is
# not on production yet. Any other fetch error fails the check, because the
# check cannot prove the page is clean.
#
# Log rules: print the URL path and ok / LEAK / ERROR with the token name.
# Never print a value or a response body. Never add `set -x`.

set -euo pipefail

site=${1:?usage: check-prod-overlay-free.sh <site-dir> [<url-path> ...]}
shift

if [ -z "${OVERLAY_JSON:-}" ]; then
  echo "check-prod-overlay-free: OVERLAY_JSON is empty." >&2
  exit 2
fi

python3 -I - "$site" "$@" <<'PY'
import html
import json
import os
import sys
import urllib.error
import urllib.request

site = sys.argv[1]
paths = sys.argv[2:]
base = os.environ.get("PROD_BASE", "https://apexyard.ai").rstrip("/")
overlay = json.loads(os.environ["OVERLAY_JSON"])

if not paths:
    paths = []
    for name in sorted(os.listdir(site)):
        if name.endswith(".html"):
            stem = name[: -len(".html")]
            paths.append("/" if stem == "index" else f"/{stem}")
        elif name.endswith(".md.gen"):
            paths.append("/" + name[: -len(".gen")])
    for name in ("llms.txt", "llms-full.txt"):
        if os.path.isfile(os.path.join(site, name)):
            paths.append("/" + name)

forms = []
for key, value in overlay.items():
    for form in {value, html.escape(value, quote=True)}:
        forms.append((key, form))

leaks = 0
errors = 0
for path in paths:
    url = base + path
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "apexyard-overlay-check"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            print(f"ok     {path} (404, not on production)")
            continue
        print(f"ERROR  {path} (HTTP {exc.code})")
        errors += 1
        continue
    except (urllib.error.URLError, OSError) as exc:
        print(f"ERROR  {path} ({type(exc).__name__})")
        errors += 1
        continue
    hit = sorted({key for key, form in forms if form in body})
    if hit:
        print(f"LEAK   {path} (token {', '.join(hit)})")
        leaks += 1
    else:
        print(f"ok     {path}")

print(f"checked {len(paths)} path(s): {leaks} leak(s), {errors} error(s)")
sys.exit(1 if leaks or errors else 0)
PY
