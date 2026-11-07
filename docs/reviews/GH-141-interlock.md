# GH-141 Interlock staging review

Implemented locally on feature/GH-141-interlock-staging. No network, commit,
push, production configuration change, or workflow change.

## Acceptance criteria

1. Visual port: implemented across index, how-it-works, build, gate, readiness,
   pricing, skills, creators, waitlist, previews, and 404. The native docs
   landing retains its generated navigation and receives the reading layout,
   typography, palette, and mark. Staging sections remain the content authority.
   The home example uses the design's interactive interlock. Skills gain its
   search interaction. Reference pages retain their complete staging content,
   rather than the design export's abbreviated content. Pixel parity and a
   complete visual sign-off are not verified.
2. Existing functionality: preserved the claims, waitlist, site configuration,
   staging-only blocks, copy controls, and current Keel loop. The existing
   product script owns the menu, tabs, mail links, theme, and consent; duplicate
   handlers were removed from the imported design script. Header navigation
   stays visible without scripts. All original root-page links survive.
   Markdown alternates and both agent manifests are unchanged because their
   facts are unchanged and no HTML-reading generator was found for them.
   Headers, redirects, and deployment workflows are unchanged.
3. Shared files: site.css and site.js contain the imported design and staging
   integration. The family tokens are at the top of site.css. product.css and
   product.js remain referenced as compatibility support for existing screens
   and behavior, including contracts exercised by the shell tests.
4. Footer: ApexScript, with no company suffix or number, appears on every
   ported root page and the native docs footer.
5. Fonts: link and preconnect loading replaces font imports. The existing
   ancillary download pages and share-card templates use links too.
6. Phone: responsive menu fallback and 44 px controls are implemented. Actual
   390 px overflow, target measurements, and menu interaction are UNVERIFIED.
7. Production deployment: configuration and workflows are untouched.

## Staging facts reconciled

- Current counts: 20 roles, 69 skills, 23 agents, 66 hooks. Preserve the live
  star and fork badge links; do not use the design's count placeholders.
- Keep the current home promise, risk question, supported-agent sentence,
  sign-in/waitlist attributes, plan hint, CTA row, and fine print.
- Keep the exact current server-fetch claim and application-access explanation,
  including its detailed Gate link. Do not restore stronger access claims.
- Keep the empty customer-story preview, its label, and its staging-only hidden
  contract; no customer or quote has been inserted.
- Keep all five current Keel explanations, page highlights, pause control,
  approval of a drafted rule, and the current animation script.
- Preserve live/coming claim keys and fallback copy, including evidence export,
  shared Keel, versions, scheduled audits, scores, CI, trends, and desktop app.
- Keep the real Readiness report and findings unchanged. Preserve the fictional
  report and CI figures with their existing Example and sample labels.
- Preserve the fictional pull request, warning versus blocking conditions,
  named approval, timestamp, commit, and complete accessible transcript.
- Preserve Build review sizes, handover/scaffold commands, default merge
  explanation, free/open-source wording, and shared paid-plan explanation.
- Preserve current install commands and the <new-private-repo> placeholder,
  including organization and private-repository arguments and copy targets.
- Keep both pricing tables, plan names, limits, comparisons, service tiers,
  placeholder labels, and every overlay marker. Monetary dummy values become
  "Price to follow". The engineer and repository placeholders survive.
- Keep waitlist questions, field IDs, error regions, fallback, and endpoint
  configuration. The design's separate demo form handler is not used.
- Keep every skill description, argument, category, anchor, and copy-as-Markdown
  link. Only punctuation is normalized to ASCII.
- Keep preview indexing restrictions and staging-only visibility, architecture
  redirects, existing ancillary links, and native docs navigation and counts.
- Keep footer author attribution and open-source licence facts, adding the
  required ApexScript owner name.

A normalized visible-text audit against the original eleven root pages found
no lost text facts. The intentional exception is the removal of monetary dummy
values. A separate link audit found zero missing destinations and zero duplicate
IDs across those pages.

## Validation

- Shell suite: 19 of 20 scripts pass. The pre-existing failure remains:
  test-preview-workflows.sh, "deploy-production needs approve-production".
  Baseline and final results match. Workflow structure checks that require the
  unavailable YAML module report a skip.
- Native docs unit tests: 60 pass, including all 56 contrast checks.
- Syntax: site.js and docs-site/astro.config.mjs pass node --check.
- Whitespace: git diff --check passes.
- ASCII: site.css, site.js, and every added tracked diff line pass.
- Font grep: `rg -n '@import' --glob '*.css' --glob '*.html'` returns no matches.
- Browser verification stopped when the local preview server failed with:
  `PermissionError: [Errno 1] Operation not permitted`.
  No alternative server or browser route was attempted.
- Full docs build and screenshot verification were not run. Build dependencies
  are not installed locally and this run has no network.

## Owner steps

Review all pages at desktop and 390 px in an environment that permits a local
preview. Check no-script navigation, theme, interlock, tabs and copy controls,
Keel pause, waitlist validation, staging-only blocks, and sideways overflow.
Build the native docs with its existing dependencies and review its landing,
search, and navigation. Then handle the staging PR and deployment separately.
No page was skipped, but visual completion remains pending that review.
