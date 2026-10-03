# Lumaunt API abuse protection

Implemented against the supplied 1,147-line Worker, which matched the local Worker byte for byte. Existing image/moderation handlers and response schemas are preserved. No macOS source or UI was changed for this task.

## Limits and identities

All windows are 60 seconds. These are native Cloudflare Workers Rate Limiting bindings; no in-memory limiter is used in production.

| Binding | Limit | Keys and routes |
| --- | ---: | --- |
| `UPLOAD_RATE_LIMITER` | 20 | SHA-256 owner digest for `/v2/images/upload`; separately, hashed connecting IP for `/images/upload` |
| `UPLOAD_IP_RATE_LIMITER` | 60 | Hashed connecting IP shared across both upload routes; prevents unlimited owner-token rotation |
| `MODERATION_RATE_LIMITER` | 60 | Hashed connecting IP, shared between `/v1/moderate/text` and `/v1/moderate/context` |
| `DELETE_RATE_LIMITER` | 120 | Both owner digest and hashed connecting IP, with separate counters, for `/v2/images/delete` |

Native moderation requests have no authenticated installation identity, so moderation ignores caller-supplied owner tokens. Owner tokens establish ownership of uploaded images, but callers can mint arbitrary new tokens. Consequently managed uploads must pass BOTH the owner limit and the IP backstop. The higher aggregate upload allowance permits several installations behind a shared connection, while still bounding token rotation. Deletion permits two operations per second on average; large delete-all operations may need another attempt after the window resets. Rate bindings increment on every attempted protected request, including invalid requests; upload IP budget is checked before the owner budget.

Owner keys contain only the existing SHA-256 digest. IP keys contain a domain-separated SHA-256 digest of Cloudflare's `CF-Connecting-IP`; no raw IP is written to storage, logged by this code, or returned to clients. No `X-Forwarded-For` or `X-Real-IP` fallback is accepted. Hashes are pseudonymous rather than anonymous: an IP digest could be guessed from a known candidate IP. The native counter store is the only new recipient of these digest keys. Deployment must remain behind Cloudflare's public ingress, which supplies/overwrites the connecting IP header. Do not expose this Worker through an alternate proxy that passes attacker-controlled connecting IP values.

Both health/capabilities GET routes bypass protection entirely. Unknown methods/routes keep their existing 404 behavior, with no permissive CORS headers. A 429 returns only `{"error":"Too many requests. Please try again shortly."}` and the existing JSON headers. No Retry-After is invented because this binding returns success/failure without a remaining-window duration. Missing bindings, binding exceptions or missing connecting IP fail closed with a generic 503; expensive work cannot run unprotected.

Guards execute before body consumption, R2 operations, OpenAI or Workers AI. Managed image validation is unchanged. Legacy uploads now also read bodies with a hard 5 MB cap even with misleading/missing Content-Length; oversized JSON requests are bounded at 16 KiB before JSON decoding. This comfortably covers the app's current 2,000 UTF-16-code-unit moderation payloads and image deletion requests. Original content-type, text/category, retention, owner, signature, and image-ownership checks remain intact.

## Existing configuration and deployment

The dashboard was inspected: the existing Worker is `lumaunt-api`, with `IMAGES` bound to `lumaunt-images`, Workers AI bound as `AI`, custom domain `api.lumaunt.app`, workers.dev enabled, and the daily cleanup trigger already present. The existing encrypted `OPENAI_API_KEY` is kept; no secret was read or copied. No Wrangler file existed locally.

New `wrangler.jsonc` records those resources, compatibility date `2026-09-28`, logging enabled, the existing daily cleanup at 04:00 UTC, and four native rate-limit bindings. Namespace IDs `9272601` through `9272604` are distinct and dedicated to these policies. Verify they are not already used by another Worker in this account: Cloudflare shares counters across bindings that reuse a namespace ID. No namespace resource must be created separately.

**Deployed successfully on 2026-10-02.** Production version: `dca0df9d-388c-4f7c-a8e7-17059d25810b`, serving `api.lumaunt.app` and the existing workers.dev address. All four native rate-limit bindings, AI, R2, and the daily `0 4 * * *` cleanup schedule were confirmed by Wrangler. Do not paste only worker.js into the dashboard: the new code needs all four bindings, and otherwise protected POST requests return 503. Cloudflare currently documents that rate-limit bindings are not visible in the dashboard; deploy the configuration with Wrangler, rather than assuming the editor creates them.

From this Backend folder, with Node 22 or newer:

```sh
npm install
npx wrangler login
npm test
npm run test:native
npm run check
npm run deploy
```

Wrangler 4.146.0 is pinned in package.json; native rate-limit bindings require Wrangler 4.36.0 or later. Login uses your existing Cloudflare account. Deployment creates/configures the four rate bindings together with the code and preserves the R2/AI bindings, domain and schedule described above. The existing worker's encrypted OpenAI secret must still be present after deployment; do not put its value in any configuration file. No separate dashboard rate-limit setup is required when deploying this configuration. Review the configuration against any subsequent dashboard changes before deploying. For a new/different Worker, configure its OpenAI secret separately.

## Tests and results

