#!/usr/bin/env bash
# Preflight: verify the toolchain + cluster are ready BEFORE anything is deployed.
# Read-only. Never mutates the cluster.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

say "Preflight — checking prerequisites"

# 1. tools (per official README: kubectl, Helm 3.12+)
require kubectl
require helm
HELM_V=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//')
info "helm $HELM_V"; ok "helm present"

# 2. cluster reachable + which context (so the user knows WHERE they're deploying)
kubectl cluster-info >/dev/null 2>&1 || die "kubectl can't reach a cluster. Select a context first (kubectl config use-context ...)."
CTX=$(kubectl config current-context 2>/dev/null || echo '?')
ok "cluster reachable — context: $CTX"
kubectl get nodes >/dev/null 2>&1 && ok "nodes reachable" || warn "could not list nodes"

# 3. namespace guardrail (protects an existing install / running demo)
say "Target: release='$RELEASE' namespace='$NS' (render_only=$RENDER_ONLY force=$FORCE)"
if [ "$RENDER_ONLY" = "1" ]; then
  warn "RENDER_ONLY=1 — will template manifests only; the cluster will NOT be modified"
else
  guard_namespace "$NS"
  ok "namespace '$NS' is safe to use"
fi

# 4. license present in the vendored .env (official location). Do NOT print it.
ENV_FILE="$SM_K8S/.env"
if [ -f "$ENV_FILE" ] && grep -qE '^TYK_LICENSE_KEY=.+' "$ENV_FILE"; then
  ok "license found in $ENV_FILE"
else
  warn "no license set yet. In a SECOND terminal:"
  info "    cp \"$SM_K8S/.env.example\" \"$SM_K8S/.env\""
  info "    # edit \"$SM_K8S/.env\" and set TYK_LICENSE_KEY (+ operator/portal license if you have them)"
  info "  then re-run. (This mirrors the official tyk-install instructions exactly.)"
fi

say "Preflight complete"
