#!/usr/bin/env bash
#
# Guard for #102 and #160: claim switches use live or coming, every page claim
# has a switch, and every switch is used. Load claims.js before product.js.
# Root pages must not render Coming labels or carry the old label classes.
# Each claim carries one label (APEXYARD_LABELS in claims.js). A live claim
# reads Available now or Early teams (by hand). A coming claim reads
# Planned, Planned for <date>, or Preview. Each page label equals that text.
# #192: a tied sentence is true only while its claim is live. The TIED list
# below fails the test when a public text holds such a sentence too early.
# #70: each figure in the home proof block is a primitive count or equals a
# row of .github/evidence/proof-use.tsv. index.md.gen says the same.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

python3 - "$root" <<'PY'
import glob, html, os, re, sys

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

CAP = re.compile(r'<span class="state state--(now|hand|planned|preview)" data-cap="([^"]+)">(.*?)</span>', re.S)
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
            errors.append(f"{rel}: label for {key} uses state--{kind}, expected state--{want_kind}")
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

# #192: tied sentences. Each sentence is true only while its claim in
# claims.js is live. The test fails when a public text holds a tied
# sentence and its claim is not live. A key of None means that no claim
# makes the sentence true, so the sentence fails on every page.
TIED = [
    ("An agent never gives that approval", None),
    ("An agent never gives the final sign-off", None),
    ("Every merge leaves a record", "evidence_export"),
    ("Free for one person", "free_checks"),
    ("to the knowledge base", "kb_mcp"),
]
for sentence, key in TIED:
    if key is not None and key not in switches:
        errors.append(f"test-claims.sh: tied sentence '{sentence}' names unknown claim {key}")

def public_texts():
    names = sorted(glob.glob(os.path.join(root, "*.html")))
    names += sorted(glob.glob(os.path.join(root, "*.md.gen")))
    names += sorted(glob.glob(os.path.join(root, "apexdock", "**", "*.html"), recursive=True))
    names += [os.path.join(root, n) for n in ("llms.txt", "llms-full.txt", "skill.md",
                                             "creator-brief.md", "docs-site/content-map.mjs")]
    for path in names:
        if os.path.basename(path) == "game.html" or not os.path.isfile(path):
            continue
        yield path

def plain(text):
    text = re.sub(r"<[^>]*>", " ", text)
    return re.sub(r"\s+", " ", html.unescape(text)).casefold()

tied_seen = 0
for path in public_texts():
    rel = os.path.relpath(path, root)
    text = plain(open(path, encoding="utf-8").read())
    for sentence, key in TIED:
        if key is not None and switches.get(key) == "live":
            continue
        if sentence.casefold() in text:
            state = "no claim" if key is None else f"{key} is {switches.get(key)}"
            errors.append(f"{rel}: tied sentence '{sentence}' appears, but {state}")
    tied_seen += 1
if tied_seen == 0:
    errors.append("tied sentences: no public text found")

# #70: every figure in the proof block of index.html has a checked-in source.
# The first list holds primitive counts. verify-counts.sh derives them from a
# framework tag, so each figure there must name a primitive noun.
# The "use" list holds the figures from ApexYard building itself. Each one
# must equal a row of .github/evidence/proof-use.tsv, which gives the pinned
# recipe for the figure. index.md.gen must say the same.
PRIMITIVE_NOUNS = ("skills", "hooks", "agents", "roles", "rules")
MONTHS = ("January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December")

def flat(text):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", " ", text))).strip()

ev_rel = ".github/evidence/proof-use.tsv"
ev_meta, ev_figs = {}, []
try:
    ev_lines = open(os.path.join(root, ev_rel), encoding="utf-8").read().splitlines()
except OSError:
    ev_lines = []
    errors.append(f"{ev_rel}: missing")
