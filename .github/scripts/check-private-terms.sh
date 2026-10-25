#!/usr/bin/env bash
#
# Fail when a tracked file holds a private term (#102).
#
# Usage: check-private-terms.sh [<repo-dir>]
#
# The terms never live in this repository: a committed list of private terms
# would publish them. They come only from secrets, through two environment
# variables:
#
#   PRIVATE_TERMS  newline-separated terms (the PRIVATE_TERMS repo secret).
#                  Empty lines and lines that start with # are ignored.
#   OVERLAY_JSON   the staging overlay (the STAGING_OVERLAY secret). Each
#                  value is a term.
#
# Matching is case-insensitive, on the raw term and its HTML-escaped form,
# in every file that `git ls-files` lists. Binary files are skipped.
#
# When neither variable is set (a fork, a PR from a fork, a local run), the
# check skips with a notice and exits 0. Set REQUIRE_PRIVATE_TERMS=true to
# make a missing secret fail instead; the workflow does this on pushes when
# the repo variable PRIVATE_TERMS_REQUIRED is true, so the check cannot fail
# open where the secret must exist.
#
# Log rules (the repo is public, so the Actions log is public):
#   - Never print a term, the term list, or a matching line.
#   - The only output that carries a term is the `::add-mask::` command,
#     which the runner consumes and does not show.
#   - On a hit, print the file path and the term's index number only
#     (for an overlay value, its token name, which is public).
#   - Never add `set -x` to this script.

set -euo pipefail

repo=${1:-.}

if [ -z "${PRIVATE_TERMS:-}" ] && [ -z "${OVERLAY_JSON:-}" ]; then
  if [ "${REQUIRE_PRIVATE_TERMS:-false}" = "true" ]; then
    echo "::error::check-private-terms: no PRIVATE_TERMS or OVERLAY_JSON secret, and the check is required here."
    exit 1
  fi
  echo "::notice::check-private-terms: no private terms secret in this run (fork, PR preview or local run). Skipped."
  exit 0
fi

# Terms are read from the environment by python, never from a command line.
# -I keeps python from importing anything from the repository.
python3 -I - "$repo" <<'PY'
import html
import json
import os
import subprocess
import sys

repo = sys.argv[1]
def mask(value):
    """Mask a value for the Actions log. ::add-mask:: masks one line per
    call, so each line of a multi-line value is masked on its own, in the
    raw and the HTML-escaped form. A one-line value is masked whole."""
    parts = {value} if "\n" not in value and "\r" not in value else set()
    for line in value.splitlines():
        parts.update({line, line.strip()})
    outs = set()
    for part in parts:
        if part.strip():
            outs.update({part, html.escape(part, quote=True)})
    for out in sorted(outs):
        sys.stdout.write(f"::add-mask::{out}\n")

terms = []  # (label, term)

for line in (os.environ.get("PRIVATE_TERMS") or "").splitlines():
    term = line.strip()
    if term and not term.startswith("#"):
        terms.append((f"term {len(terms) + 1}", term))

raw = os.environ.get("OVERLAY_JSON") or ""
if raw:
    try:
        overlay = json.loads(raw)
    except ValueError:
        print("check-private-terms: OVERLAY_JSON is not valid JSON.", file=sys.stderr)
        sys.exit(2)
    if not isinstance(overlay, dict):
        print("check-private-terms: OVERLAY_JSON must be a JSON object.", file=sys.stderr)
        sys.exit(2)
    for key in sorted(overlay):
        value = overlay[key]
        if isinstance(value, str) and value.strip():
            mask(value)
            terms.append((f"overlay {key}" if key.replace("_", "").isalnum() else f"term {len(terms) + 1}", value.strip()))

if not terms:
    print("check-private-terms: the secret holds no terms.", file=sys.stderr)
    sys.exit(2)

# Mask every term, line by line, before anything else can print.
forms = []
for label, term in terms:
    mask(term)
    forms.append((label, {term.lower(), html.escape(term, quote=True).lower()}))
sys.stdout.flush()

files = subprocess.run(["git", "-C", repo, "ls-files", "-z"], check=True,
                       capture_output=True).stdout.split(b"\0")
hits = 0
checked = 0
for name in files:
    if not name:
        continue
    path = os.path.join(repo, name.decode("utf-8", "replace"))
    if os.path.islink(path) or not os.path.isfile(path):
        continue
    data = open(path, "rb").read()
    if b"\0" in data[:8192]:
        continue  # binary
    checked += 1
    text = data.decode("utf-8", "replace").lower()
    rel = os.path.relpath(path, repo)
    for label, variants in forms:
        if any(v in text for v in variants):
            print(f"HIT    {rel} ({label})")
            hits += 1

print(f"check-private-terms: {len(terms)} term(s), {checked} file(s), {hits} hit(s)")
sys.exit(1 if hits else 0)
PY
