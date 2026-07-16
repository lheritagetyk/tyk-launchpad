#!/usr/bin/env bash
# Deploy Tyk Self-Managed to Kubernetes by driving the OFFICIAL tyk-install steps.
# References vendor/tyk-install/kubernetes/helm-self-managed/{values.yaml,.env}.
# Copies NOTHING Tyk-shipped — values.yaml is used in place via --values.
#
# RENDER_ONLY=1  -> validate with `helm template` only; the cluster is untouched.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

VALUES="$SM_K8S/values.yaml"
ENV_FILE="$SM_K8S/.env"
[ -f "$VALUES" ] || die "vendored values.yaml missing at $VALUES (did submodules init?)"

# Official chart deps + versions come straight from the tyk-install README.
PG_VERSION=12.12.10
REDIS_VERSION=19.0.2
CERTMGR_VERSION=v1.17.4

say "Add official Helm repos (local only — does not touch the cluster)"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/ >/dev/null 2>&1 || true
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
ok "repos ready"

# ---------------------------------------------------------------------------
if [ "$RENDER_ONLY" = "1" ]; then
  say "RENDER_ONLY — templating tyk-stack with the vendored values.yaml (no cluster changes)"
  OUT="$LAUNCHPAD_ROOT/.render"; mkdir -p "$OUT"
  helm template "$RELEASE" tyk-helm/tyk-stack \
     --namespace "$NS" --values "$VALUES" > "$OUT/tyk-stack.yaml" \
     || die "helm template failed — values.yaml or chart mismatch"
  KINDS=$(grep -c '^kind:' "$OUT/tyk-stack.yaml" || true)
  ok "rendered $KINDS manifests -> $OUT/tyk-stack.yaml"
  info "review with:  less $OUT/tyk-stack.yaml"
  say "RENDER_ONLY complete — nothing was deployed"
  exit 0
fi

# --- real deploy path (guarded upstream by preflight/guard_namespace) --------
[ -f "$ENV_FILE" ] || die "no .env at $ENV_FILE — copy .env.example and set TYK_LICENSE_KEY (second terminal), then re-run"
grep -qE '^TYK_LICENSE_KEY=.+' "$ENV_FILE" || die "TYK_LICENSE_KEY is empty in $ENV_FILE"
set -a; . "$ENV_FILE"; set +a

say "1) Namespace"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"
ok "namespace $NS"

say "2) Secrets (from .env — values never printed)"
kubectl create secret generic tyk-conf --namespace "$NS" \
  --from-literal=APISecret="$TYK_API_SECRET" \
  --from-literal=AdminSecret="$TYK_ADMIN_SECRET" \
  --from-literal=DashLicense="$TYK_LICENSE_KEY" \
  --from-literal=OperatorLicense="${TYK_OPERATOR_LICENSE:-}" \
  --from-literal=DevPortalLicense="${TYK_PORTAL_LICENSE:-}" \
  --from-literal=adminUserFirstName="$ADMIN_FIRST_NAME" \
  --from-literal=adminUserLastName="$ADMIN_LAST_NAME" \
  --from-literal=adminUserEmail="$ADMIN_EMAIL" \
  --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
  --from-literal=DashDatabaseConnectionString="$DashDatabaseConnectionString" \
  --from-literal=DevPortalDatabaseConnectionString="$DevPortalDatabaseConnectionString" \
  --dry-run=client -o yaml | kubectl apply -n "$NS" -f -
kubectl create secret generic secrets-tyk-tyk-dev-portal -n "$NS" \
  --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
  --from-literal=adminUserEmail="$ADMIN_EMAIL" \
  --dry-run=client -o yaml | kubectl apply -n "$NS" -f -
ok "secrets applied"

say "3) Dependencies (PostgreSQL, Redis, cert-manager)"
helm upgrade --install tyk-postgres bitnami/postgresql --namespace "$NS" \
  --set image.repository=bitnamilegacy/postgresql \
  --set auth.username="$POSTGRES_USER" --set auth.password="$POSTGRES_PASSWORD" \
  --set auth.database="$POSTGRES_DB" \
  --set primary.initdb.scripts."init\.sql"="CREATE DATABASE portal;" \
  --set primary.persistence.size=20Gi --version "$PG_VERSION"
helm upgrade --install tyk-redis oci://registry-1.docker.io/bitnamicharts/redis --namespace "$NS" \
  --set image.repository=bitnamilegacy/redis --set auth.enabled=false --version "$REDIS_VERSION"
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version "$CERTMGR_VERSION" --namespace cert-manager --create-namespace --set crds.enabled=true
info "waiting for databases..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n "$NS" --timeout=300s
ok "dependencies ready"

say "4) Tyk Stack"
helm upgrade --install "$RELEASE" tyk-helm/tyk-stack --namespace "$NS" --values "$VALUES"
ok "tyk-stack installed — waiting for rollout"
kubectl rollout status deploy -n "$NS" --timeout=300s 2>/dev/null || true

say "Deploy complete — run: RELEASE=$RELEASE NS=$NS lib/verify.sh"
