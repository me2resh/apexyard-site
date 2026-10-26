# AgDR-0006: Check tracked files for private terms read from a secret

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-102, AgDR-0004

> In the context of a public repository that must hold no private commercial terms, facing the fact that a committed list of terms publishes those terms, I decided to read the terms only from secrets and check every tracked file in CI, to achieve a guard that names no term, accepting that the check skips where no secret is available.

## Context

AgDR-0004 keeps prices, limits and offers out of the repository with placeholder tokens and a private overlay. The guards from AgDR-0004 check for price-shaped text and check that production shows no overlay value. They do not catch a private word that is not price-shaped, such as an offer name, in any tracked file.

A guard that lists the private terms in the repository publishes them. The list must come from a secret.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| A. `PRIVATE_TERMS` repository secret, a check on every pull request and on pushes to `main` and `staging`, plus the overlay values in the staging deploy | Catches a term before merge on a same-repository PR. No term in the repository or the log. | A repository secret is readable by every workflow in the repository. It skips on a PR from a fork. |
| B. Only the `STAGING_OVERLAY` values, in the staging deploy | No new secret. | Runs after the merge to `staging`. Catches overlay values only, not other private words. |
| C. A term list in the repository, hashed | No secret needed. | Short terms are easy to recover from a hash. It still signals what the terms look like. |

## Decision

Option A, with option B as a second line.

1. `.github/scripts/check-private-terms.sh` reads terms from `PRIVATE_TERMS` (one per line) and from `OVERLAY_JSON` values. When `GITHUB_ACTIONS=true`, it masks each term with `::add-mask::` before it prints anything; locally it never prints a term. It matches the raw and HTML-escaped forms, case-insensitive, in every text file that `git ls-files` lists. A hit prints the file path and the term's index number, or the token name for an overlay value.
2. `private-terms.yml` runs the check on every pull request and on pushes to `main` and `staging`, with no path filter.
3. Without a secret the check skips with a notice. When the repository variable `PRIVATE_TERMS_REQUIRED` is `true`, a push to `main` or `staging` without the secret fails.
4. `deploy-staging-v2.yml` runs the same check with the `STAGING_OVERLAY` values before it applies the overlay, and requires the values.

## Consequences

- The owner sets the `PRIVATE_TERMS` secret from a private file and then sets `PRIVATE_TERMS_REQUIRED` to `true`.
- A pull request from a fork gets no check. A maintainer merge to `staging` or `main` still runs it.
- A term that is too general, such as a common word, fails the check on unrelated files. The owner keeps the list to specific terms.

## Evolution

- 2026-10-26: `mask()` emits `::add-mask::` only when `GITHUB_ACTIONS=true`. Reason: a local run printed private terms in clear text via those lines; CI behaviour is unchanged. Covered by `.github/tests/test-mask-local.sh`.
