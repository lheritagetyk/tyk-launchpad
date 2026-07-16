#!/usr/bin/env bash
# tyk-launchpad — guided deploy for Tyk, built entirely on the official tyk-install
# repo (pinned in vendor/). Runs standalone (no LLM required); the Claude Code skill
# in .claude/ drives this same script and adds troubleshooting.
#
# Usage:
#   ./launch.sh                     # k8s self-managed into namespace 'tyk' (guarded)
#   NS=tyk-eval ./launch.sh         # deploy into a different namespace
#   RENDER_ONLY=1 ./launch.sh       # template manifests only — never touches the cluster
#   FORCE=1 NS=tyk ./launch.sh      # intentionally reuse a namespace with an existing release
#
# This first release covers the Kubernetes / Self-Managed vertical slice.
# Docker + Hybrid + Operator topologies land in later milestones.
set -euo pipefail
cd "$(dirname "$0")"
source lib/common.sh

SUBSTRATE="${SUBSTRATE:-k8s}"
TOPOLOGY="${TOPOLOGY:-self-managed}"

say "tyk-launchpad"
info "substrate=$SUBSTRATE  topology=$TOPOLOGY  release=$RELEASE  namespace=$NS"

# Fetch the official Tyk sources fresh on first use (nothing Tyk-shipped is committed here).
bash lib/ensure-sources.sh ensure
[ -d "$TYK_INSTALL/kubernetes" ] || die "tyk-install source missing after ensure — check network/git access"

case "$SUBSTRATE/$TOPOLOGY" in
  k8s/self-managed)
    bash lib/preflight.sh
    bash lib/deploy-k8s-self-managed.sh
    [ "$RENDER_ONLY" = "1" ] || bash lib/verify.sh
    ;;
  *)
    die "topology '$SUBSTRATE/$TOPOLOGY' not implemented in this release (k8s/self-managed only)."
    ;;
esac

say "Done."
