#!/usr/bin/env bash
# #210: site-owned /docs text must be ASD-STE100. STE uses a period, a colon
# or a comma; an em dash is never correct (see the "emDash" rule in
# docs-site/lint/docs-lint-rules.json, enforced on generated pages by
# docs-site/scripts/lint-docs.mjs). That lint only reads the generated
# Markdown pages, so it never opens an image file, and it needs a full
# "npm run sync" (network access to the framework tag) to produce them.
#
# This test scans the docs-site *source* files the site owns directly, with
# no build step and no network:
#   - every .astro component and page under docs-site/src (the site writes
#     all of this; no imported text passes through it)
#   - the hand-built architecture SVG diagrams under docs-site/public/img
#   - the site-authored strings in docs-site/content-map.mjs: titles,
#     descriptions, summaries, callout text, "coming" text and a part's own
#     `text` (the text sync-content.mjs writes straight through with no
#     source file), plus the RULE_TITLES page titles.
#
# It does NOT scan content-map.mjs's `source` and `sections` values or the
# `sections: [...]` names next to them: those are pointers that must match a
# heading in the framework repository at the pinned tag exactly, so they can
# hold an em dash that belongs to the framework's own text. Changing one
# would break the sync step (docs-site/scripts/sync-content.mjs), not fix a
# site-owned sentence.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docs="$root/docs-site"
# U+2014, written as an octal escape so this file stays ASCII.
emdash="$(printf '\342\200\224')"

fail=0

report() {
  local file="$1"
  echo "FAIL em dash in $file"
  grep -nF "$emdash" "$file" | sed 's/^/  /'
  fail=1
}

# ---------------------------------------------------------------- components and pages

while IFS= read -r -d '' file; do
  grep -qF "$emdash" "$file" && report "${file#"$root"/}"
done < <(find "$docs/src" -name '*.astro' -print0)

# ---------------------------------------------------------------- architecture diagrams

while IFS= read -r -d '' file; do
  grep -qF "$emdash" "$file" && report "${file#"$root"/}"
done < <(find "$docs/public/img" -type f -name '*.svg' -print0)

# ---------------------------------------------------------------- content-map.mjs site strings
# content-map.mjs has no imports of its own, so this needs no npm install.

site_text_findings="$(node --input-type=module -e "
import { SECTIONS, RULE_TITLES } from '$docs/content-map.mjs';
const emdash = '\u2014';
const bad = [];
const check = (label, value) => {
  if (typeof value === 'string' && value.includes(emdash)) bad.push(label + ': ' + value);
};
for (const section of SECTIONS) {
  check(\`section \${section.id}.summary\`, section.summary);
  for (const group of section.groups) {
    check(\`group \${group.id}.summary\`, group.summary);
    for (const page of group.pages || []) {
      check(\`\${page.slug}.title\`, page.title);
      check(\`\${page.slug}.description\`, page.description);
      if (page.coming) check(\`\${page.slug}.coming.text\`, page.coming.text);
      if (page.figure) check(\`\${page.slug}.figure.alt\`, page.figure.alt);
      for (const c of page.callouts || []) check(\`\${page.slug}.callouts[].text\`, c.text);
      for (const p of page.parts || []) if (p.text !== undefined) check(\`\${page.slug}.parts[].text\`, p.text);
    }
  }
}
for (const [key, title] of Object.entries(RULE_TITLES)) check(\`RULE_TITLES.\${key}\`, title);
console.log(bad.join('\n'));
")"

if [ -n "$site_text_findings" ]; then
  echo "FAIL em dash in docs-site/content-map.mjs site-owned strings:"
  while IFS= read -r line; do printf '  %s\n' "$line"; done <<< "$site_text_findings"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: no em dash in site-owned docs text"
fi
exit "$fail"
