import { links, site } from './config.js';
import { privacySections, termsSections } from './legal.js';

const escape = (value) => String(value).replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const sparkle = '<span class="sparkle" aria-hidden="true">✦</span>';
const icon = (name) => {
  const paths = {
    preview: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18M7 6.5h.01M10 6.5h.01M8 13h8M8 16h5"/>',
    image: '<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 6-6 5 5 3-3 4 4"/>',
    buttons: '<path d="M10 13a5 5 0 0 0 7 .2l3-3a5 5 0 0 0-7-7l-2 2M14 11a5 5 0 0 0-7-.2l-3 3a5 5 0 0 0 7 7l2-2"/>',
    timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l3 2M9 2h6M12 2v3M18 5l2 2"/>',
    presets: '<rect x="6" y="3" width="15" height="15" rx="3"/><path d="M3 7v11a3 3 0 0 0 3 3h11M10 8h7M10 12h4"/>',
    privacy: '<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',
    mac: '<rect x="4" y="3" width="16" height="13" rx="2"/><path d="M9 21h6M12 16v5"/>',
  };
  return `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name]}</svg>`;
};

function downloadButton() {
  return `<a class="button button-primary" href="/download/">${icon('mac')}Download for macOS</a>`;
}
function githubButton() {
  return `<a class="button button-secondary" href="${escape(links.github)}">View on GitHub</a>`;
}
function brand() {
  return '<a class="brand" href="/" aria-label="Lumaunt home"><img src="/images/lumaunt-icon.png" width="36" height="36" alt=""/><span>Lumaunt</span></a>';
}
function navLinks(path) {
  return [['Features', '/#features'], ['Download', '/download/'], ['Privacy', '/privacy/'], ['Support', '/support/']]
    .map(([label, href]) => `<a href="${href}"${path !== '/' && href === `${path}/` ? ' aria-current="page"' : ''}>${label}</a>`).join('');
}
function header(path) {
  return `<a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header"><div class="container header-inner">${brand()}
    <nav class="desktop-nav" aria-label="Main navigation">${navLinks(path)}</nav>
    <div class="header-cta">${downloadButton()}</div>
    <details class="mobile-menu"><summary>Menu<span aria-hidden="true">＋</span></summary><nav aria-label="Mobile navigation">${navLinks(path)}${downloadButton()}</nav></details>
  </div></header>`;
}
function footer() {
  return `<footer class="site-footer"><div class="container footer-top"><div>${brand()}<p>Built for Discord Rich Presence on macOS.</p></div>
  <nav aria-label="Footer navigation"><a href="/privacy/">Privacy</a><a href="/terms/">Terms</a><a href="/support/">Support</a><a href="${escape(links.github)}">GitHub</a></nav></div>
  <div class="container footer-bottom"><span>© ${new Date().getFullYear()} Lumaunt</span><span>Lumaunt is not affiliated with or endorsed by Discord.</span></div></footer>`;
}

function screenshotImage(asset, src, alt) {
  return asset ? `<img class="product-screenshot" src="${escape(src)}" width="${asset.width}" height="${asset.height}" alt="${escape(alt)}" loading="lazy" decoding="async" data-showcase-image/>` : '';
}
function screenshotPlaceholder(asset, label) {
  return `<div class="screenshot-placeholder"${asset ? ' hidden' : ''}><img src="/images/lumaunt-icon.png" width="88" height="88" alt=""/><p>${label}</p><span>Screenshot coming soon.</span></div>`;
}
function showcase(assets) {
  return `<section class="showcase container" aria-labelledby="showcase-title"><div class="section-intro"><span class="eyebrow">${sparkle} A closer look</span><h2 id="showcase-title">Your presence, in focus.</h2></div>
  <figure class="product-frame"><div class="frame-caption"><span class="window-dots" aria-hidden="true"><i></i><i></i><i></i></span><span>Lumaunt for macOS</span><span class="frame-sparkle" aria-hidden="true">✦</span></div>
  <div class="screenshot-area">${screenshotImage(assets.app, site.screenshot, 'Lumaunt for macOS showing the Presence editor and live Discord Rich Presence preview.')}${screenshotPlaceholder(assets.app, 'Meet Lumaunt.')}</div>
  <figcaption>A native workspace for your Discord Rich Presence.${assets.app ? `<a class="screenshot-link" href="${site.screenshot}">View full-size app screenshot</a>` : ''}</figcaption></figure></section>`;
}
function discordShowcase(assets) {
  return `<section class="discord-showcase container section-space" aria-labelledby="discord-title"><div class="discord-copy"><span class="eyebrow">${sparkle} From your Mac to Discord</span><h2 id="discord-title">Make it yours.<br/>See it on Discord.</h2><p>Build your presence in Lumaunt, preview it live, then apply it to Discord when you’re ready.</p><ol class="presence-flow"><li><span>01</span>Create in Lumaunt</li><li><span>02</span>Apply to Discord</li></ol></div>
  <figure class="discord-frame"><div class="screenshot-area">${screenshotImage(assets.discord, site.discordScreenshot, 'Discord Rich Presence created with Lumaunt, showing an image, status text, timer, and custom buttons.')}${screenshotPlaceholder(assets.discord, 'Your presence on Discord.')}</div><figcaption>The presence your friends see.${assets.discord ? `<a class="screenshot-link" href="${site.discordScreenshot}">View full-size Discord screenshot</a>` : ''}</figcaption></figure></section>`;
}

