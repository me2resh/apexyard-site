#!/usr/bin/env bash
#
# Guard for #102: every Team claim on a page has one switch in claims.js,
# every switch is 'live' or 'coming', and every claim can show its
# "Coming" tag. A claim with no switch cannot flip on switch-on day.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
cfg = open(os.path.join(root, "claims.js"), encoding="utf-8").read()
switches = dict(re.findall(r"^\s*([a-z_]+):\s*'([a-z]+)'", cfg, re.M))
errors = []
for key, value in switches.items():
    if value not in ("live", "coming"):
        errors.append(f"claims.js: {key} is '{value}', not 'live' or 'coming'")

used = set()
for path in sorted(glob.glob(os.path.join(root, "*.html"))):
    text = open(path, encoding="utf-8").read()
    rel = os.path.basename(path)
    for m in re.finditer(r'<span data-claim="([a-z_]+)">', text):
        key = m.group(1)
        used.add(key)
        if key not in switches:
            errors.append(f"{rel}: claim {key} has no switch in claims.js")
    if 'data-claim="' in text:
        if text.count('data-claim="') != text.count('class="claim-coming" hidden'):
            errors.append(f"{rel}: a claim has no hidden Coming tag")
        if '/claims.js' not in text or text.index('/claims.js') > text.index('/product.js'):
            errors.append(f"{rel}: claims.js must load before product.js")

for key in sorted(set(switches) - used):
    errors.append(f"claims.js: switch {key} matches no claim on any page")

for e in errors:
    print("  FAIL  " + e)
print(f"claims: {len(switches)} switch(es), {len(used)} used, {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
