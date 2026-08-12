# apexyard-site

The ApexYard marketing and docs site — static HTML, deployed on Netlify at [yard.apexscript.com](https://yard.apexscript.com).

## What's here

Hand-authored HTML pages (`index.html`, `architecture.html`, `skills.html`, `how-it-works.html`, `game.html`) plus Markdown alternates (`.md.gen` files) served as clean `/foo.md` routes for AI agents and tooling that prefer low-token plain text over full HTML. Supporting assets: `_headers`, `_redirects`, `netlify.toml`, `robots.txt`, `sitemap.xml`, `llms.txt`, `llms-full.txt`.

## How it deploys

Native Netlify git deploy — push to `main` triggers a deploy automatically. No build step. Publish directory is the repo root (Netlify default).

Security headers and the canonical 301 redirect from `apexyard.netlify.app` to `yard.apexscript.com` are set in `netlify.toml`. Markdown-alternate `Link:` response headers and MIME types are in `_headers`. Clean-URL rewrites and markdown-alternate rewrites are in `_redirects`.

## Manually maintained content

The primitive counts are hard-coded across `index.html`, `architecture.html`, `skills.html`, the `.md.gen` alternates, `llms.txt`, `llms-full.txt`, and `skill.md`, and are updated by hand on each ApexYard framework release. A cross-repo CI drift-guard that used to keep them honest lives in the apexyard framework repo and cannot run across repos — so refresh these numbers when cutting a new framework release.

### What each count means

Refresh from the framework's released **tag**, not from whatever the last sync said. Copying forward is how the rules count sat at 11 for two releases while the hook count was being kept current — when nobody writes the definition down, each sync only fixes what someone happened to notice.

The block below is **not a transcription** of what the tooling does — it is the tooling. Every definition lives once, in `.github/scripts/derive-counts.sh`, as the text of the command that computes it. That same string is what gets evaluated to derive the number, what `og/render.sh` stamps onto the social cards, what `verify-counts.sh` asserts the pages against, and what is printed here. `test-derive-counts.sh` fails if these characters and `derive-counts.sh --recipes` ever differ, so editing one without the other cannot reach `main`.

Regenerate this block with `.github/scripts/derive-counts.sh --recipes`. Point `REPO` at a clone of the framework and `REF` at the released tag:

<!-- BEGIN derive-counts.sh --recipes — asserted byte-identical by .github/tests/test-derive-counts.sh. Regenerate, don't hand-edit. -->
```bash
REPO=/path/to/apexyard REF=v5.4.0

# skills — directories carrying a SKILL.md
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/skills | grep -c '/SKILL\.md$'

# hooks — top-level *.sh only; excludes _lib* helpers and the tests/ subdir
git -C "$REPO" ls-tree --name-only "$REF" -- .claude/hooks/ \
  | sed 's#\.claude/hooks/##' | grep '\.sh$' | grep -vc '^_lib'

# agents — *.md under .claude/agents/
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/agents | grep -c '\.md$'

# roles — *.md under roles/, excluding READMEs and premium roles/growth/
git -C "$REPO" ls-tree -r --name-only "$REF" -- roles \
  | grep '\.md$' | grep -v 'README.md' | grep -vc '^roles/growth/'

# rules — *.md under .claude/rules/
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/rules | grep -c '\.md$'

# releases — published GitHub Releases (NOT git tags; the two differ).
# Needs network + gh auth, so it is opt-in everywhere: `verify-counts.sh --releases`.
gh api --paginate repos/me2resh/apexyard/releases --jq '.[].tag_name' | grep -c .
```
<!-- END derive-counts.sh --recipes -->

The `v5.4.0` on the first line is illustrative and tracks nothing — pass the tag you actually mean. Or skip the copy-paste entirely: `.github/scripts/derive-counts.sh --print /path/to/apexyard v5.4.0` runs all five tag-derived recipes and prints the numbers.

At **v5.4.0**: 66 skills · 51 hooks · 23 agents · 20 roles · 19 rules · 6 departments · 29 published releases.

Three of those definitions had already drifted between their copies before they were unified, none of them visibly, because none of the differences changed a number at v5.4.0: `og/render.sh` excluded premium `roles/growth/` where the other two did not, this README counted releases with `wc -l` where the verifier used `grep -c .`, and the `sed` above left a dot unescaped. The unified `roles` recipe keeps the exclusion — it is the stricter reading, and it is the one that keeps the published count reproducible by a reader who only has the open framework.

### Check it with one command

Reading the definitions above tells you what the numbers should be. `verify-counts.sh` tells you whether the pages actually say that:

```bash
APEXYARD_REPO=/path/to/apexyard REF=v5.4.0 .github/scripts/verify-counts.sh
APEXYARD_REPO=/path/to/apexyard REF=v5.4.0 .github/scripts/verify-counts.sh --releases  # + the Releases API
```

It exits `0` when every surface agrees, `1` naming each stale claim, and `2` when it cannot derive — if a glob stops matching because the framework layout moved, it refuses outright rather than reporting that a primitive has dropped to zero and inviting you to rewrite every correct page.

The important part is *how* it searches. It does not look for the numbers it expects in a list of files it knows about; it scans every tracked file for `<number> <primitive-noun>` and checks each match. A page added next year with a copied-forward count fails the check without anyone remembering to register it. That is the direct answer to the failure this section already describes — the rules count sat wrong at 11 for two releases because each sync only fixed what someone happened to notice.

A phrase is only matched where it follows the number immediately, so the site's exact wording has to be in the noun lists at the top of the script — `66 active slash commands` is not matched by `slash commands`. When an **unlisted adjective** sits in front of a known noun, the script says so rather than passing quietly:

```
$ sed -i 's/19 rule files/19 core rules/' architecture.html && APEXYARD_REPO=… REF=v5.4.0 .github/scripts/verify-counts.sh
UNVERIFIED [rules]            architecture.html:659  "19 core rules" — no listed phrase matches
OK (with gaps): 60 count claim(s) checked and agreeing with v5.4.0,
                but 1 unverified claim(s) above matched no listed phrase.
```

That does not fail the run — unknown is not the same as wrong — but a clean pass can never quietly mean "the check never looked there". When you see one, add the page's wording to the noun list, or reword the page if it is the odd one out.

**Know what this does not cover.** Three gaps, all deliberate and all worth knowing before you read a clean pass as a full one:

- **An unfamiliar noun.** The sweep is anchored on a *known noun*, so it catches an unfamiliar adjective but not an unfamiliar noun. `11 files`, `11 guides`, `eleven rule files`, and `11&nbsp;rule files` are all silent — neither checked nor reported.
- **`6 departments`** is checked by nothing, and five files state it: `README.md`, `index.html`, `index.md.gen`, `llms.txt`, `llms-full.txt`. Re-derive that list with `git grep -lE '[0-9]+ departments'` before you edit rather than trusting the one written here — a list of hand-edit sites is itself hand-maintained, and missing one is exactly how a count goes stale on a single page. The number is derivable — `git -C "$REPO" ls-tree -d --name-only "$REF" -- roles/ | wc -l` — and has been stable at 6 since v4.4.0, which is why it has never drifted, not why it is safe.
- **The release count** is checked only under `--releases`, and the unverified sweep does not run for it at all, so an unlisted release wording is silent with no signal. That is exactly why `architecture.html` was reworded from `19 files` to `19 rule files` in #69 rather than adding `files` to the rule nouns: `files` is too generic to check safely, so the page was made checkable instead. Prefer that fix when you hit this.

None of this is hypothetical caution. The first version of this script omitted `active slash commands` and left 9 of the 10 skill claims on `skills.html` unchecked while reporting a clean pass — on the page whose entire subject is that count. And the bare `19 files` on `architecture.html` was the same line that had read `11 files` two releases running. Both were found in review, not by the script.

Run it whenever you sync counts, and again before you merge.

Two numbers on the site look like primitive counts but are not, and must be left alone:

- The `55 → 56 hooks` line in the gate-replay terminal on `index.html` counts hook **wiring entries in `.claude/settings.json`** at PR #787's merge commit — a different metric at a fixed point in history. It carries an inline comment saying so.
- `5–20 structured tickets` in the `/tickets-batch` description is a range, not a role count.

When the skill total changes, diff the **names** too — a rename keeps the total right while leaving a dead `/command` on the page:

```bash
git -C "$REPO" ls-tree -r --name-only "$REF" -- .claude/skills \
  | sed -n 's#^\.claude/skills/\(.*\)/SKILL\.md$#\1#p' | sort > /tmp/tag-skills.txt
grep -oE 'class="skill__name">/[a-z0-9-]+' skills.html | sed 's#.*>/##' | sort > /tmp/site-skills.txt
diff /tmp/tag-skills.txt /tmp/site-skills.txt && echo "names match"
```

`verify-counts.sh` checks totals, not names — a rename keeps the total right, so this diff is still a separate step.

### The proof block is NOT covered by any of the above

The four figures in the `03 / PROOF` section of `index.html` are a different family from the primitive counts, and nothing verifies them:

| Figure | On the page | Basis |
|---|---|---|
| PRs reviewed & merged, last 90 days | 343 | undocumented; a **rolling window**, so it is wrong again a week after any fix |
| Production releases shipped | 29 | published GitHub Releases — the one that *is* documented, and current |
| Technical decisions on record | 72 | undocumented; reads as `docs/agdr/` on the framework's `main` |
| Bugs caught and fixed before users hit them | 52 | undocumented — no query is known to reproduce it |

Three of the four were written at **v2.0.0** and have not been touched since; the framework is now at v5.4.0. They are excluded from `verify-counts.sh` on purpose rather than by oversight: a verifier that asserts a number whose definition nobody recorded would be encoding a guess as a check.

Do not refresh these by picking a plausible query. Two need a decision first — what counts as a "bug caught before users hit them", and whether a rolling 90-day window belongs on a hand-maintained static page at all. Tracked in [#70](https://github.com/me2resh/apexyard-site/issues/70).

## CI

`.github/workflows/link-check.yml` runs lychee on every PR and weekly to catch broken links in HTML and Markdown files.

`.github/workflows/shell-tests.yml` shellchecks the shell scripts and runs every `.github/tests/test-*.sh` — currently the CloudFront invalidation guard (#48), the count verifier (#69), and the derive library plus its README-sync assertion (#72). It also triggers on `README.md` and `og/render.sh`, because both are now bound to `derive-counts.sh`: a README edit that desyncs the definition block, or a `render.sh` edit that breaks the source, has to fail somewhere.

It still does **not** run on a PR that only edits page content. Counts are therefore verified by running `verify-counts.sh` yourself, not by CI; wiring that to run per-PR needs a decision about cloning the framework repo in CI and pinning the ref.
