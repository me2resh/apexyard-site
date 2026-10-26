# docs-site

The `/docs` section of the site. Astro Starlight builds it from `me2resh/apexyard` at the tag pinned in `content-map.mjs`. See `docs/agdr/AgDR-0006-docs-sub-build.md`.

## Commands

```bash
cd docs-site
npm ci
npm run build      # sync the source, build, clean links
npm run check      # page counts, links, exclusions, page parts, contrast
npm run preview    # http://127.0.0.1:4321/docs with the site root mounted
npm run lint       # ASD-STE100 lint, report only
npm run lint:strict  # fail on findings in site-owned text
```

## The docs lint

`scripts/lint-docs.mjs` checks the pages against ASD-STE100. Run it after `npm run sync`. All rules are in one data file, `lint/docs-lint-rules.json`:

- Sentence length: at most 20 words in a procedure step (a numbered list item), at most 25 words in other text.
- Passive voice: a form of "be", then up to one adverb, then a past participle. This is a heuristic. It misses passives without "be". It can flag an adjective that ends in -ed.
- Banned words: idioms, vague words and contractions, each with a word to use.
- The em dash.
- Approved phrases: a banned or passive match inside one of these is not a finding.

The framework repository hosts a copy of the rules file at `docs/docs-lint-rules.json`. When the release cache has that copy, the lint uses it. Else it uses the copy in this folder. Use `--rules FILE` to choose a file.

Each finding is one line: `<page>:<line>: <rule>: <detail> [site|framework]`. The line number is in `src/content/docs/<page>.md`. The lint ignores code blocks, inline code, HTML lines and URLs.

Modes:

- No file arguments: lint the generated pages. Strict mode fails on findings in site-owned text only. Site-owned text is each line that matches a string in `content-map.mjs`.
- File arguments: lint those Markdown files. Strict mode fails on all findings.
- `--changed FILE`: a list of `path:line` or `path:start-end` entries. Only findings on those lines are in scope. Strict mode fails on those findings only.
- `--scope-only` prints only the findings in scope. `--summary` prints the counts only.

The build runs the lint in report-only mode. The lint exits 0 and prints a summary count.

- Set `APEXYARD_REPO=/path/to/apexyard` to read the tag from a local clone instead of GitHub.
- Set `DOCS_PRIVATE_TERMS=/path/outside/repo.txt` to add private names to the exclusion check. Keep that file out of this repository.

## Update to a new framework release

1. Change `SOURCE.tag` and `SOURCE.commit` in `content-map.mjs`.
2. Run `npm run build` and `npm run check`.
3. Fix each mapped heading that the build reports as missing.
