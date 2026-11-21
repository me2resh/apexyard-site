---
id: AgDR-0016
timestamp: 2026-11-21T23:00:00Z
agent: claude-code
model: claude-sonnet-5-5
trigger: user-prompt
status: executed
category: ci
---

# Feature flags in the docs build

> In the context of #202, where the docs sidebar still listed Cockpit, hosted gate and Readiness pages with the flags off, I decided to filter the docs at build time from `SITE_FEATURES`, to achieve a docs site with no page, count, search entry or link of an area that is off, accepting that the docs job needs the variable.

## Context

- AgDR-0015 filters the site HTML after the build. The docs sidebar and the search index come from the Astro build, not from tagged HTML, so that filter cannot remove them.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Filter in the docs build (chosen) | Sidebar, counts, pages, search index, `llms.txt` and links all agree. | The docs job reads `SITE_FEATURES`. |
| Tag the built sidebar and filter after | Reuses `apply-features.sh`. | The search index and counts stay wrong. |

## Decision

Chosen: **filter in the docs build**. A group in `content-map.mjs` carries `feature`. `sync-content.mjs` leaves out a group whose feature is off and removes links to it. An unset `SITE_FEATURES` keeps every page. The staging docs job passes `SITE_FEATURES`. `test-docs-features.sh` builds both states.

## Consequences

- A docs page about an area has to sit in a group with a `feature` field.
- Decided together with AgDR-0015.
