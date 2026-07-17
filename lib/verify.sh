#!/usr/bin/env bash
# Verify a Tyk Self-Managed install is healthy. Read-only.
# Uses a temporary port-forward (torn down on exit) so it works without a LoadBalancer.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

say "Verify — release='$RELEASE' namespace='$NS'"

kubectl get ns "$NS" >/dev/null 2>&1 || die "namespace '$NS' not found"

say "1) Pods"
kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '{printf "  %-55s %s\n",$1,$3}'
NOTREADY=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]!=a[2] && $3!="Completed") c++} END{print c+0}')
[ "$NOTREADY" = "0" ] && ok "all pods ready" || warn "$NOTREADY pod(s) not ready yet"

# temp port-forwards on official ports (Gateway 8080, Dashboard 3000) — local only
GW_SVC=$(kubectl get svc -n "$NS" -o name 2>/dev/null | grep -iE 'gateway' | head -1)
DASH_SVC=$(kubectl get svc -n "$NS" -o name 2>/dev/null | grep -iE 'dashboard' | head -1)
PIDS=()
cleanup(){ for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

say "2) Gateway /hello"
if [ -n "$GW_SVC" ]; then
  kubectl port-forward -n "$NS" "$GW_SVC" 18080:8080 >/dev/null 2>&1 & PIDS+=($!)
  sleep 3
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:18080/hello || echo 000)
  [ "$CODE" = "200" ] && ok "gateway /hello -> 200" || warn "gateway /hello -> $CODE"
else warn "no gateway service found"; fi

say "3) Dashboard /hello"
if [ -n "$DASH_SVC" ]; then
  kubectl port-forward -n "$NS" "$DASH_SVC" 13000:3000 >/dev/null 2>&1 & PIDS+=($!)
  sleep 3
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:13000/hello || echo 000)
  [ "$CODE" = "200" ] && ok "dashboard /hello -> 200" || warn "dashboard /hello -> $CODE"
else warn "no dashboard service found"; fi

say "Verify complete"
if [ "${NOTREADY:-0}" != "0" ]; then
  warn "some components aren't ready — diagnose/heal with:  NS=$NS bash lib/doctor.sh   (add HEAL=1 to repair)"
fi
