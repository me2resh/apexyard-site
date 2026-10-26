# AgDR-0010: Run shell tests for waitlist script and style changes

- **Status:** Accepted
- **Date:** 2026-10-26
- **Decision owners:** ApexYard maintainers
- **Related:** GH-122

> We chose to add three files to the workflow paths list. This makes the waitlist test run for JavaScript-only and CSS-only changes. We accept that both trigger lists need the same edits.

## Context

- The HTML-only paths filter skips the waitlist test for JavaScript-only changes.
- Changes to the waitlist scripts and styles need this test.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| Keep the HTML-only paths | No workflow change. | JavaScript-only changes skip the test. |
| Add three files to the paths list (chosen) | Script and style changes run the test. | Both trigger lists need the same edits. |
| Remove the paths filter | Every change runs the job. | More CI runs. |

## Decision

Add `waitlist.js`, `site-config.js` and `product.css` to the paths lists in `.github/workflows/shell-tests.yml`.

Apply this change to the `pull_request` and `push` triggers.

Run `.github/tests/test-waitlist.sh` for JavaScript-only and CSS-only edits to these files.

## Consequences

- The `pull_request` and `push` paths lists stay duplicated.
- Edit both lists when the paths change.

## Artifacts

- `.github/workflows/shell-tests.yml`
- `.github/tests/test-waitlist.sh`
