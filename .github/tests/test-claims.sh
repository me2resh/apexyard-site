#!/usr/bin/env bash
#
# Guard for #102 and #160: claim switches use live or coming, every page claim
# has a switch, and every switch is used. Load claims.js before product.js.
# Root pages must not render Coming labels or carry the old label classes.
# Each claim carries one label (APEXYARD_LABELS in claims.js). A live claim
# reads Available now or Early teams (by hand). A coming claim reads
# Planned, Planned for <date>, or Preview. Each page label equals that text.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
cfg = open(os.path.join(root, "claims.js"), encoding="utf-8").read()
switches = dict(re.findall(r"^\s*([a-z_]+):\s*'([^']*)'", cfg.split("window.APEXYARD_LABELS")[0], re.M))
errors = []
if not switches:
    errors.append("claims.js: no switches found")
for key, value in switches.items():
    if value not in ("live", "coming"):
        errors.append(f"claims.js: {key} is '{value}', not 'live' or 'coming'")

labels_src = cfg.split("window.APEXYARD_LABELS", 1)[1] if "window.APEXYARD_LABELS" in cfg else ""
labels = dict(re.findall(r"^\s*([a-z_]+):\s*'([^']*)'", labels_src, re.M))
if not labels:
    errors.append("claims.js: no APEXYARD_LABELS found")
DATE = r"\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) 20\d\d"
for key, value in switches.items():
    label = labels.get(key)
    if label is None:
        errors.append(f"claims.js: {key} has no label")
    elif value == "live" and label not in ("Available now", "Early teams (by hand)"):
        errors.append(f"claims.js: live claim {key} has label '{label}'")
    elif value == "coming" and not re.fullmatch(r"Planned(?: for " + DATE + r")?|Preview", label):
        errors.append(f"claims.js: coming claim {key} has label '{label}'")
for key in sorted(set(labels) - set(switches)):
    errors.append(f"claims.js: label {key} has no switch")

CAP = re.compile(r'<span class="cap cap--(now|hand|planned|preview)" data-cap="([^"]+)">(.*?)</span>', re.S)
# The "by hand" label is an overlay token (HAND_LABEL) with a plain fallback.
# The text of the fallback is the label that claims.js holds.
TOKEN = re.compile(r"<!--\{\{HAND_LABEL\}\}-->(.*?)<!--/\{\{HAND_LABEL\}\}-->", re.S)
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
    caps = CAP.findall(text)
    cap_keys = set()
    for kind, key, shown in caps:
        shown = TOKEN.sub(lambda m: m.group(1), shown)
        cap_keys.add(key)
        want = "Available now" if key == "available-now" else labels.get(key)
        if want is None:
            errors.append(f"{rel}: label for unknown claim {key}")
            continue
        if shown != want:
            errors.append(f"{rel}: label for {key} reads '{shown}', claims.js says '{want}'")
        want_kind = "now" if want == "Available now" else "preview" if want == "Preview" else "planned" if want.startswith("Planned") else "hand"
        if kind != want_kind:
            errors.append(f"{rel}: label for {key} uses cap--{kind}, expected cap--{want_kind}")
    if text.count('data-cap="') != len(caps):
        errors.append(f"{rel}: a data-cap label does not match the label markup")
    for key in sorted(set(keys) - cap_keys):
        errors.append(f"{rel}: claim {key} has no label on the page")
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
