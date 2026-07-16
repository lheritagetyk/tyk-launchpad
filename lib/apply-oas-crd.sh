#!/usr/bin/env bash
# Deploy a Tyk OAS API via the Tyk Operator, exactly per the official docs
# (vendor/tyk-docs/tyk-stack/tyk-operator/create-an-api.mdx):
#   1. store the OAS JSON in a ConfigMap  (kubectl create / replace — NOT apply)
#   2. create a TykOasApiDefinition referencing it via spec.tykOAS.configmapRef
#   3. wait for reconcile (status.latestTransaction.status == Successful)
#
# Env:
#   NAME      required   CRD + ConfigMap base name (e.g. petstore)
#   OAS_FILE  required   path to the Tyk OAS JSON (see lib/scaffold-oas.py)
#   NS        tyk        namespace
#   KEY       oas.json   ConfigMap key holding the definition
#   RENDER_ONLY 0        1 = render manifests + client dry-run only; never touch cluster
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${NAME:?set NAME (e.g. NAME=petstore)}"
: "${OAS_FILE:?set OAS_FILE (path to the Tyk OAS json)}"
: "${KEY:=oas.json}"
CM="${CM:-${NAME}-oas}"

[ -f "$OAS_FILE" ] || die "OAS_FILE not found: $OAS_FILE"
python3 -c "import json,sys; d=json.load(open('$OAS_FILE')); assert 'x-tyk-api-gateway' in d, 'missing x-tyk-api-gateway'" \
  || die "$OAS_FILE is not a valid Tyk OAS definition (needs x-tyk-api-gateway)"
ok "valid Tyk OAS: $OAS_FILE  (api name: $(python3 -c "import json;print(json.load(open('$OAS_FILE'))['x-tyk-api-gateway']['info']['name'])"))"

# The CRD manifest (small — safe to apply; original, not copied from Tyk)
crd_yaml() {
cat <<YAML
apiVersion: tyk.tyk.io/v1alpha1
kind: TykOasApiDefinition
metadata:
  name: $NAME
  namespace: $NS
spec:
  tykOAS:
    configmapRef:
      name: $CM
      namespace: $NS
      keyName: $KEY
YAML
}

if [ "$RENDER_ONLY" = "1" ]; then
  say "RENDER_ONLY — no cluster changes"
  OUT="$LAUNCHPAD_ROOT/.render"; mkdir -p "$OUT"
  # ConfigMap exactly as the official flow builds it (client-side only)
  kubectl create configmap "$CM" --from-file="$KEY=$OAS_FILE" -n "$NS" \
    --dry-run=client -o yaml > "$OUT/$CM.configmap.yaml" || die "configmap dry-run failed"
  crd_yaml > "$OUT/$NAME.tykoas.yaml"
  ok "configmap  -> $OUT/$CM.configmap.yaml"
  ok "crd        -> $OUT/$NAME.tykoas.yaml"
  info "review, then deploy for real by re-running without RENDER_ONLY"
  exit 0
fi

say "1) ConfigMap '$CM' (kubectl create/replace — per official docs, not apply)"
if kubectl get configmap "$CM" -n "$NS" >/dev/null 2>&1; then
  kubectl create configmap "$CM" --from-file="$KEY=$OAS_FILE" -n "$NS" \
    --dry-run=client -o yaml | kubectl replace -f -
else
  kubectl create configmap "$CM" --from-file="$KEY=$OAS_FILE" -n "$NS"
fi
ok "configmap applied"

say "2) TykOasApiDefinition '$NAME'"
crd_yaml | kubectl apply -f -
ok "CRD applied"

say "3) Waiting for Operator reconcile"
for i in $(seq 1 20); do
  STAT=$(kubectl get tykoasapidefinition "$NAME" -n "$NS" \
         -o jsonpath='{.status.latestTransaction.status}' 2>/dev/null || true)
  [ "$STAT" = "Successful" ] && { ok "reconciled (Successful) in ~$((i*3))s"; break; }
  info "attempt $i: status=${STAT:-<pending>}"; sleep 3
done
[ "$STAT" = "Successful" ] || warn "not yet Successful — inspect: kubectl get tykoasapidefinition $NAME -n $NS -o yaml"
kubectl get tykoasapidefinition "$NAME" -n "$NS" 2>/dev/null | sed 's/^/  /'

say "Done — API '$NAME' deployed via Operator"
