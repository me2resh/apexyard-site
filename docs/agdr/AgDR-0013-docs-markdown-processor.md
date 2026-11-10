# AgDR-0013: Docs keep the unified Markdown processor after the astro 7 upgrade

- **Status:** Accepted
- **Date:** 2026-11-10
- **Decision owners:** ApexYard maintainers
- **Related:** GH-150, AgDR-0006, AgDR-0008

> In the context of the docs sub-build upgrade from astro 5 to astro 7, facing a new default Markdown processor that renders `--` as an en dash and changes some curly quotes, I decided to add `@astrojs/markdown-remark` as a pinned direct dependency and select its unified processor, to keep the typography that the docs had on astro 5, accepting one more pin that must move with astro.

## Context

- Astro 5.18.2 has a critical advisory (GHSA-26w7-cxv4-gfx2). No 5.x release fixes it, so the docs sub-build moves to astro 7.4.8 (GH-150).
- Astro 7 uses a new default Markdown processor. It renders `--` as an en dash and has no setting for an em dash. It also changed three curly-quote cases. 30 of 177 built pages had different visible text.
- The owner does not accept the en dash. The docs text must stay as it was.
- Astro 5 used the unified (remark) pipeline from `@astrojs/markdown-remark` internally. Astro 7 still supports it through `markdown: { processor: unified() }`. Starlight 0.42.10 lists the package as a supported peer.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| (A) Add `@astrojs/markdown-remark` 7.3.6, pinned, and set `markdown: { processor: unified() }` | The visible text of all 177 pages matches the astro 5 build. Official astro package. The same pipeline as before. | One more direct dependency. Its pin must move with each astro upgrade. |
| (B) Keep the new default processor and accept the en dash | No new dependency. | Changes the text of 30 pages. The owner rejected it. |
| (C) Replace dashes in the built HTML with a postbuild script | No new dependency. | A regex on HTML can change code blocks and attributes. It hides the real cause. |
| (D) Change `--` to an em dash in the synced framework content | No new dependency. | The content belongs to the framework repository. Each sync would bring the problem back. |

## Decision

Chosen: **A**, because it is the only option that restores the exact text without changing the content or the built HTML.

1. `docs-site/package.json` pins `@astrojs/markdown-remark` to 7.3.6.
2. `docs-site/astro.config.mjs` sets `markdown: { processor: unified() }`.

## Consequences

- The docs keep their em dashes, curly quotes, apostrophes and ellipses.
- Each astro upgrade must also move this pin to the version that astro and Starlight accept. `npm install` reports a peer conflict when the two drift.
- If a later astro release drops the unified processor, this decision needs a new review.

## Artifacts

- GH-150
- `docs-site/package.json`
- `docs-site/astro.config.mjs`
