#!/usr/bin/env bash
# Copy and filter the deploy tree. Empty/missing list means all off.
# data-feature="build pricing" and feature:build pricing regions use ANY:
# keep the element/region if at least one named feature is enabled.
# Nested regions/elements also require every ancestor to be kept.
set -euo pipefail
python3 -I - "${1:?usage: apply-features.sh <src-dir> <out-dir> [comma-list]}" "${2:?out-dir required}" "${3:-}" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
import re
import shutil
import sys

KNOWN = set('build gate readiness pricing cockpit'.split())
def fail(message):
    raise ValueError(message)
def names(value):
    result = set(value.split())
    if not result or result - KNOWN:
        fail('unknown feature name: ' + value)
    return result

class Filter(HTMLParser):
    void = set('area base br col embed hr img input link meta param source track wbr'.split())
    def __init__(self, text, enabled):
        super().__init__(convert_charrefs=False)
        self.text, self.enabled, self.stack, self.cuts = text, enabled, [], []
        self.lines = [0]
        for m in re.finditer('\n', text): self.lines.append(m.end())
    def pos(self):
        line, col = self.getpos()
        return self.lines[line-1] + col
    def handle_starttag(self, tag, attrs):
        value = dict(attrs).get('data-feature')
        remove = value is not None and not (names(value) & self.enabled)
        start = self.pos()
        if tag in self.void:
            if remove: self.cuts.append((start, start + len(self.get_starttag_text())))
        else:
            self.stack.append((tag, start, remove))
    def handle_startendtag(self, tag, attrs):
        value = dict(attrs).get('data-feature')
        if value is not None and not names(value) & self.enabled:
            self.cuts.append((self.pos(), self.pos()+len(self.get_starttag_text())))
    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, -1, -1):
            if self.stack[i][0] == tag:
                for _, start, remove in self.stack[i:]:
                    if remove: self.cuts.append((start, self.text.find('>',self.pos())+1))
                del self.stack[i:]
                break
    def result(self):
        self.feed(self.text)
        for _, start, remove in self.stack:
            if remove: self.cuts.append((start,len(self.text)))
        merged=[]
        for start,end in sorted(self.cuts):
            if merged and start <= merged[-1][1]: merged[-1]=(merged[-1][0],max(end,merged[-1][1]))
            else: merged.append((start,end))
        result=self.text
        for start,end in reversed(merged): result=result[:start]+result[end:]
        return result

def regions(text, enabled):
    stack=[]; output=[]; last=0
    for m in re.finditer(r'<!--\s*(/?)feature:([a-z ]+)\s*-->',text):
        if all(keep for _,keep in stack): output.append(text[last:m.start()])
        value=m[2].strip(); active=bool(names(value)&enabled)
        if m[1]:
            if not stack or stack[-1][0]!=value: fail('unmatched feature region: '+value)
            stack.pop()
        else: stack.append((value,active))
        last=m.end()
    if stack: fail('unclosed feature region')
    output.append(text[last:])
    return ''.join(output)

try:
    src,out=map(lambda s:Path(s).resolve(),sys.argv[1:3])
    enabled=set(filter(None,(s.strip() for s in sys.argv[3].split(','))))
    if enabled-KNOWN: fail('unknown feature name: '+', '.join(sorted(enabled-KNOWN)))
    if src==out or src in out.parents: fail('out-dir must be outside src-dir')
    if out.exists(): fail('out-dir already exists; use a fresh directory')
    shutil.copytree(src,out,ignore=shutil.ignore_patterns('.git','node_modules'),symlinks=True)
    # Never follow source symlinks into files outside the deploy tree.
    for p in list(out.rglob('*')):
        if p.is_symlink(): p.unlink()
    for feature in KNOWN - enabled:
        for suffix in ('.html', '.md.gen', '.md'):
            (out / (feature + suffix)).unlink(missing_ok=True)
    for p in list(out.rglob('*')):
        if not p.is_file() or any(part.startswith('.') for part in p.relative_to(out).parts): continue
        if p.suffix not in {'.html','.txt','.xml','.md'} and not p.name.endswith('.md.gen'): continue
        text=p.read_text()
        if p.suffix=='.html':
            body=re.search(r'<body\b[^>]*data-feature="([^"]+)"',text)
            if body and not names(body[1])&enabled: p.unlink(); continue
        text=regions(text,enabled)
        if p.suffix=='.html': text=Filter(text,enabled).result()
        p.write_text(text)
    print('apply-features: enabled '+(','.join(sorted(enabled)) or '(none)'))
except (ValueError,OSError) as error:
    print('apply-features: '+str(error),file=sys.stderr)
    sys.exit(1)
PY
