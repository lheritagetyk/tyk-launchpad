#!/usr/bin/env bash
# Shared helpers for tyk-launchpad. Sourced by launch.sh and the lib/* scripts.
# Original code — drives official tyk-install, never vendors Tyk-shipped files.

set -euo pipefail

# --- paths -------------------------------------------------------------------
LAUNCHPAD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TYK_INSTALL="$LAUNCHPAD_ROOT/vendor/tyk-install"
SM_K8S="$TYK_INSTALL/kubernetes/helm-self-managed"   # official self-managed k8s dir

# --- output ------------------------------------------------------------------
say()  { printf "\n\033[1m%s\033[0m\n" "$*"; }
info() { printf "  %s\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
die()  { printf "\n\033[31mFAIL:\033[0m %s\n" "$*" >&2; exit 1; }

# --- defaults (official / vanilla — no personal customizations) --------------
: "${RELEASE:=tyk}"          # helm release name (official README uses "tyk")
: "${NS:=tyk}"               # namespace (official default)
: "${RENDER_ONLY:=0}"        # 1 = helm template / client dry-run, never mutate cluster
: "${FORCE:=0}"              # 1 = allow deploying into a namespace with an existing release

require() { command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH"; }

# Refuse to write over an existing Tyk install unless explicitly forced.
# This is the guardrail that protects a running demo / a customer's prod.
guard_namespace() {
  local ns="$1"
  if helm list -n "$ns" 2>/dev/null | grep -qE '\btyk-stack\b|\b'"$RELEASE"'\b'; then
    [ "$FORCE" = "1" ] && { warn "existing release in '$ns' — proceeding (FORCE=1)"; return; }
    die "namespace '$ns' already contains a Tyk release. Refusing to overwrite it.
     → choose another namespace:   NS=tyk-eval ./launch.sh
     → or override intentionally:  FORCE=1 NS=$ns ./launch.sh"
  fi
  if kubectl get ns "$ns" >/dev/null 2>&1 && \
     kubectl get pods -n "$ns" -l app.kubernetes.io/managed-by=Helm 2>/dev/null | grep -qi tyk; then
    [ "$FORCE" = "1" ] || die "namespace '$ns' has Tyk pods but no matching release — refusing. Use FORCE=1 to override."
  fi
}

# retry <attempts> <sleep_secs> <cmd...> — run cmd until it succeeds or attempts run out.
# Used by self-healing flows to ride out transient states (DB warming, reconcile lag).
retry() {
  local n=$1 s=$2; shift 2
  local i
  for i in $(seq 1 "$n"); do
    "$@" && return 0
    [ "$i" -lt "$n" ] && sleep "$s"
  done
  return 1
}

# wait_ready <namespace> <selector-or-empty> <timeout> — wait for pods to be Ready.
wait_ready() {
  local ns=$1 sel=$2 to=${3:-180}
  if [ -n "$sel" ]; then
    kubectl wait --for=condition=ready pod -l "$sel" -n "$ns" --timeout="${to}s" >/dev/null 2>&1
  else
    kubectl wait --for=condition=ready pod --all -n "$ns" --timeout="${to}s" >/dev/null 2>&1
  fi
}