const features = [
  ['preview', 'Live Preview', 'See how your Rich Presence will look before applying it.', 'feature-wide'],
  ['image', 'Images & Hover Text', 'Use large and small images with customizable hover text.', 'feature-artwork'],
  ['buttons', 'Custom Buttons', 'Add links to your Rich Presence and arrange them the way you want.', ''],
  ['timer', 'Timers', 'Use elapsed time, countdowns, custom start times, and optional automatic presence disabling.', ''],
  ['presets', 'Presets', 'Save configurations and quickly return to your favorite setups.', ''],
  ['privacy', 'Privacy-Focused', "Sensitive Discord session credentials are stored in your Mac's Keychain. Hosted image uploads are optional, and crash reporting is opt-in.", 'feature-privacy'],
];
function featureSection() {
  return `<section class="features container section-space" id="features" aria-labelledby="features-title"><div class="section-heading"><div><span class="eyebrow">${sparkle} The details make it yours</span><h2 id="features-title">A little more you.</h2></div><p>Everything you need to shape your presence,<br class="desktop-break"/> in one native macOS app.</p></div>
  <div class="feature-grid">${features.map(([name, title, copy, style]) => `<article class="feature ${style}"><div class="feature-icon">${icon(name)}</div><div><h3>${title}</h3><p>${copy}</p></div>${style === 'feature-wide' ? '<span class="feature-sparkle" aria-hidden="true">✦</span>' : ''}</article>`).join('')}</div></section>`;
}
function home(assets) {
  return `<main id="main" tabindex="-1"><section class="hero container"><span class="eyebrow hero-eyebrow">${sparkle} Native to your Mac. Personal to you.</span><h1>Your Discord presence.<br/><span>Your way.</span></h1><p class="hero-description">Create beautiful, customizable Discord Rich Presences with images, buttons, timers, presets, and live previews.</p><div class="hero-actions">${downloadButton()}${githubButton()}</div></section>
  ${showcase(assets)}${featureSection()}${discordShowcase(assets)}
  <section class="local-first container section-space" aria-labelledby="local-title"><div class="local-mark" aria-hidden="true">${icon('privacy')}</div><div><span class="eyebrow">${sparkle} Yours by default</span><h2 id="local-title">Built with privacy<br/>in mind.</h2></div><div class="local-copy"><p>Sensitive Discord session credentials are stored in your Mac’s Keychain. Lumaunt connects directly to Discord and does not maintain a server-side Discord account database.</p><p>Hosted image uploads are optional. Choose 7, 30, or 90 days of managed retention, or manually delete managed images. Crash reporting stays off unless you enable it.</p><p>Presence text may be processed by moderation services when required by Lumaunt’s safety systems.</p><a class="text-link" href="/privacy/">Read the Privacy Policy</a></div></section>
  <section class="final-cta container" aria-labelledby="final-title"><div><span class="eyebrow">${sparkle} Your next presence</span><h2 id="final-title">Make your presence yours.</h2></div><div class="cta-actions">${downloadButton()}${githubButton()}</div></section></main>`;
}

