---
name: version-apis
description: Add versions to a Tyk OAS API and manage them via the Tyk Operator (base + child APIs, version identifier, default, reassigning the base). Use when the user wants to version an API, add v2/v3, deprecate a version, or change the base version.
---

# Version Tyk OAS APIs (base + child, via Operator)

Ground in `vendor/tyk-docs/api-management/api-versioning.mdx`. The Tyk OAS model:

- A **base API** carries `x-tyk-api-gateway.info.versioning` and routes to child versions
  by a version identifier (header / url-param / url). It stays **External**.
- **Child APIs** are ordinary APIs referenced by their **API Id** in the base's
  `versions[]` list. Set child `state.internal: true` so they're only reachable via the base.
- Creating a new version does **not** change existing API Ids; keys must be granted the
  child's new Id to reach it.

## Flow — add a new version (e.g. v2) to an existing base
1. **Ground + sources** — read the versioning doc; `bash lib/ensure-sources.sh ensure`.
2. **Scaffold the child** (internal):
   ```sh
   python3 lib/scaffold-oas.py --name "orders-v2" --listen /orders-v2/ \
     --upstream https://orders-v2.internal --internal > /tmp/orders-v2.oas.json
   ```
3. **Deploy the child** as its own CRD:
   ```sh
   NAME=orders-v2 OAS_FILE=/tmp/orders-v2.oas.json bash lib/apply-oas-crd.sh
   ```
4. **Get the child's API Id** (authoritative, Operator-assigned):
   ```sh
   kubectl get tykoasapidefinition orders-v2 -n tyk -o jsonpath='{.status.id}'
   ```
5. **Version the base** — add the child to the base OAS:
   ```sh
   python3 lib/set-versioning.py --base /tmp/orders-base.oas.json \
     --child-id <child-id-from-step-4> --version-name v2 \
     --key x-api-version --location header > /tmp/orders-base.updated.json
   ```
6. **Redeploy the base** (ConfigMap `replace`, per the Operator update path):
   ```sh
   NAME=orders-base OAS_FILE=/tmp/orders-base.updated.json bash lib/apply-oas-crd.sh
   ```
7. **Verify** — call the base with and without the identifier:
   ```sh
   curl TYK_GATEWAY_URL/orders-base/...                       # default version
   curl -H 'x-api-version: v2' TYK_GATEWAY_URL/orders-base/... # routed to child
   ```

## Changing / reassigning the base
Promoting a child to base is documented (Dashboard 5.12.0+, "Reassigning the Base API").
The new base must be **External** and the old one usually flipped to **Internal**; mind
listen-path collisions. Follow the doc's "Changing the Base Version" section exactly.

## Guardrail (detect → documented fix; never a baked-in hack)
If an **in-place base update fails to reconcile** (some Operator/Gateway versions have
returned a 400 like "Failed to retrieve organisation" on versioned-base edits): inspect
`kubectl logs deploy/...operator...` and the CRD's `status`. A known recovery is to
delete + recreate the **base** CRD — its API Id is stable because the Operator derives it
from the CRD name, so child links remain valid. Confirm current behavior against the docs
and `gh search issues --owner TykTechnologies "versioning base"` before acting; on 5.12.0+
prefer the documented **Reassign the Base** flow instead of delete/recreate.

## Access control for versions (don't skip)
A version child has its own API Id, so a key/policy that grants only the base **403s on the
child**. After adding a version, grant access to the base AND the child in one policy — see
the `secure-apis-and-keys` skill (`lib/scaffold-policy.py --api <base> --api <child>`).

## Not this skill
Creating the first (base) API → `author-oas-apis`. Policies + access keys (incl. the
per-version grant) → `secure-apis-and-keys`. Developer-facing plans/catalogue →
`build-products-plans`.
