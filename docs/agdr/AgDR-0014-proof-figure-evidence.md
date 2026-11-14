# AgDR-0014: Keep the proof figure evidence in a checked-in file

- **Status:** Accepted
- **Date:** 2026-11-14
- **Decision owners:** ApexYard maintainers
- **Related:** GH-70

> We chose to record the three use figures of the home proof block in `.github/evidence/proof-use.tsv`. `test-claims.sh` reads the file, so the shell tests workflow must also run when the file changes. We accept one more entry in both trigger lists.

## Context

- The proof block on `index.html` shows three figures from ApexYard building itself. Nothing checked them.
- The figures come from GitHub searches and from the framework repository. CI cannot run these queries offline.
- A figure must trace to a checked-in source that a test can read.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| Remove the three figures | No source to keep. | The block loses figures that a recipe can reproduce. |
| Query GitHub in CI | Always current. | Needs the network and a token. A static page still shows the old value. |
| Dated evidence file with pinned recipes (chosen) | Offline test. A person can run each recipe again and get the same value. | A person refreshes the file by hand. |

## Decision

Keep the date, the cutoff, the `dev` commit and one pinned recipe for each figure in `.github/evidence/proof-use.tsv`.

`test-claims.sh` fails when the page, `index.md.gen` and the file disagree.

Add `.github/evidence/**` to the `pull_request` and `push` paths in `.github/workflows/shell-tests.yml`.

## Consequences

- A change to the evidence file runs the shell tests.
- The figures change only when a person runs the recipes again.
- The `.github/` tree is not deployed, so the file is not a public page.