export const routes = ['/', '/download', '/privacy', '/terms', '/support', '/auth/discord'];
const pageInfo = {
  '/auth/discord': ['Discord authorization', 'Return to Lumaunt after Discord authorization and check your connection status in the app.'],
  '/download': ['Download', 'A native macOS app for creating your Discord Rich Presence. Release download availability and the Lumaunt source repository.'],
  '/privacy': ['Privacy Policy', 'How Lumaunt handles Discord session credentials, moderation, optional hosted images, crash reporting, and technical information.'],
  '/terms': ['Terms of Use', 'Readable terms for using Lumaunt, publishing Rich Presence, and accessing its supporting services.'],
  '/404': ['Page not found', 'This page could not be found. Return to the Lumaunt homepage.'],
  '/support': ['Support', 'Help with Lumaunt installation, Discord connections, images, buttons, and timers. Report bugs or contact us about privacy.'],
};
function pageHeading(label, title, copy) {
  return `<div class="page-heading"><span class="eyebrow">${sparkle} ${label}</span><h1>${title}</h1><p class="page-description">${copy}</p></div>`;
}
function downloadPage() {
  return `<main id="main" tabindex="-1" class="content-page container">${pageHeading('Lumaunt for macOS', 'Your Mac. Your presence.', 'A native macOS application for creating and managing your Discord Rich Presence.')}
  <section class="download-panel" aria-labelledby="download-title"><div class="download-brand"><img src="/images/lumaunt-icon.png" width="88" height="88" alt=""/><div><h2 id="download-title">Lumaunt for macOS</h2><p>Images, buttons, timers, presets.<br/>One native workspace.</p></div></div><div class="download-actions">${links.macOSDownload ? `<a class="button button-primary" href="${escape(links.macOSDownload)}">${icon('mac')}Download for macOS</a>` : '<button class="button button-unavailable" type="button" disabled>Coming soon</button>'}${githubButton()}<p>${links.macOSDownload ? 'The macOS release is available using the download link above.' : 'The macOS release download will be added here when it’s ready.'}</p></div></section>
  <div class="download-notes"><p>Current platform: macOS. A Windows version is planned for later.</p><p>Explore the source on GitHub. Need a hand? Visit <a href="/support/">Support</a>.</p></div><a class="text-link" href="/">Back to Home</a></main>`;
}
const helpTopics = [
  ['Installation / launching', '<p>Use the macOS download on the Download page once a release is available. If Lumaunt will not launch, note the exact macOS message and report it on GitHub Issues. Do not disable system security protections to troubleshoot.</p>'],
  ['Connecting Discord', '<p>Use Connect in Lumaunt and complete Discord authorization. If a connection fails, record the visible error. Disconnect Account closes Lumaunt’s Discord connection and removes its saved login; use Connect again when you want to reconnect.</p>'],
  ['Presence not appearing', '<p>Check that Lumaunt shows Discord Connected, then apply your presence. The live preview shows your edits before publishing. Check any error displayed by Lumaunt and allow Discord time to reflect the update.</p>'],
  ['Images', '<p>Choose a local image or paste one from the clipboard in the image controls. Hosted uploads are optional and can be managed in the app’s privacy controls. An image that has expired or been deleted needs to be replaced or uploaded again before it can display.</p>'],
  ['Buttons', '<p>Check each button’s label and destination link, then apply your changes. You can reorder buttons in Lumaunt. If a button is missing or opens the wrong destination, include what you expected and what happened in your report.</p>'],
  ['Timers', '<p>Choose elapsed time or a countdown. Elapsed timers support a custom start time; countdowns can optionally disable presence when they end. If the timer behaves unexpectedly, include the mode and settings you used.</p>'],
  ['Privacy questions', `<p>See the <a href="/privacy/">Privacy Policy</a> for credential storage, moderation, managed image retention and deletion, and optional crash reporting. Send privacy requests to <a href="${links.privacyEmail}">privacy@lumaunt.app</a>.</p>`],
  ['Bug reports', `<p>Report reproducible problems through <a href="${links.issues}">GitHub Issues</a>. Include your macOS version, Lumaunt version, what you expected, what happened, and the steps needed to reproduce it.</p>`],
];
function supportPage() {
  return `<main id="main" tabindex="-1" class="content-page container">${pageHeading('Support', 'A little help with Lumaunt.', 'Start with the topic below, or report a problem on GitHub Issues.')}<div class="support-layout"><section class="help-topics" aria-labelledby="topics-title"><h2 id="topics-title">Common questions</h2>${helpTopics.map(([title, copy]) => `<details class="help-topic"><summary>${title}</summary>${copy}</details>`).join('')}</section><aside class="support-panel" aria-labelledby="report-title"><div class="feature-icon">${icon('presets')}</div><h2 id="report-title">Help us find the bug.</h2><p>Include:</p><ul><li>macOS version</li><li>Lumaunt version</li><li>What you expected</li><li>What happened</li><li>Steps to reproduce</li></ul><p class="credential-note">Do not include Discord access tokens, refresh tokens, Keychain secrets, or private credentials. Check screenshots before sharing them.</p><a class="button button-secondary" href="${links.issues}">Report on GitHub</a><div class="privacy-contact"><h3>Privacy requests</h3><a href="${links.privacyEmail}">privacy@lumaunt.app</a></div></aside></div><a class="text-link" href="/">Back to Home</a></main>`;
}
function legalPage(path) {
  const privacy = path === '/privacy';
  const sections = privacy ? privacySections(links) : termsSections(links);
  const title = privacy ? 'Privacy Policy' : 'Terms of Use';
  const contents = privacy ? [
    ['authentication', 'Authentication'], ['presence', 'Rich Presence'],
    ['moderation', 'Moderation'], ['images', 'Hosted Images'],
    ['crashes', 'Crash Reports'], ['logs', 'Backend Logs'],
    ['retention', 'Retention'], ['choices', 'Your Controls'],
  ] : sections;
  const copy = privacy ? 'Your choices, your information, and the services behind Lumaunt.' : 'A straightforward guide to using Lumaunt and its supporting services.';
  return `<main id="main" tabindex="-1" class="content-page legal-page container">${pageHeading('Lumaunt', title, copy)}<p class="policy-date">Effective date / Last updated: <time datetime="${site.policyDateISO}">${site.policyDate}</time></p><div class="legal-layout"><nav class="legal-toc" aria-label="${title} contents"><h2>On this page</h2><ol>${contents.map(([id, heading]) => `<li><a href="#${id}">${heading}</a></li>`).join('')}</ol></nav><article class="legal-content" aria-label="${title}">${sections.map(([id, heading, content]) => `<section aria-labelledby="${id}"><h2 id="${id}">${heading}</h2>${content}</section>`).join('')}<a class="text-link" href="/">Back to Home</a></article></div></main>`;
}

