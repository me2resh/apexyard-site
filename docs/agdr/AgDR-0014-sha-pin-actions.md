# AgDR-0014: Pin GitHub Actions to commit SHAs

- **Status:** Accepted
- **Date:** 2026-11-14
- **Decision owners:** ApexYard maintainers
- **Related:** GH-13

> We chose to pin every GitHub Action to a full commit SHA. A tag can move. A commit cannot. We accept that updates are now manual.

## Context

- The deploy workflows hold `id-token: write`. They get AWS credentials through OIDC.
- Actions were pinned to tags such as `actions/checkout@v4`.
- A moved or compromised tag could run code in a job that can assume an AWS role.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| Keep tags | No edits. | A tag can move. |
| Pin to commit SHAs (chosen) | A pin cannot move. | Updates are manual. |
| Pin only the deploy workflows | Smaller change. | Other workflows stay open to the same risk. |

## Decision

Pin every `uses:` in `.github/workflows/*` to a full 40-character commit SHA.

Add the release version in a trailing `# vX.Y.Z` comment.

Update an Action by changing the SHA and the version comment together in one edit.

No version changed in this decision. Each SHA is the commit that the old tag pointed to.

## Consequences

- Update a pin by hand when a new version is needed.
- The comment shows the version that the SHA matches.

## Artifacts

- `.github/workflows/*.yml`
