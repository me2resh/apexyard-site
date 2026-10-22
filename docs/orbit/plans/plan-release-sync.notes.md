# plan-release-sync — notes

## Interview

- 2026-10-16, q1-outcome: Site stays in sync on every release. Each framework release updates the site by a repeatable sync, including the one-off catch-up to v5.9.0.
- 2026-10-16, q2-intent: Site never claims a stale framework state. Every number, version, and list on apexyard.ai derives from a released apexyard tag. A release is not done until the site reflects it.
- 2026-10-16, q3-outcomes: Site content matches the latest release. Sync is a scripted, verified step.
- 2026-10-16, q4-acceptance: ac1-1 version string, ac1-2 primitive counts, ac1-3 skill list, ac1-4 OG cards. ac2-1 one regenerate command, ac2-2 CI blocks drift, ac2-3 README is the runbook, ac2-4 verify runs on every PR. Revised after the Naqid challenge. The version is parameterised through a declared-tag file (ac2-1). Regeneration is dropped to honour issue #72. ac2-2 and ac2-4 are merged. ac1-5 and a backlog criterion (ac2-4) are added. After the Rex review, ac1-4 covers counts only, because the OG templates have no version slot.
- 2026-10-16, q5-constraints: Counts derive from the released tag. No build step on the site. Deploy path unchanged. Single reviewed PR per sync.
- 2026-10-16, q6-save: Revise per Naqid, then save. Verdict was proceed-with-changes.

## Constraints and assumptions

- Assumption: the source of truth is the declared git tag and the published GitHub Releases, never a working branch.
- Constraint: the site stays hand-authored static HTML with no generator. Scripts verify files. They do not regenerate page content. This keeps issue #72's decision.
- Constraint: this Plan does not decide Netlify versus AWS. Deploy workflows are out of scope.
- Constraint: each release sync ships as one PR through Rex review and human merge approval, never a direct push to main.
- Constraint: the release-line prose (features, fixes, improvements per release) is written by hand. No script derives it.
- Constraint: issue #72 closes only after an AgDR records its hand-authored decision. Closing it as a duplicate would drop that record.

## Proof

Set `TAG=$(cat <declared-tag file>)` and `PREV=<the tag the site declared before this sync>` before each check.

- ac1-1: for each tracked `*.html`, `*.md.gen`, `llms*.txt`, `skill.md`, and `AGENTS.md`, the framework version slots equal `$TAG`. The slots are the release pill, the `softwareVersion` JSON-LD value, and the version line of each manifest. A grep for `$PREV` across those files returns nothing. Other version strings are not framework version slots and are ignored. Examples are the `v0.1.0` release-range start, the ApexDock `v0.8.0`, and the `v1.2.0` argument example in `skills.html`.
- ac1-2: `APEXYARD_REPO=<framework clone> REF=$TAG .github/scripts/verify-counts.sh` exits 0 against the site tree.
- ac1-3: the skill names in `skill.md` equal the directory names from `git -C <framework> ls-tree -r --name-only $TAG -- .claude/skills | grep '/SKILL\.md$'`.
- ac1-4: `og/*.png` were rendered by `og/render.sh` with `APEXYARD_REF=$TAG`, and that render commit is on main. The three counts on the cards equal `derive-counts.sh --print` at `$TAG`.
- ac1-5: `gh release view --repo me2resh/apexyard --json tagName` returns `$TAG`.
- ac2-1: `git ls-files` shows exactly one file that declares the tag. `verify-counts.sh` reads it when `REF` is unset. `og/render.sh` reads it when `APEXYARD_REF` is unset.
- ac2-2: a workflow runs on every `pull_request` with no path filter, clones `me2resh/apexyard` with tags, and runs `verify-counts.sh`. A pull request that changes one count on `index.html` to a wrong value gets a failing required check.
- ac2-3: the README sync section names the declared-tag file and lists the release-line prose as the only hand edit.
- ac2-4: `gh issue list --repo me2resh/apexyard-site --state open --json number` contains none of #85, #72, #69, #66, #64, #61, #60, #55, #54, #49, and #46. Each is closed with a comment that links this Plan.

## Order

1. sync-verified
2. content-current

## Checks

- 2026-10-22, f1c0cd0: checked, no change.

## Challenges

- 2026-10-17, slice-release-sync-declared-tag-ci-gate: Naqid verdict proceed-with-changes. Accepted four fixes. The declared-tag file starts at v5.6.3, so the new check is green on main (measured: 51 of 51 claims agree). ac2-2 is recorded as counts-only in this slice. Version slots and the skill list join the gate in the content-current slice. The ac2-3 README wording now says every version, count, and list is hand-edited and CI-verified, and the release-line prose is the only edit CI cannot check. The workflow clones with `--depth 1 --branch <tag>`, runs the verifier unpiped, and never sets `REF`. The cross-repo CI dependency and the hand-authored decision behind #72 get one AgDR alongside the slice.

- 2026-10-22, slice-release-sync-content-v5-10-0: Naqid verdict proceed-with-changes. The content-current slice goes before the filed #95 gate, against the Order list. The owner wants the site on v5.10.0 now, and #95 at v5.6.3 would gate stale content. Accepted four fixes. The docs/orbit/ scan exclusion moves into this slice, so the ac1-2 proof stays exit 0. ac1-1 and ac1-5 are partial until #95 adds the declared-tag file. A release check runs before merge. The #95 build declares the tag that main describes at build time, not v5.6.3. The #95 record moves the docs/orbit/ exclusion to its exclude list. The #95 issue is not amended in this cycle. Zero unverified claims was measured at v5.10.0 and stays in scope. Version-slot and skill-list CI checks stay with sync-verified, because this slice can merge before the gate exists.

## Withdrawn slices
