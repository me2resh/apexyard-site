# plan-release-sync — notes

## Interview

- 2026-10-16, q1-outcome: Site stays in sync on every release. A repeatable sync so each framework release updates the site without manual drift, including the one-off catch-up to v5.9.0.
- 2026-10-16, q2-intent: Site never claims a stale framework state. Every number, version, and list on apexyard.ai is derived from a released apexyard tag, and a release is not done until the site reflects it.
- 2026-10-16, q3-outcomes: Site content matches the latest release. Sync is a scripted, verified step.
- 2026-10-16, q4-acceptance: ac1-1 version string, ac1-2 primitive counts, ac1-3 skill list, ac1-4 OG cards. ac2-1 one regenerate command, ac2-2 CI blocks drift, ac2-3 README is the runbook, ac2-4 verify runs on every PR. Revised after the Naqid challenge: the version is parameterised through a declared-tag file (ac2-1), regeneration is dropped to honour issue #72, ac2-2 and ac2-4 are merged, ac1-5 and a backlog criterion (ac2-4) are added.
- 2026-10-16, q5-constraints: Counts derive from the released tag. No build step on the site. Deploy path unchanged. Single reviewed PR per sync.
- 2026-10-16, q6-save: Revise per Naqid, then save. Verdict was proceed-with-changes.

## Constraints and assumptions

- Assumption: the source of truth is the declared git tag and the published GitHub Releases, never a working branch.
- Constraint: the site stays hand-authored static HTML with no generator. Scripts verify files. They do not regenerate page content. This keeps issue #72's decision.
- Constraint: this Plan does not decide Netlify versus AWS. Deploy workflows are out of scope.
- Constraint: each release sync ships as one PR through Rex review and human merge approval, never a direct push to main.
- Constraint: the release-line prose (features, fixes, improvements per release) is written by hand. No script derives it.

## Proof

- ac1-1: with `TAG=$(cat <declared-tag file>)`, a grep for `v[0-9]+\.[0-9]+\.[0-9]+` and for `"softwareVersion": "[0-9.]+"` across every tracked `*.html`, `*.md.gen`, `llms*.txt`, `skill.md`, and `AGENTS.md` returns only the declared tag.
- ac1-2: `APEXYARD_REPO=<framework clone> APEXYARD_REF=$TAG .github/scripts/verify-counts.sh` exits 0 against the site tree.
- ac1-3: the skill names in `skill.md` equal the directory names from `git -C <framework> ls-tree -r --name-only $TAG -- .claude/skills | grep '/SKILL\.md$'`.
- ac1-4: `og/*.png` were rendered by `og/render.sh` with `APEXYARD_REF=$TAG`, and that render commit is on main.
- ac1-5: `gh release view --repo me2resh/apexyard --json tagName` returns the declared tag.
- ac2-1: `git ls-files` shows exactly one file that declares the tag, and `verify-counts.sh` and `og/render.sh` read it when `APEXYARD_REF` is unset.
- ac2-2: a workflow runs on every `pull_request` with no path filter, clones `me2resh/apexyard` with tags, and runs `verify-counts.sh`. A pull request that changes one count on `index.html` to a wrong value gets a failing required check.
- ac2-3: the README sync section names the declared-tag file and lists the release-line prose as the only hand edit.
- ac2-4: `gh issue list --repo me2resh/apexyard-site --state open` shows none of #85, #72, #66, #64, #61, #60, #55, #54 open without a comment that links this Plan.

## Order

1. sync-verified
2. content-current

## Checks

## Withdrawn slices
