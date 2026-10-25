#!/usr/bin/env node
// Local preview of the whole site with the docs sub-build mounted at /docs.
//
// The URL rules match the CloudFront function of the site:
//   - a path with a file extension is served as is;
//   - an extensionless path gets ".html" (a trailing slash is dropped first);
//   - "/" serves index.html.
// The docs home is dist/index.html. The deploy publishes it as /docs.html.
//
// Usage: node scripts/serve.mjs [port]     (default 4321, binds 127.0.0.1)

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SITE = path.resolve(ROOT, '..');
const DIST = path.join(ROOT, 'dist');
const PORT = Number(process.argv[2] || 4321);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.md': 'text/markdown; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml',
  '.wasm': 'application/wasm',
  '.pf_meta': 'application/octet-stream',
  '.pf_index': 'application/octet-stream',
  '.pf_fragment': 'application/octet-stream',
  '.pagefind': 'application/octet-stream',
};

function resolve(urlPath) {
  let p = decodeURIComponent(urlPath.split('?')[0]);
  if (p === '/docs' || p === '/docs/') return path.join(DIST, 'index.html');
  if (p.length > 1 && p.endsWith('/')) p = p.slice(0, -1);
  if (p === '' || p === '/') p = '/index';
  if (!/\.[a-zA-Z0-9_]+$/.test(p)) p += '.html';
  const base = p.startsWith('/docs/') ? DIST : SITE;
  const rel = p.startsWith('/docs/') ? p.slice('/docs/'.length) : p.slice(1);
  const file = path.resolve(base, rel);
  if (!file.startsWith(base + path.sep)) return null;
  // Never serve the internal repo docs/ folder or dot paths from the site root.
  if (base === SITE && (rel.startsWith('docs/') || rel.startsWith('.') || rel.startsWith('docs-site/'))) return null;
  return file;
}

http
  .createServer((req, res) => {
    const file = resolve(req.url || '/');
    if (!file || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('Not found');
      return;
    }
    const type = TYPES[path.extname(file)] || 'application/octet-stream';
    // CloudFront compresses text responses. Do the same so local audits match.
    const gzip = /text|javascript|json|svg|xml/.test(type) && /gzip/.test(req.headers['accept-encoding'] || '');
    res.writeHead(200, { 'content-type': type, ...(gzip ? { 'content-encoding': 'gzip' } : {}) });
    const stream = fs.createReadStream(file);
    (gzip ? stream.pipe(zlib.createGzip()) : stream).pipe(res);
  })
  .listen(PORT, '127.0.0.1', () => console.log(`preview: http://127.0.0.1:${PORT}/docs`));
