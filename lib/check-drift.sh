#!/usr/bin/env bash
# check-drift.sh — verify the assumptions our scripts bake in (API/CRD field names,
# endpoints, chart anchors) still exist in the FRESHLY-CLONED official sources. If Tyk
# renamed or moved one, this fails loudly — turning silent staleness into a signal you can
# act on (fix the script) instead of a customer hitting a mystery 400 later. Read-only.
#
#   bash lib/check-drift.sh          # exits non-zero if anything drifted
# Run it after pulling latest sources, or on a schedule (see the scheduling skill).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DOCS="$LAUNCHPAD_ROOT/vendor/tyk-docs"
INSTALL="$LAUNCHPAD_ROOT/vendor/tyk-install"

say "Drift check — asserting our scripts' assumptions still exist in the official sources"
# make sure the sources are present (fresh)
[ -d "$DOCS" ] && [ -d "$INSTALL" ] || { info "fetching sources…"; bash "$LAUNCHPAD_ROOT/lib/ensure-sources.sh" ensure >/dev/null 2>&1; }

DRIFT=0
# label | literal pattern | search root | dependent script(s)
CHECKS=(
  "Tyk vendor extension|x-tyk-api-gateway|$DOCS|scaffold-oas.py, apply-oas-crd.sh"
  "OAS CRD configmapRef|configmapRef|$DOCS|apply-oas-crd.sh"
  "TykOasApiDefinition kind|TykOasApiDefinition|$DOCS|apply-oas-crd.sh"
  "Operator API group|tyk.tyk.io/v1alpha1|$DOCS|apply-oas-crd.sh, scaffold-policy.py"
  "Versioning field|fallbackToDefault|$DOCS|set-versioning.py"
  "Detailed tracing field|detailedTracing|$DOCS|scaffold-oas.py"
  "Traffic logs field|trafficLogs|$DOCS|scaffold-oas.py"
  "CORS variable|--tdp-|$DOCS|customize-portal-theme (branding)"
  "SecurityPolicy kind|SecurityPolicy|$DOCS|scaffold-policy.py"
  "Policy access rights|access_rights_array|$DOCS|scaffold-policy.py"
  "Policy id status|pol_id|$DOCS|apply-policy.sh"
  "Key policy binding|apply_policies|$DOCS|create-key.sh"
  "Dashboard keys endpoint|/api/keys|$DOCS|create-key.sh"
  "Portal API base path|/portal-api|$DOCS|portal-api.sh"
  "Portal products endpoint|/products|$DOCS|portal-payload.py"
  "Portal plans endpoint|/plans|$DOCS|portal-payload.py"
  "Portal catalogues endpoint|/catalogues|$DOCS|portal-payload.py"
  "Portal providers endpoint|/providers|$DOCS|build-products-plans"
  "Theme upload endpoint|/themes/upload|$DOCS|upload-theme.sh"
  "Portal logo asset|dev-portal-logo|$DOCS|new-theme.sh (branding)"
  "Chart: postgres anchor|bitnami/postgresql|$INSTALL|deploy-k8s-self-managed.sh"
  "Chart: redis anchor|bitnamicharts/redis|$INSTALL|deploy-k8s-self-managed.sh"
  "Chart: cert-manager anchor|jetstack/charts/cert-manager|$INSTALL|deploy-k8s-self-managed.sh"
  "Chart: tyk-stack repo|tyk-helm/tyk-stack|$INSTALL|deploy-k8s-self-managed.sh"
)

for c in "${CHECKS[@]}"; do
  IFS='|' read -r label pat root deps <<<"$c"
  if [ -d "$root" ] && grep -rFq -- "$pat" "$root" 2>/dev/null; then
    ok "$label  ('$pat')"
  else
    warn "DRIFT: '$pat' no longer found in $(basename "$root") — used by: $deps"
    DRIFT=$((DRIFT+1))
  fi
done

say "Summary"
if [ "$DRIFT" = "0" ]; then
  ok "no drift — all ${#CHECKS[@]} assumptions still present in the official sources"
else
  warn "$DRIFT of ${#CHECKS[@]} assumption(s) drifted — update the dependent script(s) against the current docs/source"
  exit 1
fi
