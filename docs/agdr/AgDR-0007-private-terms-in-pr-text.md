# AgDR-0007: Check PR text and commit messages for private terms

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-102, AgDR-0006

> In the context of a public repository, facing two PRs that leaked restricted words through PR text and commit messages, I decided to extend the AgDR-0006 guard to the PR title, the PR body and every commit message, in CI and in local hooks, to achieve a leak check before the text is public, accepting that a local hook only helps where it is installed.

## Context

AgDR-0006 checks tracked files only. The PR title, the PR body and commit messages are public on a public repository, and the file check does not see them.

## Decision

1. `check-private-terms.sh` gets a `--text-dir <dir>` mode. It reuses the term loading and the masking, and checks each file in the directory as one field. A hit prints the field name and the term index only.
2. `check-pr-text.sh` collects the title and the body from the event payload (never from a command line, never printed) and each commit message in `base..head`, then calls text mode. `private-terms-pr-text.yml` runs it on `opened`, `edited`, `synchronize` and `reopened`. Without the secret it skips with a notice.
3. `.githooks/` holds a `commit-msg` hook and a `pre-push` hook. They read terms from `~/.claude/apexyard/private/private-terms.txt`, skip silently when it is absent, and print the index only. A contributor installs them with `git config core.hooksPath .githooks`. They are not installed globally.
4. `.github/pull_request_template.md` tells authors to use overlay token names, to write no values or paid-only words, and to report leak scans as "0 hits".

## Consequences

- A PR from a fork gets no CI check, as in AgDR-0006.
- The CI job fails the PR. The author must edit the text or rewrite the commit; a public commit message that already leaked stays in history until the branch is rewritten.
- The local hooks are the first line. CI is the second.
