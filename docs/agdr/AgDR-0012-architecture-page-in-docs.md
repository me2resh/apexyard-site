# AgDR-0012: Architecture page moves into /docs

- **Status:** Accepted
- **Date:** 2026-10-27
- **Decision owners:** ApexYard maintainers
- **Related:** GH-137, AgDR-0006, AgDR-0008

> In the context of the product site and Starlight docs, facing a standalone architecture page that duplicated the Keel story and drifted from STE docs lint, I decided to publish architecture as a site-owned quickstart page under `/docs`, redirect `/architecture` there, and keep five changelog releases with an external All releases link, to give one canonical architecture page that the docs lint owns and that the marketing nav can point at.

## Context

- The marketing site had a long hand-authored `/architecture` page (five-layer model).
- The docs sub-build already owns install, key concepts and how-to pages with ASD-STE100 lint.
- Changelog sidebar showed six releases with no path to the full GitHub releases list.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| (A) Move architecture into `docs-site/content-map.mjs` as site-owned Markdown, redirect the old URL, trim changelog to five releases plus an external All releases link | One canonical page. STE lint applies. Old URLs still resolve. | Marketing copy about the five-layer model is retired from the root page. |
| (B) Keep `/architecture.html` and link to it from docs | No redirect work. | Two stories. Docs lint does not cover the root page. |
| (C) Delete `/architecture` with no redirect | Less surface. | Breaks bookmarks and agent manifests. |

## Decision

Chosen: **A**.

1. Add `quickstart/architecture` with a Keel-centred diagram and site-owned STE text.
2. Replace install page text with Homebrew / npx / `/setup` steps (no coming callout).
3. Set changelog `releases: 5` and append `{ label: 'All releases', link: … }` in `astro.config.mjs` without adding a nav.json page.
4. Replace root `architecture.html` and `architecture.md.gen` with a redirect / pointer; Netlify 301 `/architecture` to the docs path; drop the sitemap entry; retarget site and agent links.

## Consequences

- `/architecture` becomes a 301 to `/docs/quickstart/architecture`.
- The old five-layer narrative is no longer the public architecture page.
- Changelog badge count stays at the number of release pages (5). The All releases item is sidebar-only.

## Artifacts

- `docs-site/content-map.mjs`
- `docs-site/astro.config.mjs`
- `docs-site/public/img/keel-architecture.svg`
- `docs-site/src/pages/index.astro`
- `architecture.html`
- `architecture.md.gen`
- `_redirects`
- `sitemap.xml`
