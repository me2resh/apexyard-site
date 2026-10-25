# AgDR-0006: Generate /docs with Astro Starlight from a pinned framework tag

- **Status:** Proposed
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-107, AgDR-0005

## Context

The site needs a documentation section at `/docs`. The source text lives in `me2resh/apexyard`. Hand-copied pages drift from the framework. The site is static HTML on S3 and CloudFront, with no root build step. The CloudFront function maps an extensionless path to `<path>.html`.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| A. Astro Starlight sub-build in `docs-site/` | Static output. Built-in static search (Pagefind), collapsible sidebar, "On this page", skip link, theme control and mobile menu. Small vanilla scripts, no client framework. | A Node toolchain for one folder. The default look needs overrides. |
| B. Own Node generator (Markdown to HTML templates) | Full control. No framework. | Search, navigation, table of contents and accessibility work must be built and tested by hand. |
| C. Hand-written HTML pages | No toolchain. | Copies of the source text drift. 170 pages is too many to keep in sync. |

## Decision

Option A.

1. `docs-site/` is a separate Node package. The root site keeps no build step.
2. `scripts/sync-content.mjs` reads `me2resh/apexyard` at the tag and commit in `content-map.mjs`. It fails when the tag moves or a mapped heading is missing.
3. `content-map.mjs` holds structure only. Page text comes from the source at build time.
4. `build.format: 'file'` writes `a/b.html`, which matches the CloudFront rule. The docs home becomes `/docs.html`.
5. The build excludes internal folders and any page that names a paid component, a price or a private repository. The private term list stays outside the repository (`DOCS_PRIVATE_TERMS`).
6. `scripts/check-output.mjs` checks page counts, internal links and anchors, exclusions and page parts. `tests/contrast.test.mjs` checks the token contrast.

## Consequences

- A framework release needs a one-line change to `SOURCE.tag` and `SOURCE.commit`, then a build.
- The staging deploy needs one step that runs `.github/scripts/build-docs.sh` and uploads its output. That step goes into the staging workflow after GH-102 merges.
- The `/docs` URL moves from the developer guide page of GH-102 to the docs home. Old `/docs#anchor` links go to the matching new page.
