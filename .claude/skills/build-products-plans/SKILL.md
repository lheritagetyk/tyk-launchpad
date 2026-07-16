---
name: build-products-plans
description: Create API products and plans in the Tyk Enterprise Developer Portal and publish them to a catalogue, via the official Portal API. Use when the user wants to package APIs into products, define plans (rate limits/quota), or publish to the portal catalog.
---

# Build API products & plans, publish to the catalogue

Ground in the official Portal API contract:
`vendor/tyk-docs/swagger/enterprise-developer-portal-swagger.yaml` and the endpoint list
`vendor/tyk-docs/product-stack/tyk-enterprise-developer-portal/api-documentation/list-of-endpoints/portal-api-list-of-endpoints.mdx`.
Base path `/portal-api`; auth = admin authorisation token (`Authorization` header).

## Model (official)
- **Provider** — the connection to your Dashboard/Gateway. It must be **synchronized** so
  the portal knows about your APIs before they can go in a product:
  `POST /providers/{id}/synchronize`.
- **Product** — packages one or more APIs (by `APIID`) for consumers. `POST /products`.
- **Plan** — access tier (rate limit, quota, key expiry, auto-approve). `POST /plans`.
- **Catalogue** — publishes selected Products + Plans to an audience. `POST /catalogues`.

## Flow
1. **Sources + inputs** — `bash lib/ensure-sources.sh ensure`. You need: the portal URL,
   the admin token (ask the user — never print/commit it), the `ProviderID`, and the
   `APIID`(s) to package. List providers/products to discover ids:
   ```sh
   PORTAL_URL=... PORTAL_TOKEN=... bash lib/portal-api.sh GET /providers
   PORTAL_URL=... PORTAL_TOKEN=... bash lib/portal-api.sh GET /products
   ```
2. **Sync the provider** (so APIs are available):
   ```sh
   bash lib/portal-api.sh POST /providers/<id>/synchronize
   ```
3. **Build + create a plan**:
   ```sh
   python3 lib/portal-payload.py plan --name Bronze --provider 1 \
     --rate 100 --per 60 --quota 10000 --quota-renewal 3600 > /tmp/plan.json
   bash lib/portal-api.sh POST /plans /tmp/plan.json
   ```
4. **Build + create a product** (reference the API by `APIID`):
   ```sh
   python3 lib/portal-payload.py product --name payment_api --display "Payment API" \
     --provider 1 --api-id <APIID> --oas-url <OAS_URL> > /tmp/product.json
   bash lib/portal-api.sh POST /products /tmp/product.json
   ```
5. **Publish via a catalogue** (link the product + plan):
   ```sh
   python3 lib/portal-payload.py catalogue --name "Public" --product <pid> --plan <plid> > /tmp/cat.json
   bash lib/portal-api.sh POST /catalogues /tmp/cat.json
   ```
6. **Verify** — `GET /products` / `GET /catalogues`; confirm they appear in the portal.

## Safe preview
Every call supports `DRY_RUN=1` (shows the method/URL/body, sends nothing). Build all the
payloads and dry-run them first; deploy once the user confirms.

## Guardrails (detect → documented fix)
- Product create fails "API not found" → the provider wasn't synchronized (step 2) or the
  `APIID` is wrong; re-list and re-sync.
- Uploading an OAS to a product uses the dedicated multipart endpoint
  `POST /products/{id}/api-details/{api_id}/oas` — a plain product PUT does not carry the
  OAS document. Confirm against the swagger.

## Not this skill
Creating the underlying API → `author-oas-apis`. Portal look & feel → `customize-portal-theme`.
