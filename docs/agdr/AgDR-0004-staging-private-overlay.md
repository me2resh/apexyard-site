# AgDR-0004: Fill staging placeholders from a private overlay in one isolated job

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-102

> In the context of the site v2 build on the `staging` branch, facing a public repository that must hold no commercial values, I decided to keep placeholder tokens in the repository and fill them in one staging-only job from an environment secret, to achieve a reviewable staging site, accepting a new scoped AWS role and a paused main-to-staging deploy.

## Context

The site v2 pages need commercial values for review on `staging.apexyard.ai`. The repository is public. Files, branch names, commit messages, PR bodies, issue bodies and Actions logs must hold no such value. Production must never show one.

The shared `github-actions-deployer` role trusts the `ref:refs/heads/main` subject only (AgDR-0023 in the infrastructure repo). A job that declares `environment:` presents the `environment:<name>` subject. A job on the `staging` branch presents `ref:refs/heads/staging`. Neither subject can assume the shared role.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| A. Environment secret on `staging`, one job on the `staging` branch, scoped AWS role | The branch policy limits the secret to the `staging` branch. The secret, the overlay and the S3 write stay in one job. | Needs a new role in the infrastructure repo that trusts `environment:staging`. |
| B. Repository secret, a `main` workflow that checks out `staging` | Works with the shared role. No infrastructure change. | Every workflow on every branch can read a repository secret. No branch policy. |
| C. Two jobs: overlay in an environment job, sync in a `main` job | Works with the shared role. | The overlaid site must move between jobs as an artifact. A public repository exposes artifacts to any signed-in user. |
| D. Private overlay repository | Gives value history. | Adds a deploy key to rotate and a second repository. It does not solve the AWS subject problem. |

## Decision

Option A.

1. The values live in the `STAGING_OVERLAY` secret of the `staging` environment. The environment deployment branch policy admits the `staging` branch only.
2. `deploy-staging-v2.yml` runs on a push to `staging`. It is the only workflow that reads the secret. It declares `environment: staging` and assumes the role in the `STAGING_OVERLAY_ROLE_ARN` repository variable. It stops before any AWS call while that variable is empty.
3. Public files wrap each value in a token with a visible fallback: `<!--{{TEAM_PRICE}}-->Pricing to be announced<!--/{{TEAM_PRICE}}-->`. `apply-overlay.sh` replaces the tokens in a copy under `$RUNNER_TEMP`. It masks each value first (`::add-mask::` only when `GITHUB_ACTIONS=true`) and logs token names and counts only. Locally it never prints a value.
4. `check-prod-overlay-free.sh` fetches the production pages after each staging deploy and fails if any value is there.
5. `test-overlay-isolation.sh` fails a pull request when another workflow reads the secret or enters the `staging` environment, when the v2 workflow gains another trigger or an artifact upload, or when a public file holds a bare token or price-shaped text.
6. The `SITE_V2_ON_STAGING` repository variable pauses the main-to-staging deploy and the PR preview deploy, so they do not overwrite the overlaid site. That change lands on `main`, because `workflow_run` and `main` pushes read the workflow files of `main`.

## Consequences

- The overlay deploy fails closed until the scoped role exists and `STAGING_OVERLAY_ROLE_ARN` is set.
- Production keeps the fallback text. A merge of `staging` into `main` carries tokens and fallbacks only.
- Each overlay value must be text that production does not show. Otherwise the production check reports a false leak.
- A repository admin can still change a workflow. Masking protects the logs, not the workflow source. Branch protection on `staging` limits this.
- Anyone with the shared staging Basic Auth credential can see the values on staging.

## Evolution

- 2026-10-26: `mask()` emits `::add-mask::` only when `GITHUB_ACTIONS=true`. Reason: a local run printed overlay values in clear text via those lines; CI behaviour is unchanged. Covered by `.github/tests/test-mask-local.sh`.

## Artifacts

- Ticket: GH-102
- Workflow: `.github/workflows/deploy-staging-v2.yml`
- Scripts: `.github/scripts/apply-overlay.sh`, `.github/scripts/check-prod-overlay-free.sh`
- Tests: `.github/tests/test-apply-overlay.sh`, `.github/tests/test-overlay-isolation.sh`, `.github/tests/test-mask-local.sh`
