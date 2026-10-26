#!/usr/bin/env bash
#
# Apply the private staging overlay to a copy of the site (#102).
#
# Usage: apply-overlay.sh <src-dir> <out-dir>
#
# The public repo holds placeholder tokens only. Each token wraps a visible
# fallback text:
#
#   <!--{{TEAM_PRICE}}-->Pricing to be announced<!--/{{TEAM_PRICE}}-->
#
# This script copies <src-dir> to <out-dir> and replaces each wrapped token
# in <out-dir> with its value from the overlay. <src-dir> is not changed.
#
# Input: the OVERLAY_JSON environment variable, a flat JSON object of
# TOKEN_NAME -> plain-text value. Only the staging deploy sets it, from the
# STAGING_OVERLAY secret of the `staging` environment.
#
# Log rules (the repo is public, so the Actions log is public):
#   - Never print a value, the JSON, or a changed file.
#   - Emit `::add-mask::` only when GITHUB_ACTIONS=true (CI). The runner
#     consumes those lines and does not show the value. Locally, print
#     token names and counts only; never a value.
#   - Print token names and counts only.
#   - Never add `set -x` to this script.
#
# Fails (non-zero) when the overlay is empty or malformed, when a value holds
# a line break, when a token in the site has no value, or when a value has
# no token in the site.

set -euo pipefail

src=${1:?usage: apply-overlay.sh <src-dir> <out-dir>}
out=${2:?usage: apply-overlay.sh <src-dir> <out-dir>}

if [ -z "${OVERLAY_JSON:-}" ]; then
  echo "apply-overlay: OVERLAY_JSON is empty. Set the STAGING_OVERLAY secret on the staging environment." >&2
  exit 2
fi

mkdir -p "$out"
rsync -a --delete --exclude ".git/" "$src"/ "$out"/

# The value never goes on a command line: python reads it from the
# environment. -I keeps python from importing anything from the site tree.
python3 -I - "$out" <<'PY'
import html
import json
import os
import re
import sys

out = sys.argv[1]
NAME = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
TEXT_SUFFIXES = (".html", ".md.gen", ".txt", ".xml")
HTML_SUFFIXES = (".html", ".xml")
ANY_TOKEN = re.compile(r"\{\{([A-Z][A-Z0-9_]*)\}\}")
# Trees the deploy does not publish. og/templates holds the OG card
# templates, which use their own {{NAME}} slots at render time.
SKIP_DIRS = (".git", ".github", "docs", "og/templates", "og/node_modules")


def fail(msg):
    print(f"apply-overlay: {msg}", file=sys.stderr)
    sys.exit(1)


def mask(value):
    """Mask a value for the Actions log when GITHUB_ACTIONS=true.
    ::add-mask:: masks one line per call, so each line of a multi-line
    value is masked on its own, in the raw and the HTML-escaped form.
    A one-line value is masked whole. Locally, write nothing."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    parts = {value} if "\n" not in value and "\r" not in value else set()
    for line in value.splitlines():
        parts.update({line, line.strip()})
    outs = set()
    for part in parts:
        if part.strip():
            outs.update({part, html.escape(part, quote=True)})
    for out in sorted(outs):
        sys.stdout.write(f"::add-mask::{out}\n")

try:
    overlay = json.loads(os.environ["OVERLAY_JSON"])
except (ValueError, KeyError):
    fail("OVERLAY_JSON is not valid JSON.")
if not isinstance(overlay, dict) or not overlay:
    fail("OVERLAY_JSON must be a non-empty JSON object.")

# Mask every value before anything else can print, including the checks
# below. GitHub masks the whole secret string, but not each value inside
# the JSON, and not the lines of a multi-line value.
for value in overlay.values():
    if isinstance(value, str):
        mask(value)
sys.stdout.flush()

for key, value in overlay.items():
    if not isinstance(key, str) or not NAME.match(key):
        fail("a key is not a valid token name (A-Z, 0-9, _).")
    if not isinstance(value, str) or not value.strip():
        fail(f"the value of {key} must be a non-empty string.")
    if "\n" in value or "\r" in value:
        fail(f"the value of {key} must be one line.")


counts = {key: 0 for key in overlay}
unresolved = set()

for dirpath, dirs, files in os.walk(out):
    rel_dir = os.path.relpath(dirpath, out)
    dirs[:] = [
        d for d in dirs
        if os.path.normpath(os.path.join(rel_dir, d)) not in SKIP_DIRS
    ]
    for name in files:
        if not name.endswith(TEXT_SUFFIXES):
            continue
        path = os.path.join(dirpath, name)
        if os.path.islink(path):
            continue
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        if "{{" not in text:
            continue
        is_html = name.endswith(HTML_SUFFIXES)
        changed = text
        for key, value in overlay.items():
            pattern = re.compile(
                r"<!--\{\{" + key + r"\}\}-->.*?<!--/\{\{" + key + r"\}\}-->", re.S)
            repl = html.escape(value, quote=True) if is_html else value
            changed, n = pattern.subn(lambda _m, r=repl: r, changed)
            counts[key] += n
        for match in ANY_TOKEN.finditer(changed):
            unresolved.add((match.group(1), os.path.relpath(path, out)))
        if changed != text:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(changed)

for key in sorted(counts):
    print(f"apply-overlay: {key} replaced {counts[key]} time(s)")

problems = False
for key, rel in sorted(unresolved):
    print(f"apply-overlay: token {key} has no value (in {rel})", file=sys.stderr)
    problems = True
for key in sorted(k for k, n in counts.items() if n == 0):
    print(f"apply-overlay: overlay key {key} matches no token in the site", file=sys.stderr)
    problems = True
if problems:
    sys.exit(1)
PY
