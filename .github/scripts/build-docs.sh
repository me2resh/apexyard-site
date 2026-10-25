#!/usr/bin/env bash
# Build the /docs sub-build and stage it for upload.
#
# Usage: .github/scripts/build-docs.sh <out-dir>
#
# Writes:
#   <out-dir>/docs.html   the docs home (CloudFront serves /docs from it)
#   <out-dir>/docs/...    every other docs file (pages, .md copies, search index)
#
# The deploy uploads <out-dir>/docs to s3://<bucket>/docs with --delete, then
# copies docs.html to the bucket root. The site sync must keep its
# --exclude "docs/*" so it does not upload the internal docs/ folder.
set -euo pipefail

out="${1:?usage: build-docs.sh <out-dir>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$root/docs-site"
npm ci --no-audit --no-fund
npm run build
npm run check

rm -rf "$out/docs" "$out/docs.html"
mkdir -p "$out/docs"
cp -R dist/. "$out/docs/"
mv "$out/docs/index.html" "$out/docs.html"
node scripts/check-layout.mjs "$out"
echo "build-docs: staged $(find "$out/docs" -name '*.html' | wc -l | tr -d ' ') pages in $out"
