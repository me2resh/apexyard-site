# AgDR-0001: Pull-request previews use the shared staging environment

- **Status:** Accepted
- **Date:** 2026-09-20
- **Decision owners:** ApexYard maintainers

## Context

Reviewers need to inspect a pull request on the deployed site before merge. The site already has a production deployment workflow with an explicit production environment approval. The preview path must not weaken that gate or execute untrusted pull-request code with deployment credentials.

## Decision

Add a dedicated `pull_request_target` workflow for shared staging previews. The workflow checks out workflow code and deployment scripts from the trusted base branch, checks out the pull-request head as static input, and syncs only the resulting site files to the staging bucket. The existing `main` deployment workflow remains responsible for merged staging content and the production environment approval.

## Security and operational constraints

- AWS access uses the existing GitHub OIDC deployment role.
- Pull-request scripts are not executed while AWS credentials are available.
- The preview workflow targets staging only.
- A single concurrency group prevents overlapping preview deployments from racing on the shared staging site.
- Production remains behind the existing environment approval.

## Alternatives considered

- **Deploy every PR to an isolated environment:** rejected for this MVP because it adds infrastructure and cost.
- **Run the PR workflow from the pull-request branch:** rejected because untrusted workflow changes must not control credentialed deployment steps.
- **Change the existing main deployment workflow:** rejected because it would mix preview behavior with the production path.

## Consequences

Reviewers can inspect the latest pull request at the shared staging URL. A later preview or merged `main` deployment replaces the shared content. The workflow must continue to keep trusted deployment logic separate from pull-request content.
