# AgDR-0011: Staging-only files and deploy-time GitHub stats

- **Status:** Accepted
- **Date:** 2026-10-27
- **Decision owners:** ApexYard maintainers
- **Related:** GH-137, AgDR-0004, AgDR-0009

> In the context of the staging review, facing tracked files that must not reach production and home-page stats that must not be stale or invented, I decided to exclude named staging-only files from the production sync and return 404 for them on Netlify, and to write GitHub stars and forks at staging deploy time, to keep production free of review-only surfaces and to show dated public counts, accepting that production shows no stars until the same step is added there.

## Context

- The staging review needs a page of feature previews and a testimonial slot that production must not show.
- The home page needs GitHub stars and forks that are not stale or invented.
- The site has no build step.
- A merge of staging into main carries tracked files to production.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| (A) Exclude named staging-only files from the production sync and 404 them on Netlify, plus a deploy-time stats file written by the staging deploy | Production stays clean. Counts have a fixed date. No client secret. | Production waits for a later step to show stars. |
| (B) A client-side hostname check | No deploy change. | Easy to break. Review pages still ship in the production bucket. |
| (C) Overlay tokens | Fits AgDR-0004. | Overlay values are plain text. They cannot add markup. |
| (D) A live browser call to the GitHub API | Counts are live. | Rate limits. CSP `connect-src`. No fixed date. |

## Decision

Chosen: **A**.

1. Staging-only files: `previews.html` and `staging-only.js`.
2. `deploy-aws.yml` production sync excludes both files.
3. `deploy-staging-v2.yml` writes `github-stats.json` after the private overlay and before AWS credentials.
4. `_redirects` returns 404 for `/previews`, `/previews.html` and `/staging-only.js` on Netlify.
5. `.github/scripts/write-github-stats.sh` reads the public GitHub API (or a test input file) and writes dated stars and forks. A failed read writes no file.
6. Production shows no stars until a later change adds the same stats step to the production deploy. Production shows no testimonial slot while it excludes `staging-only.js`.
7. `shell-tests.yml` also runs on changes to `*.js`, `_redirects`, `docs-site/content-map.mjs` and `docs-site/astro.config.mjs`, because `.github/tests/test-staging-review.sh` reads them.
8. `product.js` loads `staging-only.js` only on the staging host, so production pages never request it.

## Consequences

- Production loads `/staging-only.js` only if a page links it.
- The home page links it, so production returns 404 for that script and the slot stays hidden.
- The stats are as fresh as the last staging deploy and carry their date.
- A failed read hides the numbers.

## Artifacts

- `previews.html`
- `staging-only.js`
- `.github/workflows/deploy-aws.yml`
- `.github/workflows/deploy-staging-v2.yml`
- `_redirects`
- `.github/scripts/write-github-stats.sh`
- `.github/tests/test-staging-only.sh`
- `.github/tests/test-staging-review.sh`
- `.github/workflows/shell-tests.yml`
