#!/usr/bin/env bash
#
# #194. No public page shows the word "Placeholder".
#
#   1. No published file holds the word, in any case. The check reads the
#      root pages, the apexdock pages, the Markdown alternates, the llms
#      files, the images and the docs sources. A file name such as
#      img/placeholder-x.svg and an input placeholder="..." attribute do not
#      count: the word must not be followed by "-", "_" or "=".
#   2. An owner fact (data-owner-fact) stays hidden until it holds a value.
#      To show one, write the value into its data-owner-value element and
#      remove the hidden attribute.
#   3. When docs-site/dist exists (a local docs build), the built docs pages
#      are checked too. The reference pages copy framework docs that explain
#      template placeholders in lower case, so a built page fails only on the
#      capitalised word in its visible text.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
WORD = re.compile(r"\bplaceholder\b(?![-_=])", re.I)
BUILT_WORD = re.compile(r"\bPlaceholder\b(?![-_=])")

patterns = [
    "*.html", "*.md.gen", "llms.txt", "llms-full.txt", "skill.md",
    "apexdock/**/*.html", "img/**/*.svg",
    "docs-site/content-map.mjs", "docs-site/src/**/*.astro",
    "docs-site/public/**/*.svg", "docs-site/dist/**/*.html",
]
files = set()
for pattern in patterns:
    files.update(glob.glob(os.path.join(root, pattern), recursive=True))

errors = []
checked = 0
for path in sorted(files):
    rel = os.path.relpath(path, root)
    try:
        text = open(path, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue
    checked += 1
    rule = WORD
    if "/docs-site/dist/" in path:
        text = re.sub(r"<[^>]*>", " ", text)
        rule = BUILT_WORD
    for m in rule.finditer(text):
        line = text.count("\n", 0, m.start()) + 1
        errors.append(f"{rel}:{line}: shows the word '{m.group(0)}'")

# Owner facts: hidden, or shown with a value.
# The value element sits inside the fact, within the next 400 characters.
FACT = re.compile(r"<\w+\b([^>]*\bdata-owner-fact=\"([^\"]+)\"[^>]*)>")
VALUE = re.compile(r"<(\w+)\b[^>]*\bdata-owner-value\b[^>]*>(.*?)</\1>", re.S)
facts = 0
for path in sorted(files):
    if not path.endswith((".html", ".astro")) or "/dist/" in path:
        continue
    rel = os.path.relpath(path, root)
    text = open(path, encoding="utf-8").read()
    for m in FACT.finditer(text):
        facts += 1
        hidden = re.search(r"\shidden(?:[\s=>]|$)", m.group(1)) is not None
        value = VALUE.search(text, m.end(), m.end() + 400)
        filled = value is not None and re.sub(r"<[^>]*>", "", value.group(2)).strip() != ""
        if not hidden and not filled:
            errors.append(f"{rel}: owner fact {m.group(2)} is shown without a value")

if checked < 20:
    errors.append(f"only {checked} files checked")
if facts == 0:
    errors.append("no owner fact found")

# Self-test of the word rule.
for sample, want in (("Placeholder", True), ("Screenshot placeholder: x", True),
                     ("img/placeholder-check.svg", False), ('placeholder="Search"', False),
                     ("placeholders", False)):
    if bool(WORD.search(sample)) != want:
        errors.append(f"word rule self-test failed on {sample!r}")

for e in errors:
    print("  FAIL  " + e)
print(f"no-placeholder: {checked} file(s), {facts} owner fact(s), {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
