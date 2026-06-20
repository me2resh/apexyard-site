# apexyard-site

The ApexYard marketing and docs site — static HTML, deployed on Netlify at [yard.apexscript.com](https://yard.apexscript.com).

## What's here

Hand-authored HTML pages (`index.html`, `architecture.html`, `skills.html`, `how-it-works.html`, `game.html`) plus Markdown alternates (`.md.gen` files) served as clean `/foo.md` routes for AI agents and tooling that prefer low-token plain text over full HTML. Supporting assets: `_headers`, `_redirects`, `netlify.toml`, `robots.txt`, `sitemap.xml`, `llms.txt`, `llms-full.txt`.

## How it deploys

Native Netlify git deploy — push to `main` triggers a deploy automatically. No build step. Publish directory is the repo root (Netlify default).

Security headers and the canonical 301 redirect from `apexyard.netlify.app` to `yard.apexscript.com` are set in `netlify.toml`. Markdown-alternate `Link:` response headers and MIME types are in `_headers`. Clean-URL rewrites and markdown-alternate rewrites are in `_redirects`.

## Manually maintained content

The hard-coded counts in `index.html` (number of skills, hooks, and agents) are updated by hand on each ApexYard framework release. A cross-repo CI drift-guard that used to keep them honest lives in the apexyard framework repo and cannot run across repos — so refresh these numbers when cutting a new framework release.

## CI

`.github/workflows/link-check.yml` runs lychee on every PR and weekly to catch broken links in HTML and Markdown files.
