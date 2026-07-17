---
name: secure-apis-and-keys
description: Create Tyk SecurityPolicies (rate limit/quota, access control) and issue access keys, including granting a key access to every version of a versioned API. Use when the user wants to secure an API, add a policy, rate-limit, create a test key/token, or fix a 403.
---

# Secure APIs & issue keys

Ground in `vendor/tyk-docs/tyk-stack/tyk-operator/create-an-api.mdx` (SecurityPolicy CRD)
and `vendor/tyk-docs/tyk-apis/`. Default path is the **Operator** for policies (declarative
`SecurityPolicy` CRD); keys are runtime credentials created via the **Dashboard API**
(`POST /api/keys`) — there is no key CRD.

## The model
- A **SecurityPolicy** grants access to one or more APIs (`access_rights_array`, referencing
  API CRDs by name) and carries rate limit / quota. `.status.pol_id` is its dashboard id.
- An **access key** authenticates a caller. Bind it to a policy with `apply_policies` so it
  inherits the policy's access + limits.

## THE VERSIONING TRAP (this is why this skill exists)
Each version **child** API has its own API Id. A policy/key that grants only the **base**
will return **403** on the child versions. **Always grant the base AND every child** in the
same policy — pass each CRD to `--api`.

## Flow
1. **Scaffold the policy** — include the base and each version child:
   ```sh
   python3 lib/scaffold-policy.py --name orders-standard \
     --api orders-base --api orders-v2 --namespace tyk \
     --rate 100 --per 60 --quota 10000 --quota-renewal 3600 > /tmp/policy.yaml
   ```
2. **Preview / apply** (waits for reconcile, prints `pol_id`):
   ```sh
   NAME=orders-standard POLICY_FILE=/tmp/policy.yaml RENDER_ONLY=1 bash lib/apply-policy.sh  # preview
   NAME=orders-standard POLICY_FILE=/tmp/policy.yaml bash lib/apply-policy.sh                # apply
   ```
3. **Issue a key bound to the policy** (needs the Dashboard user API token — ask the user,
   or retrieve it as the install does; never print/commit it):
   ```sh
   DASH_TOKEN=<dash-token> POLICY_ID=<pol_id> bash lib/create-key.sh   # DRY_RUN=1 to preview
   ```
4. **Verify** — the 401→200 and per-version checks:
   ```sh
   curl $GW/orders-base/...                         # 401 without a key
   curl -H "Authorization: $KEY" $GW/orders-base/...          # 200 (base)
   curl -H "Authorization: $KEY" -H 'x-api-version: v2' $GW/orders-base/...  # 200 (child) — NOT 403
   ```
   A 403 on a version means that child Id isn't in the policy — add it with `--api` and re-apply.

## Guardrails
- **403 on a version** → missing child grant (above). The single most common versioning mistake.
- Auth type mismatch: the API must use a key-based scheme (authToken) for a key to apply.
- Keep secrets out of output/commits.

## Not this skill
Creating the API → `author-oas-apis`. Versioning → `version-apis`. Portal-facing plans for
developers → `build-products-plans` (that's catalogue packaging, not raw keys/policies).