function discordAuthorizationPage() {
  return `<main id="main" tabindex="-1" class="content-page container authorization-page"><section class="authorization-panel" aria-labelledby="authorization-title"><img class="authorization-icon" src="/images/lumaunt-icon.png" width="88" height="88" alt=""/><span class="eyebrow">${sparkle} Discord authorization</span><h1 id="authorization-title">Continue in Lumaunt.</h1><p class="page-description">You can close this tab and return to Lumaunt to check your connection.</p><div class="authorization-next"><h2>Your next step</h2><p>Once the app shows <strong>Discord Connected</strong>, you’re ready to customize and apply your presence.</p><p>If authorization was cancelled or a connection error appears, use Connect in Lumaunt to try again.</p></div><div class="authorization-actions"><a class="button button-primary" href="/support/">Connection help</a><a class="button button-secondary" href="/">Back to Home</a></div><p class="authorization-note">Your Discord session credentials stay in your Mac’s Keychain.</p></section></main>`;
}

function notFoundPage() {
  return `<main id="main" tabindex="-1" class="content-page container">${pageHeading('Lumaunt', 'Page not found.', 'This page may have moved, or the address may be incorrect.')}<a class="button button-secondary not-found-link" href="/">Back to Home</a></main>`;
}

export function renderPage(path, { assets = {} } = {}) {
  const title = path === '/' ? site.title : `${pageInfo[path][0]} — Lumaunt`;
  const description = path === '/' ? site.description : pageInfo[path][1];
  const canonical = site.origin + (path === '/' ? '/' : `${path}/`);
  const content = path === '/auth/discord' ? discordAuthorizationPage() : path === '/404' ? notFoundPage() : path === '/' ? home(assets) : path === '/download' ? downloadPage() : path === '/support' ? supportPage() : legalPage(path);
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><meta name="theme-color" content="#191d29"/>
<title>${escape(title)}</title><meta name="description" content="${escape(description)}"/>${path === '/auth/discord' ? '<meta name="robots" content="noindex, follow"/><meta name="referrer" content="no-referrer"/>' : path === '/404' ? '<meta name="robots" content="noindex, follow"/>' : `<link rel="canonical" href="${canonical}"/>`}
<meta property="og:type" content="website"/><meta property="og:site_name" content="Lumaunt"/><meta property="og:title" content="${escape(title)}"/><meta property="og:description" content="${escape(description)}"/><meta property="og:url" content="${canonical}"/>
<meta property="og:image" content="${site.origin}${site.socialImage}"/><meta property="og:image:width" content="512"/><meta property="og:image:height" content="512"/><meta property="og:image:alt" content="Lumaunt app icon"/>
<meta name="twitter:card" content="summary"/><meta name="twitter:title" content="${escape(title)}"/><meta name="twitter:description" content="${escape(description)}"/><meta name="twitter:image" content="${site.origin}${site.socialImage}"/><meta name="twitter:image:alt" content="Lumaunt app icon"/>
<link rel="icon" type="image/png" href="/images/lumaunt-favicon.png"/><link rel="apple-touch-icon" sizes="512x512" href="/images/lumaunt-icon.png"/><link rel="stylesheet" href="/styles.css"/><script type="module" src="/navigation.js"></script>
${path === '/' && (assets.app || assets.discord) ? '<script type="module" src="/image-fallback.js"></script>' : ''}</head>
<body>${header(path)}${content}${footer()}</body></html>`;
}
