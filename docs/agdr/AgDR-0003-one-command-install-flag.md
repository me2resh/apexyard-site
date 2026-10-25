# AgDR-0003: One-command install content behind a default-off site flag

- **Status:** Accepted
- **Date:** 2026-10-25
- **Decision owners:** ApexYard maintainers
- **Related:** GH-100

## Context

The marketing site still documents the fork path (`gh repo fork`). A one-command install path (curl, Homebrew, npx, then `apexyard init`) is coming, but those commands are not live yet. Shipping the new copy without a gate would show install steps that fail for visitors.

`sitemap`, `llms.txt`, and `*.md.gen` stay on the fork path until the flag turns on.

## Decision

1. **Add `site-flags.js`** with `window.APEXYARD_FLAGS = { oneCommandInstall: false }`. On `localhost` / `127.0.0.1` only, `?oneCommandInstall=1` may force the flag on for local review.
2. **Load the flag early in `index.html` `<head>`.** An inline script sets `document.documentElement.dataset.oneCommandInstall = "on"` when the flag is true.
3. **Keep both markup trees in HTML.** New blocks use `data-flag="one-command-install"` (CSS-hidden by default). Old fork CTAs and the install-row use `data-flag-off="one-command-install"`. With the flag off, the live page matches today’s fork path.
4. **Do not restyle.** Reuse `.install`, `.install__copy`, `.section`, and `.step`. Add only minimal tablist structure CSS using existing tokens.
5. **Gate sitemap / llms / markdown alternates separately.** They stay on the fork path until the flag is turned on for production.

## Alternatives considered

- **Ship new copy immediately:** rejected. Commands are not available yet.
- **Separate preview page or branch-only HTML:** rejected. One HTML tree with a flag keeps review and cutover simple.
- **Build-time flag:** rejected. This site has no root build step.

## Consequences

- Production stays on the fork path until maintainers set `oneCommandInstall: true` in `site-flags.js`.
- Local preview: open `index.html` via a local server and append `?oneCommandInstall=1`.
- `.github/tests/test-install-flag.sh` locks the default-off contract and the “gated strings only inside data-flag blocks” rule.
- When the CLI ships, turn the flag on and update `llms.txt` / `*.md.gen` / sitemap in the same change set.
