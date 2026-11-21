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
- Staging reads `SITE_FEATURES` from the `staging` environment. Live reads the repository variable `SITE_FEATURES_PRODUCTION`.
- The private-terms check runs on the filtered output.

## Consequences

- To release an area, add its name to the live variable and run the deploy again.
- New content for an area must carry its tag. The feature test fails on links to removed pages.

## Artifacts

- Ticket: #200
