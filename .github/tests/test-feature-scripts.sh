#!/usr/bin/env bash
# ubuntu-latest (shell-tests.yml) includes Node; require it rather than skip CI.
# Check raw previews and every supported feature matrix state, offline.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
command -v node >/dev/null
check_scripts() {
python3 -I - "$1" "$2" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
import re, subprocess, sys
root=Path(sys.argv[1]); count=0
class Scripts(HTMLParser):
    def __init__(self): super().__init__(convert_charrefs=False); self.active=False; self.code=[]; self.scripts=[]
    def handle_starttag(self,tag,attrs):
        if tag=='script':
            a=dict(attrs)
            self.active='src' not in a and a.get('type','').lower() in ('','text/javascript','application/javascript','module')
            self.code=[]
    def handle_data(self,data):
        if self.active: self.code.append(data)
    def handle_endtag(self,tag):
        if tag=='script' and self.active:
            self.scripts.append(''.join(self.code)); self.active=False
for page in sorted(root.rglob('*.html')):
    rel=page.relative_to(root)
    if any(x.startswith('.') for x in rel.parts) or rel.parts[0] in {'docs-site','handbooks','og'}: continue
    parser=Scripts(); parser.feed(page.read_text())
    for n,script in enumerate(parser.scripts,1):
        assert not re.search(r'<!--\s*/?feature',script), (rel,n,'feature marker inside script')
        result=subprocess.run(['node','--check'],input=script,text=True,capture_output=True)
        assert result.returncode==0, f'{rel} script {n}: {result.stderr}'
        # Game copy lookups must resolve in source and every filtered state.
        for on,off in re.findall(r"document.getElementById\('(loop-copy-[^']+-on)'\) \|\| document.getElementById\('(loop-copy-[^']+-off)'\)",script):
            assert f'id="{on}"' in page.read_text() or f'id="{off}"' in page.read_text(), (rel,on,off)
        count+=1
print(f'PASS inline JavaScript: {sys.argv[2]} ({count} scripts)')
PY
}
check_scripts "$root" source
for flags in build,gate,readiness,pricing,cockpit '' build gate readiness pricing cockpit; do
  out="$tmp/out-${flags:-none}"
  "$root/.github/scripts/apply-features.sh" "$root" "$out" "$flags"
  check_scripts "$out" "${flags:-all off}"
done
