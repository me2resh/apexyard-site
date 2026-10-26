#!/usr/bin/env bash
# #107: the ASD-STE100 docs lint (docs-site/scripts/lint-docs.mjs).
# Runs the lint on small fixtures. Needs node, no network, no npm install.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lint="$root/docs-site/scripts/lint-docs.mjs"
rules="$root/docs-site/lint/docs-lint-rules.json"
build="$root/.github/scripts/build-docs.sh"

pass=0
fail=0
assert() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
    echo "  ok    $name"
  else
    fail=$((fail + 1))
    echo "  FAIL  $name"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Non-ASCII test characters, written as octal escapes so this file stays ASCII.
emdash="$(printf '\342\200\224')"
curly="$(printf '\342\200\231')"

# Run the lint from the fixture folder. Print the output, keep the exit code.
run() {
  (cd "$tmp" && node "$lint" "$@" 2>&1)
}
out_has() { grep -qF -- "$2" <<<"$1"; }
out_lacks() { ! grep -qF -- "$2" <<<"$1"; }
code_of() {
  local rc=0
  (cd "$tmp" && node "$lint" "$@" >/dev/null 2>&1) || rc=$?
  echo "$rc"
}

# ---------------------------------------------------------------- file mode

# Line numbers matter: the assertions name them.
cat >"$tmp/a.md" <<EOF
# Title

One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five twenty-six.

1. Run one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty.
2. Run one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen.

