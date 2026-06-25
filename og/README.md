# Open Graph images

Four 1200×630 share-preview PNGs referenced from the `<meta property="og:image">` and `<meta name="twitter:image">` tags in `{index,architecture,skills,game}.html`. Served at `https://yard.apexscript.com/og/<page>.png`.

| File | Page it backs | Purpose |
|------|---------------|---------|
| `index.png` | `index.html` | Hero banner — product name + tagline + the live component-count footer |
| `architecture.png` | `architecture.html` | The 5-layer architecture model |
| `skills.png` | `skills.html` | Skills-focused — a sample of slash commands + the skill count |
| `game.png` | `game.html` ("You vs. the LLM") | The game intro — 11 topic chips + CTA |

All four are 1200×630, kept under 200 KB (LinkedIn + Slack truncate large images).

## Scriptable regeneration (no hand-work)

The cards are now generated from HTML templates by a reproducible pipeline — **do not hand-edit the PNGs**. To regenerate:

```bash
cd og
npm install playwright           # one-time; render.sh expects playwright locally
npx playwright install chromium  # one-time; downloads the browser
brew install pngquant            # one-time
./render.sh
```

`render.sh`:

1. **Derives the framework-only component counts** from the apexyard ops-fork's `main` ref (released), excluding premium-injected items:
   - **roles**: tracked `*.md` under `roles/` minus `README.md` minus the premium `roles/growth/*` pack
   - **skills**: skill dirs (those carrying a `SKILL.md`) under `.claude/skills/` — premium skills are never committed to the framework `main`, so this is framework-only by construction
   - **hooks**: top-level `*.sh` in `.claude/hooks/` excluding `_lib*` helpers and the `tests/` subdir
   - Override the repo path with `APEXYARD_REPO=…`, the ref with `APEXYARD_REF=…` (default `main`), or hard-pin with `ROLES= SKILLS= HOOKS=`.
2. Substitutes the counts into the `{{ROLES}}/{{SKILLS}}/{{HOOKS}}` placeholders (the committed templates stay count-agnostic).
3. Renders each `templates/<card>.html` to a 1200×630 PNG via headless Chromium (`render.js`).
4. Optimises with `pngquant --quality=70-90` and verifies every card is exactly 1200×630 and < 200 KB.

`templates/_base.css` carries the shared Swiss Graphite tokens; each `templates/<card>.html` is the per-card layout. Both the templates **and** the rendered PNGs are committed.

## Design tokens — Swiss Graphite (LIGHT theme, for future regeneration)

Canonical source: the apexyard design-system `tokens.css` `[data-theme="light"]` block. The cards use the **light** variant of the locked ecosystem design.

| Token | Value | Use |
|-------|-------|-----|
| canvas `--bg` | `#f7f9fc` | card background (with a faint dot grid) |
| surface | `#ffffff` / `#fcfdff` | chips, layer rows |
| border | `#e2e7ef` / `#dde3ec` | hairlines, chip outlines |
| ink | `#14181f` | primary text / headlines |
| ink-2 | `#3a4452` | secondary text |
| muted | `#5c6986` | tertiary / eyebrow text |
| faint | `#9aa4b4` | quietest text |
| **accent** | `#2f6df6` | the canonical Swiss Graphite electric blue |
| accent-soft | `rgba(47,109,246,0.10)` | soft-accent chip fills |
| ok / warn / danger / violet | `#2f9e5e` / `#f5a524` / `#e5484d` / `#283593` | status dots on the game chips |

**Type** (Google Fonts webfonts, embedded via `@import` in `_base.css`; system fallbacks if offline):

- **Archivo** (600/700/800) — display / headlines / wordmark
- **Inter** (400/500/600) — UI / body
- **IBM Plex Mono** (500/600) — mono / counts / eyebrow rows

**Aesthetic**: clean, modern Swiss — generous whitespace, sharp-but-not-brutalist, no heavy gradients, a single accent, a faint dot grid for quiet texture and a hairline inset frame.

> Replaced the prior terminal-brutalist look (cream `#F4EFE6` / red `#C8321A` / JetBrains Mono) shipped via #341. Swiss Graphite cards land ahead of the site pages themselves — a full page re-skin to Swiss Graphite is a separate follow-up.
