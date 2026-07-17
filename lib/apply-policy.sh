#!/usr/bin/env bash
# Apply a Tyk SecurityPolicy CRD and wait for the Operator to reconcile it, then print
# its dashboard policy id (.status.pol_id) — which you feed to lib/create-key.sh.
#
# Env:
#   NAME         required   SecurityPolicy CRD name
#   POLICY_FILE  required   path to the SecurityPolicy YAML (see lib/scaffold-policy.py)
#   NS           tyk        namespace
#   RENDER_ONLY  0          1 = validate + show, never touch the cluster
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${NAME:?set NAME (SecurityPolicy CRD name)}"
: "${POLICY_FILE:?set POLICY_FILE (path to the SecurityPolicy YAML)}"
[ -f "$POLICY_FILE" ] || die "POLICY_FILE not found: $POLICY_FILE"

if [ "$RENDER_ONLY" = "1" ]; then
  say "RENDER_ONLY — SecurityPolicy manifest (no cluster changes)"
  sed 's/^/  /' "$POLICY_FILE"
  exit 0
fi

say "Applying SecurityPolicy '$NAME'"
kubectl apply -f "$POLICY_FILE"

say "Waiting for reconcile (.status.pol_id)"
POL_ID=""
for i in $(seq 1 20); do
  POL_ID=$(kubectl get securitypolicy "$NAME" -n "$NS" -o jsonpath='{.status.pol_id}' 2>/dev/null || true)
  [ -n "$POL_ID" ] && { ok "reconciled — pol_id=$POL_ID"; break; }
  info "attempt $i: not reconciled yet"; sleep 3
done
[ -n "$POL_ID" ] || die "policy did not reconcile — inspect: kubectl get securitypolicy $NAME -n $NS -o yaml"
echo "$POL_ID"
say "Next: bind a key to it —  DASH_TOKEN=… POLICY_ID=$POL_ID bash lib/create-key.sh"
