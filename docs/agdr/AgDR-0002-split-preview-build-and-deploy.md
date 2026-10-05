# AgDR-0002: Split the PR preview into an unprivileged build and a trusted deploy

- **Status:** Accepted
- **Date:** 2026-10-05
- **Supersedes:** AgDR-0001
- **Decision owners:** ApexYard maintainers

## Context

AgDR-0001 used one `pull_request_target` job. That job checked out the pull request head, assumed the shared AWS deploy role, and then synced the checked-out files. The pull request can come from a fork. Untrusted content therefore sat next to an AWS credential. The markdown copy step also followed symlinks.

The shared deploy role will trust only the `main` branch subject (issue #91). A `pull_request_target` job runs with a `main` token, so that change alone does not close the path. A job that declares `environment:` presents an environment subject, not the `main` subject, so such a job can no longer assume the role.

## Decision

1. **Split the preview in two workflows.**
   - `preview-build.yml` runs on `pull_request`. It has `contents: read` only, no `id-token`, and no secrets. It uploads the site output as an artifact.
   - `preview-deploy.yml` runs on `workflow_run` from the default branch. It downloads only the artifact, validates it as untrusted input (`.github/scripts/validate-preview-artifact.sh`: no symlinks, no non-regular files, no `..` paths, no escape from the folder), assumes the role, and syncs it to the staging bucket root. It never checks out or runs pull request code.
2. **Keep the preview behaviour of AgDR-0001.** The sync flags, markdown alternates, staging `robots.txt`, invalidation, and the single fixed concurrency group are the same. Two previews never sync the shared bucket root at the same time.
3. **Move the production approval to its own job.** `approve-production` declares `environment: production` (required reviewers) and has no AWS access. `deploy-production` needs it and declares no `environment:`.
4. **Deploy staging from `main` only.** `deploy-aws-staging.yml` has no branch push trigger. It runs by manual dispatch, and only from `main`. `deploy-staging` in `deploy-aws.yml` has no `environment:`.

## Alternatives considered

- **Keep `pull_request_target` and rely on the role trust alone:** rejected. The job still runs fork content with a credential.
- **Environment subjects with a `main`-only deployment-branch policy:** rejected. The control lives in GitHub settings, outside the repository and outside review.
- **Deploy every PR to its own prefix:** rejected for now. It changes the preview URL and needs infrastructure checks. AgDR-0001 rejected isolated environments for cost.

## Consequences

- A fork pull request gets a preview with no AWS access during the build. The deploy job finds the PR number by matching the open PR head commit and head repository. The number is for logs only. A missing number does not stop the deploy.
- The build checks out the PR merge commit (the `pull_request` default). A PR with merge conflicts gets no preview.
- The production approval is a separate job. If someone re-runs only `deploy-production` in an approved run, GitHub reuses the earlier approval and does not ask again. The commit was already approved.
- `workflow_run` workflows run only from the default branch. The preview deploy has no effect until it is merged.
- Do not add `environment:`, `id-token: write`, or secrets to any job that builds pull request code. Do not add `environment:` to any job that assumes the shared role. `test-preview-workflows.sh` checks both rules.
