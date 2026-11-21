#!/usr/bin/env bash
# All-on filtering must preserve source text except feature-off alternatives.
# Optional source tree supports fail-before verification without git refs.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
src="${1:-$root}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
check_content() {
python3 -I - "$1" "$2" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
import sys, re, html, difflib
src,out=map(Path,sys.argv[1:])
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
def without_off_alternatives(text):
    # Track all region kinds so nested alternatives are removed in full,
    # independently of the production filter's feature evaluation.
    stack=[]; parts=[]; last=0
    for marker in re.finditer(r'<!--\s*(/?)feature(-off|-all)?:([^>]*?)\s*-->', text):
        if '-off' not in stack: parts.append(text[last:marker.start()])
        mode=marker[2] or ''
        if marker[1]:
            assert stack and stack.pop()==mode, 'unmatched feature region'
        else: stack.append(mode)
        last=marker.end()
    assert not stack, 'unclosed feature region'
    parts.append(text[last:])
    return ''.join(parts)
files=sorted(p.relative_to(src).as_posix() for p in src.rglob('*') if p.is_file() and not p.is_symlink())
failed=[]; count=0
for name in files:
    p=Path(name)
    if any(x.startswith('.') for x in p.parts): continue
    if p.parts[0] in {'docs','docs-site','handbooks'} or name.startswith('og/'): continue
    if name in {'README.md','AGENTS.md','CLAUDE.md'}: continue
    if p.suffix not in {'.html','.md','.txt','.xml','.json'} and not name.endswith('.md.gen'): continue
    before=without_off_alternatives((src/name).read_text())
    after=(out/name).read_text() if (out/name).exists() else ''
    count+=1
    if normal(before)!=normal(after):
        failed.append(name)
        print('FAIL all-on visible text: '+name)
        for line in list(difflib.unified_diff(normal(before).split(),normal(after).split(),n=3))[:35]: print(line)
assert not failed, 'all-on content changed: '+', '.join(failed)
print(f'PASS all-on visible text: {count} published text files')
PY
}
"$src/.github/scripts/apply-features.sh" "$src" "$tmp/out" build,gate,readiness,pricing,cockpit
check_content "$src" "$tmp/out"

# A broken all-on filter that drops visible source text must be detected.
mkdir -p "$tmp/fixture/.github/scripts"
cp "$root/.github/scripts/apply-features.sh" "$tmp/fixture/.github/scripts/"
cat >> "$tmp/fixture/.github/scripts/apply-features.sh" <<'SH'
printf '%s\n' '<p>Kept</p>' > "$2/index.html"
SH
printf '%s\n' '<p>Kept</p><p data-feature="build">Must survive</p>' > "$tmp/fixture/index.html"
"$tmp/fixture/.github/scripts/apply-features.sh" "$tmp/fixture" "$tmp/broken-out" build,gate,readiness,pricing,cockpit
if check_content "$tmp/fixture" "$tmp/broken-out" > "$tmp/negative.log" 2>&1; then
  echo 'FAIL negative self-test: visible text loss was accepted' >&2
  exit 1
fi
grep -q 'FAIL all-on visible text: index.html' "$tmp/negative.log"
echo 'PASS negative self-test: all-on visible text loss rejected'
