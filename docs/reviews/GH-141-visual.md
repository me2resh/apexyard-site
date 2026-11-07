# GH-141 visual verification and fixes

Rendered in Chrome with a local harness. Each page loaded in an iframe of exact
width (1440 px and 390 px) from a local static server. The reference design was
served on a second port for side-by-side comparison.

## What was checked

Pages: index, how-it-works, build, gate, readiness, pricing, skills, creators,
waitlist, previews and 404, at 1440 px and 390 px.

- Layout and visual comparison with the reference design.
- Sideways scroll (document width against viewport) at both widths.
- Tap targets at 390 px (all links, buttons and inputs).
- Contrast (computed text against effective background, light theme).
- Broken images, and every local asset reference on disk.
- Behaviour: mobile menu with JS (open, Escape closes) and without JS, theme
  toggle, waitlist validation and error summary, claims attributes and
  data-claim-off text on pricing, copy-for-ai button, staging-only reveal
  (staging-only.js injected by hand, as product.js only loads it on
  staging.apexyard.ai), skills search, Keel animation and pause button.
- Dark theme spot check on the home page.

## What was fixed

site.css
- Home ledger: old `.plan` rule from product.css gave the ledger a light
  background, so white labels vanished. Fixed in product.css (see below).
- Ledger step names (`.cond__name`) were dark on dark: `.t-dark` only remapped
  tokens for `.sec.t-dark`. `.t-dark` now remaps them everywhere.
- Install tabs: the command block rendered as an empty light box (old
  `.tabs pre` background). Now transparent with light text.
- Cookie banner: message text was grey on graphite. Now light text; Accept is
  the primary blue.
- Legacy reference pages (how-it-works, skills, 404) were squeezed into a
  narrow column by the old `main` rule. `main#main` is now full width.
  Legacy headings use the display face; label, body and aside sizes raised;
  intro and outro headings enlarged; skills contents links are 44 px.
- Legacy footer strip below the new footer is now part of the dark footer
  (it kept the unique "play the game" link). 404 footer and nav link
  underlines from its inline styles removed; 404 content has side padding
  on mobile.
- Creators: kit rows were each a nested `.sec` with their own rails, giving
  boxed, ghosted text and invisible headings. They are plain rows in one dark
  section now (creators.html).
- Waitlist: radio chips had a double border and 20 px inputs; the hidden input
  now covers the whole chip (44 px target).
- Header: the Theme toggle is a 44 px key with a half-moon icon, so the mobile
  header stays on one row (brand, demo, menu, theme). Old 146 px brand
  minimum removed.
- No-JS mobile: the nav was squeezed into the header row. It now wraps on its
  own row with 44 px links.
- Tap targets at 390 px: `Copy commands` (40 px) is 44 px; the footer and
  cookie "me2resh" and "Privacy" links get a 44 px hit area.
- Contrast: link and label blue on light grounds now uses the darker
  `--primary-edge` (brand, accent); Warn, Pass and error inks darkened;
  `.t-dark` scope keeps the light blue. Hint and muted text use `--muted`.
- Dark theme: designed dark panels keep their own palette; key faces get dark
  values in dark theme; hard-coded hint colour removed.

product.css
- `.plan` rules scoped to `.plans .plan` so they no longer hit the home ledger.

how-it-works.html, skills.html
- Removed a stray text node (" ApexScript.") after the legacy footer.

creators.html
- Kit rows lose the `sec`/`t-*`/`data-side`, join and rail markup.

404.html
- `main` gets class `nf` for its padding; stray text node removed.

## Results

- No sideways scroll on any page at 390 px or 1440 px.
- No control under 44 px height at 390 px on any page (inline text links are
  44 px tall hit areas).
- No broken images. All local asset references exist (`/docs/...` is built by
  the docs site; `/skills.md` is served by a redirect).
- Contrast: no failing text pair left in the light theme (the checker mis-reads
  `color-mix` backgrounds on the pricing table; those were checked by eye).
- Test suite: 19 of 20 pass. Only test-preview-workflows.sh fails (baseline).

## Still off

- docs (native Astro landing) was NOT rendered. `docs-site` has no
  node_modules and no network install was done. Its CSS and footer are
  unverified visually.
- how-it-works, skills and 404 keep their old inline structure with the new
  tokens. They read well but do not match the design's page-head, timeline
  strip and big section headings. Build, gate, readiness and previews still
  use the old product mock components, not the design's built-in screens.
- Home: a second small caption ("A team setup: ticket and named approval must
  pass.") shows under the ledger and repeats the panel footer text.
- Dark theme is only spot-checked on the home page. Other dark pages not
  reviewed.
- Mobile inline links are 44 px tall inline-flex, so paragraph line spacing
  grows where links sit in text (creators facts, readiness notes).
- Pricing: "Price to follow." appears twice in the Team price cell (a
  placeholder note plus the value). This came from the content port, not CSS.
- Pixel parity with the design was not attempted.
