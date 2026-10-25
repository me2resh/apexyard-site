# docs-site

The `/docs` section of the site. Astro Starlight builds it from `me2resh/apexyard` at the tag pinned in `content-map.mjs`. See `docs/agdr/AgDR-0006-docs-sub-build.md`.

## Commands

```bash
cd docs-site
npm ci
npm run build      # sync the source, build, clean links
npm run check      # page counts, links, exclusions, page parts, contrast
npm run preview    # http://127.0.0.1:4321/docs with the site root mounted
```

- Set `APEXYARD_REPO=/path/to/apexyard` to read the tag from a local clone instead of GitHub.
- Set `DOCS_PRIVATE_TERMS=/path/outside/repo.txt` to add private names to the exclusion check. Keep that file out of this repository.

## Update to a new framework release

1. Change `SOURCE.tag` and `SOURCE.commit` in `content-map.mjs`.
2. Run `npm run build` and `npm run check`.
3. Fix each mapped heading that the build reports as missing.
