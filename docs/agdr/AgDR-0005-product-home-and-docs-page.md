# AgDR-0005: Product home page for buyers, developer material under /docs

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-102, AgDR-0004

## Context

The site v2 home page kept the terminal and README look of the framework site and added three plan cards. The owner reviewed it and said it does not read as a product site. The buyer is a team lead or a CTO. The developer material (the gate replay, the hooks, the terminal walkthrough, the toolbox) must stay, and its URLs must keep working.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| A. New product home page, old home page content moves to `/docs` | Each page has one reader. Nothing is deleted. | Old `/#anchor` links need a redirect. |
| B. Restyle the old home page in place | One page. | The page stays long and mixes two readers. |
| C. Separate product domain | Clean split. | New DNS, a new distribution, and an infrastructure change. |

## Decision

Option A.

1. `index.html` is the product page. It uses `product.css` and `product.js`, Archivo for text and IBM Plex Mono for code only, and one brand colour.
2. `docs.html` holds the previous home page content without the plan cards and the Team section. Those now live on the home page and on `pricing.html`.
3. `product.js` sends an old home anchor (for example `/#the-rules`) to the same anchor on `/docs`. It sends `/#paths`, `/#commercial` and `/#demo` to `/pricing`.
4. Product images are real captures or marked slots. A slot names the file to add and its alt text. The page never shows a drawn copy of the product UI.
5. Proof numbers come from data: the GitHub search API, the release tag (checked by `verify-counts.sh`), and a live star count that stays hidden when the API call fails.
6. The `PLAN_HINT` token joins the overlay token list in AgDR-0004.
7. `preview-build.yml` also triggers on `product.css`, `product.js` and `img/**`. `link-check.yml` excludes the clean `/docs` URL, as it does for the other pages.

## Consequences

- A visitor with JavaScript off who follows an old `/#anchor` link lands at the top of the home page.
- The developer pages (`/docs`, `/architecture`, `/skills`, `/how-it-works`, `/game`) keep the framework look. The product pages use the new look.
- The owner must add the screenshots for the marked slots before the page leaves staging.

## Artifacts

- Ticket: GH-102
- Pages: `index.html`, `pricing.html`, `docs.html`
- Assets: `product.css`, `product.js`, `img/check-pr9.webp`
