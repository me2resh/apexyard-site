#!/usr/bin/env bash
#
# Regression guard for one-command install content behind the
# oneCommandInstall site flag (GH-100).
#
# Asserts:
#   1. site-flags.js defaults oneCommandInstall to false
#   2. index.html contains the three install commands, migrate, and
#      apexyard init, and no telemetry text (owner decision)
#   3. Those strings appear only inside data-flag blocks (flag off
#      leaves the live markup on the fork path)
#   4. Hero install tabs follow the WAI-ARIA tabs pattern
#   5. The old gh repo fork install-row carries data-flag-off
#
# Run locally:  .github/tests/test-install-flag.sh
#
# Lives under .github/ deliberately: deploy syncs exclude ".github/*".

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
flags="$repo_root/site-flags.js"
index="$repo_root/index.html"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "$2"; }

echo "test-install-flag.sh"

[ -f "$flags" ] || { echo "FATAL: $flags missing"; exit 1; }
[ -f "$index" ] || { echo "FATAL: $index missing"; exit 1; }

# --- flag default -----------------------------------------------------------

if grep -q 'oneCommandInstall: false' "$flags"; then
  ok "site-flags.js defaults oneCommandInstall: false"
else
  bad "site-flags.js defaults oneCommandInstall: false" "pattern not found"
fi

# --- required strings present -----------------------------------------------

curl_cmd='curl -fsSL https://apexyard.ai/install | sh'
brew_cmd='brew install me2resh/tap/apexyard'
npx_cmd='npx create-apexyard'

for needle in \
  "$curl_cmd" \
  "$brew_cmd" \
  "$npx_cmd" \
  'apexyard migrate' \
  'apexyard init'
do
  if grep -Fq -- "$needle" "$index"; then
    ok "index.html contains: $needle"
  else
    bad "index.html contains: $needle" "missing"
  fi
done

