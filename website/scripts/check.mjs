import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import path from 'node:path';
import { output, root } from './build.mjs';
import { routes, renderPage } from '../src/pages.js';
import { links, site } from '../src/config.js';

const pages = new Map();
const approvedDestinations = new Set([links.github, links.issues, links.privacyEmail, ...routes.map(route => site.origin + (route === '/' ? '/' : route + '/'))]);
for (const route of routes) {
  pages.set(route, await readFile(path.join(output, route.slice(1), 'index.html'), 'utf8'));
}
pages.set('/404', await readFile(path.join(output, '404.html'), 'utf8'));
const titles = new Set();
for (const [route, html] of pages) {
  const title = html.match(/<title>(.*?)<\/title>/)[1];
  assert(!titles.has(title), `${route}: unique page title`);
  titles.add(title);
  assert(html.includes('<html lang="en">') && html.includes('class="skip-link"'));
  assert(html.includes('rel="apple-touch-icon"'));
  assert.equal((html.match(/<h1[ >]/g) ?? []).length, 1, `${route}: one main heading`);
  assert(html.includes('<nav') && html.includes('<footer') && html.includes('id="main"'));
  assert(html.includes('Lumaunt is not affiliated with or endorsed by Discord.'));
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length, `${route}: unique anchors`);
  for (const [, href] of html.matchAll(/(?:href|src)="([^"\s]+)"/g)) {
    assert.notEqual(href, '#', `${route}: no dead anchor placeholder`);
    if (href.startsWith('#')) {
      assert(html.includes(`id="${href.slice(1)}"`), `${route}: same-document anchor ${href}`);
      continue;
    }
    if (/^(https:|mailto:)/.test(href)) {
      assert(approvedDestinations.has(href), `${route}: approved external destination`);
      continue;
    }
    const url = new URL(href, site.origin + (route === '/' ? '/' : route + '/'));
    let target = path.join(output, url.pathname.slice(1));
    if (!path.extname(url.pathname)) target = path.join(target, 'index.html');
    await access(target);
    if (url.hash) {
      const targetHtml = await readFile(target, 'utf8');
      assert(targetHtml.includes(`id="${url.hash.slice(1)}"`), `${route}: anchor ${href}`);
    }
  }
  for (const [, src] of html.matchAll(/<script[^>]*src="([^"]+)"/g)) {
    assert(src.startsWith('/') && !src.startsWith('//'), `${route}: only local scripts`);
  }
  assert(!/api\.lumaunt\.app|<iframe|google-analytics|googletagmanager|connect\.facebook|<form/i.test(html));
  assert(html.includes('href="/#features"') && html.includes(`href="${links.github}"`));
  assert(html.includes('property="og:image"') && html.includes('name="twitter:card"'));
  assert(!/Windows (?:download|available now)|Download for Windows/i.test(html));
}
const notFound = pages.get('/404');
assert(notFound.includes('Page not found.') && notFound.includes('Back to Home'));
assert(notFound.includes('content="noindex, follow"') && !notFound.includes('rel="canonical"'));
const privacyContents = pages.get('/privacy').match(/<nav class="legal-toc"[\s\S]*?<\/nav>/)[0];
assert.equal((privacyContents.match(/<a /g) ?? []).length, 8, 'Compact privacy navigation');
assert(!/Discord credentials|moderation-system improvement and checking/.test(pages.get('/privacy')));
assert(pages.get('/privacy').includes('cannot guarantee that accidental sensitive-data transmission'));
const home = pages.get('/');
assert(home.includes('src="/images/lumaunt-app.png" width="2048" height="1194"'));
assert(home.includes('src="/images/lumaunt-discord-preview.png" width="810" height="324"'));
assert.equal((home.match(/data-showcase-image/g) ?? []).length, 2);
assert(home.includes('Make it yours.') && home.includes('Built with privacy'));
assert(home.includes('loading="lazy"'));
assert(pages.get('/download').includes('disabled>Coming soon</button>') || links.macOSDownload);
assert(links.macOSDownload === null || /^https:\/\//.test(links.macOSDownload), 'Download stays unavailable or uses an approved HTTPS artifact URL');
for (const route of ['/privacy', '/terms']) {
  assert(pages.get(route).includes('datetime="2026-10-03"'));
  assert(!/coming soon|lorem ipsum/i.test(pages.get(route)));
  assert(pages.get(route).includes(`href="${links.privacyEmail}"`));
}
assert(pages.get('/support').includes(`href="${links.issues}"`));
assert(pages.get('/privacy').includes('up to 90 days'));
assert(pages.get('/privacy').includes('no longer than 7 days'));
assert(pages.get('/privacy').includes('Sentry'));
// Screenshot absence remains an honest placeholder, including one missing asset.
for (const assets of [{}, { app: { width: 2048, height: 1194 } }, { discord: { width: 810, height: 324 } }]) {
  const html = renderPage('/', { assets });
  assert.equal((html.match(/data-showcase-image/g) ?? []).length, Object.keys(assets).length);
  assert(html.includes('Screenshot coming soon.'));
}
for (const source of ['public/navigation.js', 'public/image-fallback.js']) {
  const js = await readFile(path.join(root, source), 'utf8');
  assert(!/\bfetch\s*\(|XMLHttpRequest|sendBeacon|document\.cookie|localStorage|sessionStorage|https?:\/\//.test(js));
}
const css = await readFile(path.join(output, 'styles.css'), 'utf8');
assert(css.includes('prefers-reduced-motion: reduce') && css.includes(':focus-visible'));
await access(path.join(output, site.socialImage.slice(1)));
console.log('PASS: six routes + branded 404, compact policy navigation, anchors/assets, real screenshots and fallbacks, shared navigation, policy dates/retention, metadata, unavailable download, and no API/tracking integration.');

const authorization = pages.get('/auth/discord');
assert(authorization.includes('Continue in Lumaunt.') && authorization.includes('Once the app shows'));
assert(authorization.includes('content="noindex, follow"') && authorization.includes('content="no-referrer"'));
assert(!/lumaunt:\/\/|access_token|refresh_token|[?&]code=/.test(authorization));
assert(!(await readFile(path.join(output, 'sitemap.xml'), 'utf8')).includes('/auth/'));
