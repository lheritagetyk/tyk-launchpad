---
name: author-oas-apis
description: Create a Tyk OAS API and deploy it to Kubernetes via the Tyk Operator (TykOasApiDefinition + ConfigMap). Use when the user wants to add, author, scaffold, or deploy an API onto Tyk.
---

# Author & deploy a Tyk OAS API (via Tyk Operator)

Default path is the **Tyk Operator** (declarative CRDs) unless the user asks for the
Dashboard API instead. Read `CLAUDE.md` first. Ground everything in the official doc:
`vendor/tyk-docs/tyk-stack/tyk-operator/create-an-api.mdx`.

## Inputs to gather from the user
- API name (e.g. `petstore`)
- Listen path (e.g. `/petstore/`)
- Upstream URL (the real backend)
- Auth: keyless, or auth-token protected?
- Namespace (default `tyk`) — this is where their Tyk + Operator already run.

## Flow
1. **Sources present** — `bash lib/ensure-sources.sh ensure` (needs `vendor/tyk-docs`).
2. **Scaffold the OAS** — build a valid Tyk OAS definition:
   ```sh
   python3 lib/scaffold-oas.py --name "Petstore" --listen /petstore/ \
     --upstream https://petstore.example.com [--auth-token] [--cors] > /tmp/petstore.oas.json
   ```
   Use `--cors` only if it will be tried from the developer portal (browser). Show the
   user the scaffold and let them refine paths/middleware before deploying.
3. **Preview (safe)** — render the ConfigMap + CRD without touching the cluster:
   ```sh
   NAME=petstore OAS_FILE=/tmp/petstore.oas.json RENDER_ONLY=1 bash lib/apply-oas-crd.sh
   ```
4. **Deploy** — `NAME=petstore OAS_FILE=/tmp/petstore.oas.json bash lib/apply-oas-crd.sh`
   This creates the ConfigMap with `kubectl create`/`replace` (NOT `apply` — the official
   docs avoid `apply` because the OAS can exceed the 256KB annotation limit), applies the
   `TykOasApiDefinition`, and waits for `status.latestTransaction.status: Successful`.
5. **Verify** — the script prints `kubectl get tykoasapidefinition`; confirm SYNCSTATUS.
   Optionally curl `TYK_GATEWAY_URL/<listenPath>/...`.

## Updating an existing API
Re-run step 4 with the edited OAS file. The applier uses `kubectl replace` on the
ConfigMap, which the Operator detects. (Deeper versioning/revisions is the
`version-apis` skill.)

## Guardrails (detect → apply the documented fix; never bake in hacks)
- If a ConfigMap-only edit doesn't sync, confirm the CRD's `configmapRef` is unchanged
  and the ConfigMap was `replace`d (not left stale) — see the doc's "Manage and Update".
- Portal Try-It failing cross-origin → the OAS needs CORS at
  `x-tyk-api-gateway.middleware.global.cors` (the `--cors` scaffold flag). Confirm in docs.

## Not this skill
Products/plans/portal publishing → `build-products-plans`. Theme → `customize-portal-theme`.
