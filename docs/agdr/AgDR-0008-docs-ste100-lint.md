# AgDR-0008: Lint the docs for ASD-STE100 in CI

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-107, AgDR-0006 (docs sub-build), me2resh/apexyard#1898

> In the context of the /docs section, facing an owner request to write the docs in ASD-STE100, I decided to add a docs lint to the docs build that reports each finding and exits 0 by default, with a strict mode for site-owned text and for changed lines, to achieve a repeatable STE100 check, accepting that the build reports about 6,520 findings in framework text until the framework rewrite is complete.

## Context

- The docs build reads most page text from the framework release. The site owns about 0.6 % of the words: titles, descriptions, Coming pages, readiness leads and callouts.
- The owner decided that the framework repository rewrites its own text at the source (me2resh/apexyard#1898). The framework CI will lint its own Markdown files with the same rules.
- A lint that fails on framework text would break each docs build until that rewrite is complete.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| No lint. Review the text by hand. | No new code. No CI time. | The check is not repeatable. A reviewer can miss a rule. |
| A third-party prose linter | Many rules are ready. It has a community. | A new tool and its configuration in CI. Its rules are not STE100. The framework repository must install the same tool. It cannot tell site-owned text from framework text. |
| This lint: one Node script and one rules data file | No new dependency. The rules are STE100 rules. It knows which text the site owns. The framework can use the same rules file. | We own the code. The passive-voice check is a heuristic. |

## Decision

Chosen: **this lint**, because it needs no new dependency, it checks only STE100 rules, and it can tell site-owned text from framework text.

1. `docs-site/scripts/lint-docs.mjs` checks sentence length: 20 words in a procedure step, 25 words in other text. It also checks passive voice, banned words (idioms, vague words, contractions) and the em dash. Each finding gives the page, the line and the rule.
2. All rules are in one data file. The lint reads the rules file in this order:
   1. the file that `--rules` names;
   2. the framework copy in the release cache, `.cache/apexyard-<tag>/docs/docs-lint-rules.json`, when it exists;
   3. the site copy, `docs-site/lint/docs-lint-rules.json`.
   One file keeps the site lint and the framework lint on the same rules. When a framework release includes the file, the site uses it with no change here.
3. `build-docs.sh` runs the lint in report-only mode. The lint prints each finding and a summary count, then exits 0.
4. `--strict` exits 1 on findings in scope. In page mode, the scope is site-owned text. A line is site-owned when it matches a string in `content-map.mjs`, or when its page has no framework source.
5. `--changed FILE` limits the scope to a list of `path:line` or `path:start-end` entries. The framework CI can use this mode on the lines that a PR changes.
6. `.github/tests/test-docs-lint.sh` tests the lint on fixtures. `shell-tests.yml` runs it when the lint files change.

### Limits of the passive-voice check

The check finds a form of "be", then up to one adverb, then a past participle. A participle is a word that ends in "-ed", or a word from a list of irregular participles.

- It misses a passive without "be", for example "get" passives and reduced clauses.
- It can flag an adjective that ends in "-ed", for example "is interested".
- It cannot tell "is read" (passive) from other uses of the same words.
- The approved list in the rules file removes known false findings, for example "set up".

## Consequences

- The build log shows about 6,520 report-only findings in framework text. This number goes down when the framework rewrite (me2resh/apexyard#1898) is complete.
- Site-owned text has 0 findings. `npm run lint:strict` keeps it at 0 when a contributor runs it.
- The build does not fail on findings. A later change can run strict mode in CI when the framework text is clean.
- We maintain the lint code and the rules file. A rule change in the framework copy changes the site results at the next tag update.

## Artifacts

- `docs-site/scripts/lint-docs.mjs`
- `docs-site/lint/docs-lint-rules.json`
- `.github/tests/test-docs-lint.sh`
- `.github/scripts/build-docs.sh`
