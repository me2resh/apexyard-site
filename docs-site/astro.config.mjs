// Astro + Starlight config for the /docs sub-build.
//
// The content and the sidebar come from src/generated/nav.json, which
// scripts/sync-content.mjs writes from the pinned framework tag.
//
// Output shape: build.format 'file' writes /docs/a/b as dist/a/b.html. The
// CloudFront function maps an extensionless path to `<path>.html`, so the
// pages resolve without a trailing slash. The docs home is dist/index.html.
// The deploy step publishes it as /docs.html, which serves /docs.

import fs from 'node:fs';
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const nav = JSON.parse(fs.readFileSync(new URL('./src/generated/nav.json', import.meta.url), 'utf8'));

const sidebar = nav.sections.map((section) => ({
  label: section.title,
  items: section.groups.map((group) => ({
    label: group.title,
    collapsed: group.collapsed,
    badge: { text: String(group.pages.length), class: 'sl-count' },
    items: group.pages.map((page) => ({
      label: page.title,
      slug: page.slug,
      ...(page.coming ? { badge: { text: 'Coming', class: 'sl-coming' } } : {}),
    })),
  })),
}));

export default defineConfig({
  site: 'https://apexyard.ai',
  base: '/docs',
  trailingSlash: 'never',
  build: { format: 'file' },
  integrations: [
    starlight({
      title: 'ApexYard docs',
      description: 'Learn the ApexYard workflow, then look up each skill, hook, rule and setting.',
      favicon: '/favicon.svg',
      customCss: ['./src/styles/tokens.css', './src/styles/docs.css'],
      pagefind: true,
      lastUpdated: false,
      pagination: true,
      disable404Route: true,
      sidebar,
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
      components: {
        Header: './src/components/Header.astro',
        PageTitle: './src/components/PageTitle.astro',
        Footer: './src/components/Footer.astro',
        MobileMenuFooter: './src/components/MobileMenuFooter.astro',
      },
      head: [
        { tag: 'script', attrs: { src: '/copy-for-ai.js', defer: true } },
        { tag: 'meta', attrs: { name: 'theme-color', content: '#14213D' } },
      ],
      expressiveCode: {
        themes: ['github-dark-default', 'github-light-default'],
        styleOverrides: {
          borderRadius: '6px',
          borderColor: 'var(--ay-rule)',
          codeFontFamily: 'var(--ay-font-mono)',
          uiFontFamily: 'var(--ay-font-text)',
          codeFontSize: '0.875rem',
        },
      },
    }),
  ],
});