- 20 local automated tests passed: managed upload/deletion, all retention choices, ownership denial, size/signature failures, expiry cleanup including pagination, working moderation responses with provider mocks, repeated requests/429s and counter reset with an injected test clock, shared moderation budgets, token rotation, independent clients, legacy protection, bounded JSON/legacy reads, fail-closed errors, unsupported methods/CORS, unaffected health/capabilities, and configuration policies.
- Wrangler 4.146.0 dry-run bundled successfully and recognized all four rate-limit bindings at their configured limits.
- Cloudflare's local Miniflare/workerd runtime passed managed upload/deletion and actual native-binding 429 checks for uploads and both moderation routes. OpenAI/Workers AI were mocked in an unpublished test copy; no live AI cost, production upload or deployment occurred. Native health/capabilities remained available after exhausting limits.
- Counter-reset timing was verified with test doubles and, after deployment, by waiting 65 seconds and confirming live uploads and both moderation routes accepted requests again. Native limits are permissive, eventually consistent, and local to each Cloudflare location, so production thresholds can overshoot slightly. They are burst protection, not strict worldwide quotas or guaranteed spending caps.
- The macOS request contracts were inspected: uploads use `/v2/images/upload` with ownership/retention headers, deletion uses `/v2/images/delete`, and moderation uses the two v1 routes without an owner header. These contracts are unchanged. Both real AI providers passed the post-deployment API smoke tests. The actual macOS Apply Presence workflow still needs a full app regression test.

The Map-based test double in test-fixtures.mjs exists ONLY for deterministic unit tests. Production uses native bindings.

## Legacy endpoint and beta concerns

The current macOS app does not use `POST /images/upload`. The existing production code still routes to it; it is publicly reachable at the route level and does not enforce managed ownership, retention, or signature validation. The hardened file preserves its URL/schema for compatibility, adds rate limits and bounded body reads, and keeps it out of the `managed-images/` namespace. Its uploads still persist indefinitely, unlike managed uploads. Recommend disabling/removing it before beta after explicitly deciding compatibility; it was not silently removed.

Remaining concerns to address before beta:

1. Legacy indefinite storage and weaker validation: disable the unused route or migrate any remaining external clients.
2. Self-issued owner tokens are not authentication; IP backstops stop single-IP rotation, but distributed abuse can still consume AI/storage resources. Add provider budget alerts/caps and consider verified installation identity or account authentication as a separate decision.
3. Native counters are approximate and per location. A strict global quota would require another architecture, which this task deliberately does not introduce.
4. Shared-IP moderation/deletion limits may affect large shared networks. Observe 429s during beta and tune without weakening the ownership checks.
5. Existing provider diagnostic logs can include upstream responses. They are not returned to clients, but review log access/retention before beta. Image URLs remain public for Discord and other services may retain copies.

## Short production smoke test after deployment

1. Check `GET /` and `GET /v2/images/capabilities`: both should return 200. Normal macOS Apply Presence with local images, hover text and buttons should work after upload consent. Check ordinary text and contextual moderation with known harmless examples.
2. For one installation, choose 7, 30 and 90 days on separate fresh uploads. Confirm `expiresAt` matches each choice and original ownership deletion still works. Use only disposable test images. Check invalid signature and an oversized image receive 415/413 without creating R2 objects.
3. Sequentially attempt more than 20 fresh uploads with one owner token from one connection, until 429 appears (allow slight native-counter overshoot). Inspect Worker/R2 logs to verify blocked requests produce no write. Rotate owner tokens from the same IP; aggregate uploads should still eventually receive 429 near 60 calls. Reused app image-cache entries do not call upload, so use fresh content or an API test client rather than repeatedly applying a cached image.
4. Sequentially send over 60 valid harmless text-moderation requests, until 429 appears. Repeat separately for contextual moderation after allowing the shared moderation window to reset. Mixing the routes also shares the 60-call budget. These tests invoke real AI services before the threshold, so expect provider usage. Inspect logs to ensure blocked requests do not call providers.
5. Wait at least 60 seconds after the last request, then retry a normal upload and both moderation requests; they should work again. Keep the same owner/IP when testing reset. Health/capabilities should still be 200 while POST routes are blocked.
6. Test deletion within the 120-call allowance and verify another owner receives 403. Clean up only your disposable test uploads. Avoid logging owner tokens or placing them in URLs. Confirm the existing daily cleanup trigger remains configured.

Primary reference: [Cloudflare Workers Rate Limiting API](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/).

## Files changed for this task

- worker.js — route guards, native limiter integration, bounded legacy/JSON reads and generic legacy storage errors.
- wrangler.jsonc — new deployment configuration with four native rate-limit bindings and existing resources.
- privacy.test.mjs — existing privacy regression tests now supply rate-binding fixtures and a Cloudflare connecting IP.
- abuse.test.mjs — new abuse, failure and reset tests.
- test-fixtures.mjs — shared test-only provider/binding/storage fixtures.
- native-smoke.mjs — reproducible local native-runtime smoke checks with mocked AI services.
- package.json — pinned validation/deployment tooling and test commands.
- .gitignore — exclude dependency, local emulator and secret files.
- HARDENING.md — this report, setup, limitations and production test procedure.

worker-original.js is an older existing backup; it was not edited in this task. No Swift, Xcode project, UI or production configuration was changed.

## Deployment verification — 2026-10-02

Live health/capabilities, managed uploads with 7/30/90-day expiry, wrong-owner rejection, deletion of the disposable uploads, and both real moderation providers passed. Fast invalid-input bursts produced generic 429 responses for uploads and moderation; both moderation routes share the blocked state. No Retry-After was invented. The initial sequential upload test did not reach a block, and burst counts exceeded nominal thresholds before blocking: this confirms that native counters are permissive and must not be treated as strict global quotas. These API checks do not constitute a full macOS Apply Presence regression test.

Live reset verification passed after 65 seconds: upload validation and both moderation routes resumed, while health/capabilities remained available during the block.
