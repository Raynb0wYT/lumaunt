# Lumaunt website — final polish and QA

An isolated, dependency-free static website. Shared templates generate five pages;
CSS tokens preserve the approved macOS-inspired design. No app/backend configuration,
API integration, tracking, external fonts, cookie banner, account system, or embed.
The macOS app, backend, and Swift tests are independent of this project.

## Run locally

With Node.js 22+ and pnpm:

```sh
cd /Users/liam/Documents/Lumaunt/website
pnpm run dev
```

Open http://localhost:4321. Source/public changes rebuild; refresh the browser to see them.
No dependency installation is needed. `PORT=4322 pnpm run dev` overrides the port.
You can also use `node scripts/dev.mjs` directly.

## Validate and build

```sh
pnpm run lint
pnpm run build
pnpm run check
```

Lint checks JavaScript syntax. Type checking is not configured: this project uses
plain JavaScript and HTML, without TypeScript. The output checks validate all five
routes, links/anchors/assets, screenshots and missing-asset fallbacks, policy dates
and retention statements, metadata, disabled download availability, and script exclusions.
The build writes only `website/dist/`. Static hosting must resolve directory routes
to their `index.html` files and serve `404.html` with HTTP 404 for unknown routes.
The local preview does both; confirm the production host’s routing when configured. No deployment, DNS change, commit, or release was performed.

## Content and assets

- `/`: approved hero and feature layout, real app screenshot, real Discord result,
  local-first/privacy summary, final CTA, shared navigation and footer.
- `/download`: macOS presentation with disabled **Coming soon** action until an
  approved artifact exists. Windows is mentioned only as a later plan.
- `/privacy`: policy based on the confirmed Pass #2 decisions, dated October 3, 2026.
  Local Keychain credentials, moderation, optional managed images (7/30/90 days),
  optional Sentry reporting, technical logs (applicable Workers logs ≤7 days),
  providers, retention, choices, security, age, international processing, and contact.
- `/terms`: conservative use/content/service-protection rules, image hosting,
  availability, license deference, third-party terms, and Discord non-affiliation.
- `/support`: eight concise help topics, GitHub Issues bug reporting, credential
  warning, and a separate privacy contact.

Real screenshots copied without alteration from `Lumaunt-Images/`:

- `public/images/lumaunt-app.png` — 2048 × 1194 full app window, 546,046 bytes.
- `public/images/lumaunt-discord-preview.png` — 810 × 324 Discord result, 134,447 bytes.

Images keep their native aspect ratio, reserve layout space, and load lazily.
Full-size links make UI text readable on phones. Missing/broken screenshots show
honest placeholders, including when only one screenshot is present.
The existing 512px app icon supplies the square Open Graph/Twitter summary image;
the existing favicon remains. No dedicated social artwork is required for this pass.

## Public links and release TODOs

All destinations are in `src/config.js`.

- Set `links.macOSDownload` to the approved publicly available release artifact.
  Currently null, with no fake DMG, version, file size, signing/notarization status,
  or minimum macOS requirement displayed.
- The exact requested repository and Issues URLs remain configured. Both returned
  **HTTP 200 in the final public checks on October 3, 2026**.
- Confirm `privacy@lumaunt.app` receives mail. The `mailto:` destination is checked;
  no test email has been sent. No general support email was invented.
- Review the final legal wording and confirm that the supplied operator, retention,
  and provider decisions describe release practices. No authoritative LICENSE file
  was found in this checkout. The Terms defer to applicable licenses without
  inventing a license, jurisdiction, address, arbitration term, or liability cap.
- Verify production canonical/share previews once hosted. No website was deployed.

## Pass #2 file changes

Updated:

- `package.json` — syntax-check coverage for new modules.
- `src/config.js` — public destinations, policy date, screenshot/share metadata.
- `src/pages.js` — completed homepage and four pages, shared footer and metadata.
- `public/styles.css` — compatible additions for showcases and completed pages.
- `public/image-fallback.js` — independent handling for both screenshots.
- `scripts/build.mjs` — legal module loading and actual PNG dimensions.
- `scripts/check.mjs` — route, content, asset, and privacy checks.
- `public/images/README.md` — genuine screenshot sources and fallback instructions.
- `README.md` — current architecture, commands, content, verification and TODOs.

Added:

- `src/legal.js` — confirmed Privacy Policy and Terms content.
- `public/navigation.js` — mobile menu closes on link activation or Escape.
- `public/images/lumaunt-app.png` — genuine supplied app screenshot.
- `public/images/lumaunt-discord-preview.png` — genuine supplied Discord screenshot.

Unchanged: package manager/lockfile, preview server, existing branding assets,
macOS application files, backend files, and Swift tests.

## Final polish and QA

This pass changed only seven website files: `src/pages.js`, `src/legal.js`,
`public/styles.css`, `scripts/build.mjs`, `scripts/dev.mjs`, `scripts/check.mjs`,
and this `README.md`. The build also generates `dist/404.html`.

- Replaced broad credential wording with precise Discord session credentials.
  Moderation and crash-report copy uses the requested clearer wording while
  retaining the limits on guarantees and provider-specific retention.
- Kept all 17 policy sections and the fixed October 3, 2026 legal dates.
  Privacy’s non-sticky contents list now links to eight major sections.
- Legal text is capped at 800px on wide displays, with a 1.75 line height.
- Lower homepage section gaps changed from 112px to 96px on desktop (14.3%)
  and 80px to 72px on mobile (10%). Hero spacing is unchanged.
- Above 1100px, the original Discord-result image renders approximately 14%
  wider; it remains below its native 810px width. Image bytes are unchanged.
- Screenshot alt text is concise. Skip links now focus the main element.
  The existing 512px branding asset also supplies the Apple touch icon.
- FAQ controls remain native `details`/`summary`: keyboard activation,
  expanded/collapsed accessibility states, and content relationships are built in.
- Terms and Support content/layout were reviewed and left unchanged.
- A shared-design, noindex 404 page is built without adding a router or framework.

Verification: build, JavaScript syntax lint, and existing output checks passed.
All five routes were browser-checked at 1440, 1280, 1024, 768, 430, and 390px:
no horizontal overflow, one h1 each, no missing images or JavaScript console errors.
All eight support answers open with Enter and close with Space, with visible focus
and native expanded states. The mobile menu works with Enter/Escape. Skip links
focus main. Internal links and policy anchors resolve, and headings clear the
sticky header. Unknown local routes return the branded HTML page with status 404.

Reduced-motion CSS removes transitions/animation and smooth scrolling while
preserving immediate state feedback. Main text, muted text, links, and CTA gradient
stops retain contrast above 4.5:1. There is no tracking, functional cookie, persistent
browser storage, API call, or third-party client script. No dependencies were added.
TypeScript/type checking and a separate unit-test runner are not configured;
`pnpm run check` remains the project’s verification command.

Manual release checks remain: supply the real macOS artifact and authoritative
release details; confirm privacy-mail delivery; review final legal wording; and
verify production route/404 handling, social previews, and Apple touch-icon display
once hosting is configured. No authoritative LICENSE was found locally, and GitHub’s
license endpoint returned 404. No license or release requirement was invented.
No deployment, commit, push, or app/backend/Swift test changes were made.

## Discord authorization handoff

`/auth/discord/` is a static return-to-app page. It does not receive OAuth codes or tokens and cannot verify connection status. It is excluded from the sitemap and marked noindex. The Discord SDK's existing local OAuth callback must remain unchanged. Opening this page after interactive authorization requires a separate native app handoff; the page alone does not redirect the SDK callback.
