---
id: AgDR-0015
timestamp: 2026-11-21T22:00:00Z
agent: claude-code
model: claude-opus-5-5
trigger: user-prompt
status: executed
category: ci
---

# Deploy-time feature flags for product areas

> In the context of releasing the new site before every paid area is ready, facing the need to keep unreleased areas off the live site, I decided to remove disabled areas at deploy time from a per-environment GitHub variable, to achieve a live site that holds no unreleased content, accepting a filter step in every deploy and a tag on every feature element.

## Context

- The owner wants to release the new site and docs now, and switch on each product area when it is ready (21 Nov 2026).
- Areas: `build`, `gate`, `readiness`, `pricing`, `cockpit`. Live starts with `build` only. Staging shows all five.
- The site is static HTML with no build step. The live deploy job has no GitHub environment, by design, for its AWS access.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Remove disabled areas at deploy time | Unreleased text is not published, indexed or reachable. Switching on needs no code change. | Every deploy runs a filter step. Every feature element needs a tag. |
| Hide areas in the browser with JavaScript | Simple. | Text is still in the published HTML, search results and text copies. Pages are reachable by URL. |
| Keep unreleased pages on a separate branch | No tags. | Merges grow hard. Cross-page links drift. |

## Decision

Chosen: **remove disabled areas at deploy time**.

- Elements carry `data-feature="<name>"`. Text and XML files use `<!-- feature:<name> -->` regions.
- `.github/scripts/apply-features.sh` copies the site and removes disabled pages, elements and regions. An unknown name fails the deploy. An empty list turns every area off.
- V2 staging reads `SITE_FEATURES` from the `staging` environment. The main-branch staging rehearsal and live jobs both read repository `SITE_FEATURES_PRODUCTION`, with no environment.
- The staging deploy runs the private-terms check on the filtered output. The live deploy reads no secret, as before.

## Consequences

- To release an area, add its name to the live variable and run the deploy again.
- New content for an area must carry its tag. The feature test fails on links to removed pages.

## Artifacts

- Ticket: #200

The v2 staging deploy reads `SITE_FEATURES` from the `staging` environment.
The main-branch staging job in `deploy-aws.yml` has no environment and reads
repository `SITE_FEATURES_PRODUCTION`, mirroring live. Set both variables BEFORE
this PR merges, because merging into `staging` immediately starts its deploy.
Preview builds read repository `SITE_FEATURES`, falling back to all five; they
cannot read the staging environment variable.

ANY tags are for containers with individually tagged children. Split prose by
area; never use ANY to retain a sentence naming disabled products.
`data-feature="build pricing"` uses ANY: the element shows when either area is on.
The `feature:` comment mode also uses ANY. The `feature-all:` mode shows only
when every listed area is on. The `feature-off:` mode shows when at least one
listed area is off, including the all-off state. Close each region with the
same mode and names. Nest regions to require another area. The only HTML
feature attribute is `data-feature`; ALL and off modes use comment regions.

```html
<!-- feature:build pricing -->Either area is on.<!-- /feature:build pricing -->
<!-- feature-all:build pricing -->Both areas are on.<!-- /feature-all:build pricing -->
<!-- feature-off:gate readiness --><!-- feature:build -->Build guides your agents.<!-- /feature:build --><!-- /feature-off:gate readiness -->
```

The last example shows only when Build is on and Gate or Readiness is off.
Keep these markers outside inline scripts. The game reads tagged HTML copy.

The filter keeps `docs/`, including built docs and their search index. Each site
sync excludes `docs/*`; the v2 deploy uploads built docs separately. The filter
excludes `docs-site/`, `handbooks/`, OG templates and repository README/AGENTS files.
The empty and single-area tests scan published text, metadata, links and filenames.
HTML attribute identifiers are not product mentions. Lowercase `build` is a verb
or compilation noun. Exact generic exceptions are “Build the loop”, “Build a
level header”, “Build a working prompt”, “Build-only verify”, “Build, under
governance” and “Apple's gate”. No other capitalised Build or case-insensitive
Gate, Readiness, Pricing or Cockpit word is exempt.
The all-on content test detects filtering loss against the current source,
excluding feature-off alternatives; it does not guard against source edits.
Bare/empty feature attributes, tagged non-void self-closing HTML and malformed
feature region names fail the filter.
