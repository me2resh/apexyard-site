#!/usr/bin/env bash
# Compare every published text asset against the local pre-feature staging ref.
# Optional source tree supports fail-before verification without network access.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
src="${1:-$root}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$src/.github/scripts/apply-features.sh" "$src" "$tmp/out" build,gate,readiness,pricing,cockpit
python3 -I - "$root" "$tmp/out" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
import subprocess, sys, re, html, difflib
repo,out=map(Path,sys.argv[1:])
class Text(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.parts=[]
    def handle_data(self,data): self.parts.append(data)
def normal(text):
    # Comments/feature markers and HTML wrappers have no visible text. Keep
    # script data as well: game copy is rendered from JavaScript strings.
    text=re.sub(r'<!--.*?-->', '', text, flags=re.S)
    parser=Text(); parser.feed(text)
    return ' '.join(html.unescape(''.join(parser.parts)).split())
files=subprocess.check_output(['git','ls-tree','-r','--name-only','origin/staging'],cwd=repo,text=True).splitlines()
failed=[]; count=0
for name in files:
    p=Path(name)
    if any(x.startswith('.') for x in p.parts): continue
    if p.parts[0] in {'docs','docs-site','handbooks'} or name.startswith('og/'): continue
    if name in {'README.md','AGENTS.md','CLAUDE.md'}: continue
    if p.suffix not in {'.html','.md','.txt','.xml','.json'} and not name.endswith('.md.gen'): continue
    before=subprocess.check_output(['git','show','origin/staging:'+name],cwd=repo,text=True)
    after=(out/name).read_text() if (out/name).exists() else ''
    count+=1
    if normal(before)!=normal(after):
        failed.append(name)
        print('FAIL staging visible text: '+name)
        for line in list(difflib.unified_diff(normal(before).split(),normal(after).split(),n=3))[:35]: print(line)
assert not failed, 'staging content changed: '+', '.join(failed)
print(f'PASS staging visible text: {count} published text files')
PY
