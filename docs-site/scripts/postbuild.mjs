#!/usr/bin/env node
// Clean the built HTML.
// build.format 'file' makes Astro write links as /docs/a/b.html. The site
// serves /docs/a/b, so this step removes the .html suffix from docs links,
// the canonical URL and og:url. The 404 route of Starlight is not used.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'dist');

function* htmlFiles(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* htmlFiles(p);
    else if (e.name.endsWith('.html')) yield p;
  }
}

let n = 0;
for (const file of htmlFiles(DIST)) {
  const before = fs.readFileSync(file, 'utf8');
  const after = before
    .replace(/((?:href|content)=")((?:https:\/\/apexyard\.ai)?\/docs\/[^"#?]*?)(?:\/index)?\.html(?=["#?])/g, '$1$2')
    .replace(/((?:href|content)=")(https:\/\/apexyard\.ai)?\/docs\/index(?=["#?])/g, '$1$2/docs');
  if (after !== before) {
    fs.writeFileSync(file, after);
    n++;
  }
}
fs.rmSync(path.join(DIST, '404.html'), { force: true });
console.log(`postbuild: cleaned links in ${n} files`);
