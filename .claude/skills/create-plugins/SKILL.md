---
name: create-plugins
description: Create a Tyk gateway plugin, starting from the official tyk-plugin-starter. Use when the user wants to write, build, or deploy a custom Tyk plugin, middleware, or request/response hook.
---

# Create a Tyk plugin (start from the official starter)

**Always start from the official `tyk-plugin-starter`** — never hand-roll a plugin from
scratch. It's a goja/TypeScript project with types, a local test harness, examples for every
hook, and a bundle builder. Ground in its own AI brief and examples:
`vendor/tyk-plugin-starter/AGENTS.md` and `vendor/tyk-plugin-starter/examples/`, plus the
plugin docs in `vendor/tyk-docs`.

## Runtime constraints (read AGENTS.md — enforce these)
Plugins run in the gateway's **goja** engine — *not Node.js*. No `require`/runtime `import`,
no `setTimeout`/event loop, no Node APIs (`fs`, `http`, `crypto`, `Buffer`). Portable floor
is ES5.1 (goja is v5.14+; older gateways use otto). Author modern TypeScript; the bundler
down-levels and inlines deps at build time. For HTTP from a plugin use the Tyk global
`TykMakeHttpRequest`, not `fetch`/`axios`. For state use the `TykStorage*` bindings.

## Flow
1. **Sources** — `bash lib/ensure-sources.sh ensure` (fetches the starter).
2. **Scaffold the project** (their own repo, created next to tyk-launchpad):
   ```sh
   NAME=<plugin-name> bash lib/new-plugin.sh
   cd ../<plugin-name> && npm install
   ```
3. **Pick the hook + start from an example.** Hooks: `pre`, `auth_check`, `post_key_auth`,
   `post`, `response`. Copy the closest `examples/<...>` into `src/plugin.ts` and adapt:
   - request mutation → `pre-trace-id`, `post-correlation-id`
   - custom auth → `auth-check-hmac`, `post-key-auth-tenant-context`
   - response edits → `response-pii-redaction`; idempotency → `idempotency-guard`
4. **Local loop (no gateway needed):**
   ```sh
   npm test          # vitest, pure Node
   npm run build     # dist/plugin.js
   ```
   Stay here until it's right. Write/adjust tests in `test/` using the harness mocks.
5. **Bundle for deploy:**
   ```sh
   npm run build:bundle   # dist/bundle.zip = plugin.js + manifest.json (md5 checksum)
   ```
6. **Deploy** — publish the bundle so the gateway loads it (bundle server / dashboard),
   then attach it to an API. Confirm the exact wiring against `vendor/tyk-docs` for the
   deployed gateway version; if attaching to an OAS API, this connects to `author-oas-apis`.

## Guardrails
- If the user asks for `fetch`, `axios`, `fs`, timers, or runtime `require` → stop and use
  the goja-safe equivalent (AGENTS.md). These are the most common plugin mistakes.
- Keep the whole edit→test→build loop local; only step 6 touches Tyk.

## Not this skill
Attaching a finished plugin to an API definition → `author-oas-apis`. Gateway/plugin
loading errors at runtime → `self-heal` / `debug-and-ask`.
