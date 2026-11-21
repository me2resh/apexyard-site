#!/usr/bin/env bash
# Copy and filter the deploy tree. Empty/missing list means all off.
# data-feature="build pricing" and feature:build pricing regions use ANY:
# keep the element/region if at least one named feature is enabled.
# feature-all requires every listed area; feature-off is its inverse.
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
        values = [value for key, value in attrs if key == 'data-feature']
        if values and (len(values) != 1 or values[0] is None): fail('data-feature requires one value')
        value = values[0] if values else None
        remove = value is not None and not (names(value) & self.enabled)
        start = self.pos()
        if tag in self.void:
            if remove: self.cuts.append((start, start + len(self.get_starttag_text())))
        else:
            self.stack.append((tag, start, remove))
    def handle_startendtag(self, tag, attrs):
        if tag not in self.void | {'path', 'circle', 'line', 'polyline', 'polygon', 'rect', 'ellipse', 'use'} and any(key == 'data-feature' for key, _ in attrs): fail('tagged non-void self-closing element: '+tag)
        values = [value for key, value in attrs if key == 'data-feature']
        if values and (len(values) != 1 or values[0] is None): fail('data-feature requires one value')
        value = values[0] if values else None
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
    for m in re.finditer(r'<!--\s*(/?)feature(-off|-all)?:([^>]*?)\s*-->',text):
        if all(keep for _,keep in stack): output.append(text[last:m.start()])
        value=m[3].strip(); mode=m[2] or ''; required=names(value)
        active=(not required <= enabled) if mode=='-off' else (required <= enabled if mode=='-all' else bool(required & enabled))
        value=mode+':'+value
        if m[1]:
            if not stack or stack[-1][0]!=value: fail('unmatched feature region: '+value)
            stack.pop()
        else: stack.append((value,active))
        last=m.end()
    if stack: fail('unclosed feature region')
    output.append(text[last:])
    return ''.join(output)

SECTION = re.compile(r'<section\b(?=[^>]*\bclass="[^"]*\bsec\b[^"]*")(?=[^>]*\bdata-side="[lr]")[^>]*>')
JOIN = re.compile(r'\s*<div class="join(?: join--rl)?" aria-hidden="true"><i></i><i></i><i></i></div>')
def sides(original, text):
    # The moving line runs down alternating sides, with a join between two
    # sections. A removed section breaks that pattern, so rebuild it from the
    # sections that stay (#202). The first section keeps the side of the
    # first section of the unfiltered page.
    before = SECTION.findall(original)
    matches = list(SECTION.finditer(text))
    if not before or len(matches) == len(before): return text
    side = re.search(r'data-side="([lr])"', before[0])[1]
    plan = []
    for i in range(len(matches)):
        if i: side = 'r' if side == 'l' else 'l'
        plan.append(side)
    for i in range(len(matches) - 1, -1, -1):
        m = matches[i]
        tag = re.sub(r'data-side="[lr]"', 'data-side="' + plan[i] + '"', m.group(0))
        rest = text[m.end():]
        old = JOIN.match(rest)
        join = ''
        if i:
            join = '<div class="join' + (' join--rl' if plan[i] == 'l' else '') + '" aria-hidden="true"><i></i><i></i><i></i></div>'
        text = text[:m.start()] + tag + join + rest[old.end() if old else 0:]
    return text

try:
    src,out=map(lambda s:Path(s).resolve(),sys.argv[1:3])
    enabled=set(filter(None,(s.strip() for s in sys.argv[3].split(','))))
    if enabled-KNOWN: fail('unknown feature name: '+', '.join(sorted(enabled-KNOWN)))
    if src==out or src in out.parents: fail('out-dir must be outside src-dir')
    if out.exists(): fail('out-dir already exists; use a fresh directory')
    shutil.copytree(src,out,ignore=shutil.ignore_patterns('.git','node_modules'),symlinks=True)
    # Source and tooling are not public site assets.
    for directory in ('docs-site', 'handbooks', 'og/templates'):
        shutil.rmtree(out/directory, ignore_errors=True)
    for filename in ('README.md', 'AGENTS.md', 'og/README.md'):
        (out/filename).unlink(missing_ok=True)
    # Never follow source symlinks into files outside the deploy tree.
    for p in list(out.rglob('*')):
        if p.is_symlink(): p.unlink()
    for feature in KNOWN - enabled:
        for suffix in ('.html', '.md.gen', '.md'):
            (out / (feature + suffix)).unlink(missing_ok=True)
    if 'gate' not in enabled:
        for asset in ('check-pr9.webp', 'placeholder-dashboard.svg', 'placeholder-evidence.svg', 'placeholder-org-dashboard.svg'):
            (out/'img'/asset).unlink(missing_ok=True)
    if not {'gate', 'readiness'} <= enabled:
        (out/'og/architecture.png').unlink(missing_ok=True)
    for p in list(out.rglob('*')):
        if not p.is_file() or any(part.startswith('.') for part in p.relative_to(out).parts): continue
        if p.suffix not in {'.html','.txt','.xml','.md'} and not p.name.endswith('.md.gen'): continue
        text=p.read_text()
        if p.suffix=='.html':
            body=re.search(r'<body\b[^>]*data-feature="([^"]+)"',text)
            if body and not names(body[1])&enabled: p.unlink(); continue
        text=regions(text,enabled)
        if p.suffix=='.html':
            original=text
            text=sides(original,Filter(text,enabled).result())
        if p.name in {'llms.txt', 'llms-full.txt'}: text=re.sub(r'\n(?:[ \t]*\n){2,}', '\n\n', text)
        p.write_text(text)
    print('apply-features: enabled '+(','.join(sorted(enabled)) or '(none)'))
except (ValueError,OSError) as error:
    print('apply-features: '+str(error),file=sys.stderr)
    sys.exit(1)
PY