# The site does not mention telemetry or the install ping (owner decision).
# Check every page and every published text alternate, not only index.html.
tel_hits=$(cd "$repo_root" && grep -Eil -- 'telemetry|install ping' ./*.html ./*.md.gen ./llms*.txt 2>/dev/null || true)
if [ -n "$tel_hits" ]; then
  bad "site pages have no telemetry text" "found in: $(echo "$tel_hits" | tr '\n' ' ')"
else
  ok "site pages have no telemetry text"
fi

# --- strings only inside data-flag blocks -----------------------------------

if python3 - "$index" <<'PY'
import sys
from html.parser import HTMLParser

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    src = f.read()

VOID = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}

NEEDLES = [
    "curl -fsSL https://apexyard.ai/install | sh",
    "brew install me2resh/tap/apexyard",
    "npx create-apexyard",
    "apexyard migrate",
    "apexyard init",
]

class StripFlag(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.depth = 0
        self.out = []

    def handle_starttag(self, tag, attrs):
        attrs_d = dict(attrs)
        enter = attrs_d.get("data-flag") == "one-command-install"
        if self.depth > 0:
            if tag not in VOID:
                self.depth += 1
            return
        if enter:
            if tag not in VOID:
                self.depth = 1
            return
        self.out.append(self.get_starttag_text())

    def handle_startendtag(self, tag, attrs):
        attrs_d = dict(attrs)
        if self.depth > 0:
            return
        if attrs_d.get("data-flag") == "one-command-install":
            return
        self.out.append(self.get_starttag_text())

    def handle_endtag(self, tag):
        if self.depth > 0:
            self.depth -= 1
            return
        self.out.append(f"</{tag}>")

    def handle_data(self, data):
        if self.depth == 0:
            self.out.append(data)

    def handle_entityref(self, name):
        if self.depth == 0:
            self.out.append(f"&{name};")

    def handle_charref(self, name):
        if self.depth == 0:
            self.out.append(f"&#{name};")

    def handle_comment(self, data):
        if self.depth == 0:
            self.out.append(f"<!--{data}-->")

    def handle_decl(self, decl):
        if self.depth == 0:
            self.out.append(f"<!{decl}>")

p = StripFlag()
p.feed(src)
p.close()
remainder = "".join(p.out)
failed = [n for n in NEEDLES if n in remainder]
if failed:
    for n in failed:
        print(f"LEAK\t{n}")
    sys.exit(2)
print("STRIP_OK")
PY
then
  ok "gated commands absent outside data-flag blocks"
else
  bad "gated commands absent outside data-flag blocks" "one or more strings leaked"
fi

# --- CTAs follow the flag ----------------------------------------------------
# Render the visible text for each flag state: flag off hides data-flag
# blocks; flag on hides data-flag-off blocks. With the flag on, no CTA may
# send the visitor to fork; with the flag off, the page keeps the fork CTAs.

cta_view() { # <off|on>
  python3 - "$index" "$1" <<'PY'
import sys
from html.parser import HTMLParser

path, state = sys.argv[1], sys.argv[2]
hide_attr = "data-flag" if state == "off" else "data-flag-off"
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"}

class View(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.hide = 0
        self.skip = 0
        self.out = []
    def handle_starttag(self, tag, attrs):
        if tag in VOID:
            return
        if self.hide:
            self.hide += 1
            return
        if dict(attrs).get(hide_attr) == "one-command-install":
            self.hide = 1
            return
        if tag in ("script", "style"):
            self.skip += 1
    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if self.hide:
            self.hide -= 1
            return
        if tag in ("script", "style") and self.skip:
            self.skip -= 1
    def handle_data(self, data):
        if not self.hide and not self.skip:
            self.out.append(data)

v = View()
v.feed(open(path, encoding="utf-8").read())
print(" ".join("".join(v.out).split()))
PY
}

view_off=$(cta_view off)
view_on=$(cta_view on)
has()  { case "$1" in *"$2"*) return 0;; esac; return 1; }

for needle in 'Quickstart — fork, then /setup' 'Fork it, run /setup, start your first day' 'fork the framework, register your repos'; do
  if has "$view_on" "$needle"; then bad "flag on: no fork CTA: $needle" "still visible"; else ok "flag on: no fork CTA: $needle"; fi
  if has "$view_off" "$needle"; then ok "flag off: fork CTA kept: $needle"; else bad "flag off: fork CTA kept: $needle" "missing"; fi
done
for needle in 'Quickstart — install, then apexyard init' 'Install it, run apexyard init and /setup' 'install the framework, register your repos'; do
  if has "$view_on" "$needle"; then ok "flag on: install CTA shown: $needle"; else bad "flag on: install CTA shown: $needle" "missing"; fi
  if has "$view_off" "$needle"; then bad "flag off: install CTA hidden: $needle" "visible"; else ok "flag off: install CTA hidden: $needle"; fi
done

# --- WAI-ARIA tabs pattern --------------------------------------------------

if python3 - "$index" <<'PY'
import sys
from html.parser import HTMLParser

path = sys.argv[1]
html = open(path, encoding="utf-8").read()

class TabAudit(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.in_root = False
        self.root_depth = 0
        self.tablists = 0
        self.tabs = []
        self.panels = []
        self.errors = []

    def handle_starttag(self, tag, attrs):
        attrs_d = dict(attrs)
        if attrs_d.get("id") == "install-tabs":
            self.in_root = True
            self.root_depth = 1
            return
        if not self.in_root:
            return
        self.root_depth += 1
        role = attrs_d.get("role")
        if role == "tablist":
            self.tablists += 1
            if not attrs_d.get("aria-label"):
                self.errors.append("tablist missing aria-label")
        elif role == "tab":
            self.tabs.append(attrs_d)
        elif role == "tabpanel":
            self.panels.append(attrs_d)

    def handle_endtag(self, tag):
        if not self.in_root:
            return
        self.root_depth -= 1
        if self.root_depth <= 0:
            self.in_root = False

audit = TabAudit()
audit.feed(html)
audit.close()

if audit.tablists != 1:
    audit.errors.append(f"expected 1 role=tablist, got {audit.tablists}")
if len(audit.tabs) != 3:
    audit.errors.append(f"expected 3 role=tab, got {len(audit.tabs)}")
if len(audit.panels) != 3:
    audit.errors.append(f"expected 3 role=tabpanel, got {len(audit.panels)}")

tab_ids = {t.get("id") for t in audit.tabs}
panel_ids = {p.get("id") for p in audit.panels}
controls = {t.get("aria-controls") for t in audit.tabs}
if controls != panel_ids:
    audit.errors.append(f"aria-controls {controls} != panel ids {panel_ids}")
for p in audit.panels:
    if p.get("aria-labelledby") not in tab_ids:
        audit.errors.append(
            f"panel {p.get('id')} aria-labelledby unmatched"
        )

zero = [t for t in audit.tabs if t.get("tabindex") == "0"]
if len(zero) != 1:
    audit.errors.append(f"expected exactly one tabindex=0 tab, got {len(zero)}")

if audit.errors:
    for e in audit.errors:
        print(e)
    sys.exit(2)
print("TAB_OK")
PY
then
  ok "install tabs: tablist, 3 tabs, 3 panels, aria-controls, one tabindex=0"
else
  bad "install tabs a11y pattern" "see python errors above"
fi

# --- old fork install-row carries data-flag-off -----------------------------

if python3 - "$index" <<'PY'
import sys
html = open(sys.argv[1], encoding="utf-8").read()
i = html.find('id="install-block"')
if i < 0:
    print("install-block missing")
    sys.exit(2)
chunk = html[max(0, i - 300):i]
if 'data-flag-off="one-command-install"' not in chunk:
    print("data-flag-off not near install-block")
    sys.exit(2)
print("FLAG_OFF_OK")
PY
then
  ok "install-block row carries data-flag-off"
else
  bad "install-block row carries data-flag-off" "attribute not found near install-block"
fi

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
