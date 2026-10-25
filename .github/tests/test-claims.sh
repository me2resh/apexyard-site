#!/usr/bin/env bash
#
# Guard for #102: claim switches use live or coming, every page claim has
# a switch, and every switch is used. Load claims.js before product.js.
# Root pages must not render Coming labels or carry the old label classes.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
cfg = open(os.path.join(root, "claims.js"), encoding="utf-8").read()
switches = dict(re.findall(r"^\s*([a-z_]+):\s*'([^']*)'", cfg, re.M))
errors = []
if not switches:
    errors.append("claims.js: no switches found")
for key, value in switches.items():
    if value not in ("live", "coming"):
        errors.append(f"claims.js: {key} is '{value}', not 'live' or 'coming'")

used = set()
for path in sorted(glob.glob(os.path.join(root, "*.html"))):
    rel = os.path.basename(path)
    if rel == "game.html":
        continue
    text = open(path, encoding="utf-8").read()
    keys = re.findall(r'\bdata-claim\s*=\s*[\"\']([^\"\']+)[\"\']', text)
    for key in keys:
        used.add(key)
        if key not in switches:
            errors.append(f"{rel}: claim {key} has no switch in claims.js")
    if keys:
        scripts = re.findall(r'<script\b[^>]*\bsrc=[\"\']([^\"\']+)[\"\']', text)
        if '/claims.js' not in scripts or '/product.js' not in scripts or scripts.index('/claims.js') > scripts.index('/product.js'):
            errors.append(f"{rel}: claims.js must load before product.js")
    for marker in ("claim-coming", "is-coming"):
        if marker in text:
            errors.append(f"{rel}: obsolete {marker} marker")
    if re.search(r'>\s*Coming\s*<', text):
        errors.append(f"{rel}: visible Coming label")

for key in sorted(set(switches) - used):
    errors.append(f"claims.js: switch {key} matches no claim on any page")

for e in errors:
    print("  FAIL  " + e)
print(f"claims: {len(switches)} switch(es), {len(used)} used, {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