The file is written by the hook.
The hook writes the file.
The tool is set up for you. The light is red.
Simply run the command. Do not stop.
You don't need it. You don${curly}t need it.
Use a period ${emdash} not a dash.
Use \`a ${emdash} b\` in code.

\`\`\`
You don't need this code. It is written by hand ${emdash} really.
\`\`\`

| Column | Text |
| --- | --- |
| A | The value is shown here. |
EOF

out="$(run a.md)"
assert "file mode: long description sentence has a finding" out_has "$out" "a.md:3: sentence-length: 26 words (max 25)"
assert "file mode: step over 20 words has a finding"       out_has "$out" "a.md:5: sentence-length-step: 21 words (max 20)"
assert "file mode: step of 20 words has no finding"        out_lacks "$out" "a.md:6:"
assert "file mode: passive voice has a finding"            out_has "$out" 'a.md:8: passive-voice: "is written"'
assert "file mode: active voice has no finding"            out_lacks "$out" "a.md:9:"
assert "file mode: approved phrase and short -ed word pass" out_lacks "$out" "a.md:10:"
assert "file mode: vague word has a finding"               out_has "$out" 'a.md:11: banned-word: vague "Simply"'
assert "file mode: contraction has a finding"              out_has "$out" "a.md:12: banned-word: contraction \"don't\", use: do not"
assert "file mode: curly-apostrophe contraction is found"  bash -c "[ \"\$(grep -c '^a.md:12: banned-word: contraction' <<<\"\$1\")\" -eq 2 ]" _ "$out"
assert "file mode: em dash has a finding"                  out_has "$out" "a.md:13: em-dash:"
assert "file mode: inline code is ignored"                 out_lacks "$out" "a.md:14:"
assert "file mode: code block is ignored"                  bash -c "! grep -qE '^a.md:1[6-8]:' <<<\"\$1\"" _ "$out"
assert "file mode: table cell text is checked"             out_has "$out" 'a.md:22: passive-voice: "is shown"'
assert "summary line counts the findings"                  out_has "$out" "docs-lint: 1 pages, "
assert "file mode: scope is all findings"                  out_has "$out" "in scope (all findings): "
assert "report only: exit 0 with findings"                 test "$(code_of a.md)" = 0
assert "strict: exit 1 with findings"                      test "$(code_of --strict a.md)" = 1

printf '# Clean\n\nThe hook writes the file.\n\n1. Run the command.\n' >"$tmp/clean.md"
assert "strict: exit 0 on a clean file"                    test "$(code_of --strict clean.md)" = 0

# ---------------------------------------------------------------- changed lines

printf 'a.md:9\nclean.md:1-5\n' >"$tmp/changed-none.txt"
printf '# comment\na.md:7-8\n' >"$tmp/changed-hit.txt"
printf 'a.md:x\n' >"$tmp/changed-bad.txt"
out="$(run --changed changed-hit.txt --scope-only a.md)"
assert "changed lines: strict passes when no finding is on a changed line" test "$(code_of --strict --changed changed-none.txt a.md clean.md)" = 0
assert "changed lines: strict fails on a finding in a changed range"       test "$(code_of --strict --changed changed-hit.txt a.md)" = 1
assert "changed lines: scope-only prints only the changed-line finding"    out_has "$out" 'a.md:8: passive-voice'
assert "changed lines: scope-only hides other findings"                    out_lacks "$out" 'a.md:3:'
assert "changed lines: summary names the scope"                            out_has "$out" "in scope (changed lines): 1"
assert "changed lines: a bad entry is a usage error"                       test "$(code_of --changed changed-bad.txt a.md)" = 2

# ---------------------------------------------------------------- rules file

assert "rules: the site file is valid JSON"            node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$rules"
assert "rules: step limit is 20"                       node -e "process.exit(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).sentenceLength.step===20?0:1)" "$rules"
assert "rules: description limit is 25"                node -e "process.exit(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).sentenceLength.description===25?0:1)" "$rules"
assert "rules: em dash rule names U+2014"              node -e "process.exit(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).emDash.characters.includes('—')?0:1)" "$rules"
assert "rules: the file has passive, approved and banned lists" node -e "const r=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(r.passive.irregular.length&&r.approved.terms.length&&r.banned.entries.length?0:1)" "$rules"

node -e "const fs=require('fs');const r=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));r.sentenceLength.description=3;fs.writeFileSync(process.argv[2],JSON.stringify(r))" "$rules" "$tmp/short.json"
out="$(run --rules short.json clean.md)"
assert "rules: --rules reads another rules file"       out_has "$out" "clean.md:3: sentence-length: 5 words (max 3)"
assert "rules: a missing rules file is an error"       test "$(code_of --rules nope.json clean.md)" = 2
echo '{"version":1}' >"$tmp/broken.json"
assert "rules: an incomplete rules file is an error"   test "$(code_of --rules broken.json clean.md)" = 2

# The framework copy in the release cache wins over the site copy.
site="$tmp/site"
mkdir -p "$site/lint" "$site/.cache/apexyard-v9.9.9/docs" "$site/src/generated" "$site/src/content/docs/learn"
cp "$rules" "$site/lint/docs-lint-rules.json"
node -e "const fs=require('fs');const r=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));r.sentenceLength.description=3;fs.writeFileSync(process.argv[2],JSON.stringify(r))" "$rules" "$site/.cache/apexyard-v9.9.9/docs/docs-lint-rules.json"
cat >"$site/content-map.mjs" <<'EOF'
export const SOURCE = { tag: 'v9.9.9' };
export const SECTIONS = [
  {
    id: 'learn',
    title: 'Learn',
    summary: 'Guides that explain the work.',
    groups: [
      {
        id: 'g',
        title: 'Group',
        summary: 'Pages for one task.',
        pages: [
          {
            slug: 'learn/mixed',
            title: 'Mixed',
            description: 'A page with site text and source text.',
            parts: [{ text: 'The audits are run by the agent.\nRelease {tag} has the skills.' }, { source: 'x.md' }],
          },
          {
            slug: 'learn/coming',
            title: 'Coming',
            description: 'A page with no source yet.',
            coming: { text: 'This page is published later.' },
          },
        ],
      },
    ],
  },
];
EOF
cat >"$site/src/generated/nav.json" <<'EOF'
{ "sections": [ { "id": "learn", "groups": [ { "id": "g", "pages": [
  { "slug": "learn/mixed", "sources": ["x.md"] },
  { "slug": "learn/coming", "sources": [] }
] } ] } ] }
EOF
cat >"$site/src/content/docs/learn/mixed.md" <<'EOF'
---
title: "Mixed"
description: "A page with site text and source text."
---

The audits are run by the agent.
Release v9.9.9 has the skills.

## From the source

The report is written by the framework.
EOF
cat >"$site/src/content/docs/learn/coming.md" <<'EOF'
---
title: "Coming"
description: "A page with no source yet."
---

<div class="callout callout--coming" role="note" aria-label="Coming">
<p class="callout__title">Coming</p>

This page is published later.

</div>
EOF

# Run the lint in the page-mode fixture. Print the output. Never fail.
site_out() {
  (
    cd "$site" || exit 0
    node "$lint" --root . "$@" 2>&1
  ) || true
}
# Print the exit code of the lint in the page-mode fixture.
site_code() {
  local rc=0
  (
    cd "$site" || exit 2
    node "$lint" --root . "$@" >/dev/null 2>&1
  ) || rc=$?
  echo "$rc"
}

out="$(site_out)"
assert "rules: the cache copy is used when it exists"  out_has "$out" "rules from .cache/apexyard-v9.9.9/docs/docs-lint-rules.json"
rm "$site/.cache/apexyard-v9.9.9/docs/docs-lint-rules.json"
out="$(site_out)"
assert "rules: the site copy is the fallback"          out_has "$out" "rules from lint/docs-lint-rules.json"

# ---------------------------------------------------------------- page mode

assert "page mode: site-owned line is marked [site]"          out_has "$out" 'learn/mixed:6: passive-voice: "are run" [site]'
assert "page mode: framework line is marked [framework]"      out_has "$out" 'learn/mixed:11: passive-voice: "is written" [framework]'
assert "page mode: a page with no source is all site text"    out_has "$out" 'learn/coming:9: passive-voice: "is published" [site]'
assert "page mode: findings are grouped per page"             out_has "$out" "== learn/mixed: 2 findings, 1 in scope"
assert "page mode: summary counts by owner"                   out_has "$out" "by owner: framework 1, site 2"
assert "page mode: scope is site-owned text"                  out_has "$out" "in scope (site-owned text): 2"
assert "page mode: strict fails on site-owned findings"       test "$(site_code --strict)" = 1

# Fix the site text. Framework findings alone do not fail strict mode.
sed -i.bak 's/The audits are run by the agent\./The agent runs the audits./' "$site/content-map.mjs" "$site/src/content/docs/learn/mixed.md"
sed -i.bak 's/This page is published later\./We publish this page later./' "$site/content-map.mjs" "$site/src/content/docs/learn/coming.md"
assert "page mode: strict passes with framework findings only" test "$(site_code --strict)" = 0
out="$(site_out --scope-only)"
assert "page mode: scope-only hides framework findings"       out_lacks "$out" "[framework]"

# ---------------------------------------------------------------- wiring

assert "build-docs runs the lint"                      grep -q 'npm run lint' "$build"
assert "package.json has lint and lint:strict scripts" node -e "const s=require(process.argv[1]).scripts;process.exit(s.lint&&s['lint:strict']?0:1)" "$root/docs-site/package.json"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
