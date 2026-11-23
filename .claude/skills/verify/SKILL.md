---
name: verify
description: Run the repo tests, load the main pages in a browser, sweep the scroll marker, and print evidence before a PR.
---

# Verify this site

Run this skill before you open a PR. Paste its output into the PR body.
A green CI run does not replace it.

This repo is a static site. It has no build step and no `package.json`.

## Setup

- Prerequisites: bash, git, python3, node. A browser is optional (see below).
- Install: none. Add no dependency to this repo.
- Start: `python3 -m http.server <free port>` from the repo root. The script picks the port and waits up to 5 s for `index.html`.
- Main flows: load `index.html`, `how-it-works.html`, `pricing.html`, and `skills.html`. Expect no console error. Sweep the scroll position in 25 steps.
- Stop: the script stops the server and removes its temp directory on every exit path.

## Run

```bash
bash .claude/skills/verify/verify.sh
```

The script does these steps:

1. Run every `.github/tests/*.sh` script. Report each pass or fail.
2. Serve the repo root on localhost.
3. Load the four pages in a headless browser. Fail on any console error.
4. Scroll each page in 25 steps. At each step, once the line is on screen, check the `.marker` centre. It must sit below the 67 px header and inside the viewport.
5. Check that `git status --porcelain` is the same before and after.
6. Print one `## Verify evidence` block.

Exit code 0 means no check failed. Exit code 1 means at least one check failed.

## Browser order

1. Playwright from `VERIFY_PLAYWRIGHT_DIR`, the global npm root, or the npx cache. The script never installs it.
2. Chrome or Chromium headless with `--dump-dom` and `--enable-logging`. This path checks page load and console errors only. It marks the scroll sweep SKIPPED.
3. No browser: every page check is marked SKIPPED with the reason.

A SKIPPED check is never a pass. The result then reads `Partial`. Do not claim the change is verified for a SKIPPED check. Report the blocker.

## Options

- `VERIFY_NO_BROWSER=1` skips the server and browser checks.
- `VERIFY_SKIP_TESTS=1` skips the `.github/tests/*.sh` checks.
- `VERIFY_PLAYWRIGHT_DIR=<dir>` selects a Playwright install.
- `CHROME_BIN=<path>` selects the Chrome binary for the fallback.

## Evidence for the PR

Paste the `## Verify evidence` block as printed. It holds:

- Result: Passed, Partial, or Failed.
- Revision and the count of uncommitted paths.
- Environment and the browser used.
- One row per check with its status and detail.
- Cleanup result and the unverified checks.

Add a line for any acceptance criterion the script does not cover.
