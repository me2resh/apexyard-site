#!/usr/bin/env bash
#
# Fail when a tracked file holds a private term (#102).
#
# Usage: check-private-terms.sh [<repo-dir>]
#        check-private-terms.sh --text-dir <dir>
#
# Text mode (--text-dir): check every file in <dir> instead of the tracked
# files. Each file is one field of a pull request (title, body, commit-<sha>).
# A hit prints the field name and the term's index number only. The PR text
# job and the local git hooks use this mode, so they share the term loading
# and the masking below.
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
#   - Emit `::add-mask::` only when GITHUB_ACTIONS=true (CI). The runner
#     consumes those lines and does not show the value. Locally, print
#     counts and file names only; never a term or value.
#   - On a hit, print the file path and the term's index number only
#     (for an overlay value, its token name, which is public).
#   - Never add `set -x` to this script.

set -euo pipefail

mode=repo
repo=${1:-.}
if [ "${1:-}" = "--text-dir" ]; then
  mode=text
  repo=${2:?check-private-terms: --text-dir needs a directory}
fi

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
python3 -I - "$repo" "$mode" <<'PY'
import html
import json
import os
import subprocess
import sys

repo = sys.argv[1]
mode = sys.argv[2]
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

if mode == "text":
    hits = 0
    checked = 0
    for name in sorted(os.listdir(repo)):
        path = os.path.join(repo, name)
        if not os.path.isfile(path):
            continue
        checked += 1
        text = open(path, "rb").read().decode("utf-8", "replace").lower()
        for label, variants in forms:
            if any(v in text for v in variants):
                print(f"HIT    {name} ({label})")
                hits += 1
    print(f"check-private-terms: {len(terms)} term(s), {checked} field(s), {hits} hit(s)")
    sys.exit(1 if hits else 0)

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