for n, line in enumerate(ev_lines, 1):
    if not line.strip() or line.startswith("#"):
        continue
    cols = line.split("\t")
    if cols[0] == "figure":
        if len(cols) != 4 or not re.fullmatch(r"[1-9][0-9]*", cols[1]) or not cols[2] or not cols[3]:
            errors.append(f"{ev_rel}:{n}: a figure row needs a figure, a label and a recipe")
            continue
        ev_figs.append((cols[1], cols[2], cols[3], n))
    elif len(cols) == 2:
        ev_meta[cols[0]] = cols[1]
    else:
        errors.append(f"{ev_rel}:{n}: unknown row")
counted_on = ev_meta.get("counted_on", "")
cutoff = ev_meta.get("cutoff", "")
dev_commit = ev_meta.get("dev_commit", "")
date_m = re.fullmatch(r"(20\d\d)-(\d\d)-(\d\d)", counted_on)
if not date_m or not 1 <= int(date_m.group(2)) <= 12:
    errors.append(f"{ev_rel}: counted_on '{counted_on}' is not a date")
    counted_text = None
else:
    counted_text = f"{int(date_m.group(3))} {MONTHS[int(date_m.group(2)) - 1]} {date_m.group(1)}"
if not re.fullmatch(r"20\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ", cutoff):
    errors.append(f"{ev_rel}: cutoff '{cutoff}' is not a UTC time")
if not re.fullmatch(r"[0-9a-f]{40}", dev_commit):
    errors.append(f"{ev_rel}: dev_commit '{dev_commit}' is not a full commit id")
if not ev_figs:
    errors.append(f"{ev_rel}: no figure rows")
for fig, label, recipe, n in ev_figs:
    if (not cutoff or cutoff not in recipe) and (not dev_commit or dev_commit not in recipe):
        errors.append(f"{ev_rel}:{n}: the recipe for {fig} is not pinned to the cutoff or to dev_commit")

idx = open(os.path.join(root, "index.html"), encoding="utf-8").read()
block_m = re.search(r'<section class="proof\b.*?</section>', idx, re.S)
if not block_m:
    errors.append("index.html: no proof block")
else:
    block = block_m.group(0)
    lists = re.findall(r'<ul class="proof__metrics( proof__metrics--use)?"[^>]*>(.*?)</ul>', block, re.S)
    seen_figs, prim, use = 0, [], []
    for is_use, body in lists:
        for item in re.findall(r"<li>(.*?)</li>", body, re.S):
            fm = re.search(r'<strong class="proof__figure">([^<]*)</strong>(.*)', item, re.S)
            if not fm:
                continue
            seen_figs += 1
            fig, label = fm.group(1).strip(), flat(fm.group(2))
            (use if is_use else prim).append((fig, label))
    if seen_figs != block.count('class="proof__figure"'):
        errors.append("index.html: a proof figure is outside the two proof lists")
    for fig, noun in prim:
        if not re.fullmatch(r"[1-9][0-9]*", fig) or noun not in PRIMITIVE_NOUNS:
            errors.append(f"index.html: proof figure '{fig} {noun}' is not a primitive count that verify-counts.sh derives")
    want = [(fig, label) for fig, label, _, _ in ev_figs]
    if use != want:
        errors.append(f"index.html: proof figures {use} differ from {ev_rel} {want}")
    if counted_text and f"Counted on {counted_text} " not in flat(block):
        errors.append(f"index.html: the proof block does not say 'Counted on {counted_text}'")

    md = open(os.path.join(root, "index.md.gen"), encoding="utf-8").read()
    for fig, noun in prim:
        if not re.search(r"\b" + re.escape(fig) + r" " + re.escape(noun) + r"\b", md):
            errors.append(f"index.md.gen: does not say '{fig} {noun}' as index.html does")
    md_use = re.findall(r"^- ([0-9]+) (.+?): <https://github\.com/me2resh/apexyard/", md, re.M)
    if md_use != want:
        errors.append(f"index.md.gen: proof figures {md_use} differ from {ev_rel} {want}")
    if counted_text and f"counted on {counted_text} " not in md:
        errors.append(f"index.md.gen: does not say 'counted on {counted_text}'")

for e in errors:
    print("  FAIL  " + e)
print(f"claims: {len(switches)} switch(es), {len(used)} used, {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
