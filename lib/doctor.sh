#!/usr/bin/env bash
# doctor — diagnose (and optionally self-heal) a Tyk install. Read-only by default;
# applies SAFE, documented repairs only when HEAL=1. Never destructive (no deletes of
# PVCs/namespaces/data). Grounds each finding in a likely cause + where to confirm it.
#
#   NS=tyk bash lib/doctor.sh            # diagnose only (safe — kubectl get/logs)
#   NS=tyk HEAL=1 bash lib/doctor.sh     # also apply safe repairs (rollout restart, waits, re-reconcile)
#
# Safe repairs: rollout restart (fixes post-reboot dependency-ordering crashes),
# wait-for-ready, re-apply a stuck TykOasApiDefinition. Anything riskier is REPORTED,
# not done. HEAL will not touch a namespace that isn't the one you named.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${HEAL:=0}"
FINDINGS=0; HEALED=0

kubectl get ns "$NS" >/dev/null 2>&1 || die "namespace '$NS' not found — is Tyk installed there? (try: NS=<ns> bash lib/doctor.sh)"
say "doctor — namespace '$NS'  (mode: $([ "$HEAL" = 1 ] && echo 'HEAL — will apply safe repairs' || echo 'diagnose only'))"

finding() { FINDINGS=$((FINDINGS+1)); warn "$1"; [ -n "${2:-}" ] && info "  likely cause: $2"; [ -n "${3:-}" ] && info "  fix: $3"; }

# ---- 1. Pods: crashloops / not-ready / restarts -----------------------------
say "1) Workload health"
NOT_OK=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(($2!="" && a[1]!=a[2] && $3!="Completed") || $3 ~ /CrashLoopBackOff|Error|ImagePullBackOff/) print $1"|"$3}')
if [ -z "$NOT_OK" ]; then ok "all pods ready"; else
  while IFS='|' read -r pod status; do
    [ -z "$pod" ] && continue
    finding "$pod is $status" \
      "often dependency ordering after a restart (Redis/Postgres not ready when the app started)" \
      "rollout restart the owning workload once its dependencies are Ready"
  done <<< "$NOT_OK"
  if [ "$HEAL" = "1" ]; then
    say "   HEAL: restarting not-ready Deployments (safe, recoverable)"
    # restart deployments that own not-ready pods; wait for dependencies first
    wait_ready "$NS" "app.kubernetes.io/name=postgresql" 120 || true
    wait_ready "$NS" "app.kubernetes.io/name=redis" 120 || true
    for d in $(kubectl get deploy -n "$NS" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      # only restart if this deploy currently has a not-ready pod
      if kubectl get pods -n "$NS" -l "$(kubectl get deploy "$d" -n "$NS" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(','.join(f'{k}={v}' for k,v in d.items()))" 2>/dev/null)" --no-headers 2>/dev/null \
           | awk '{split($2,a,"/"); if(a[1]!=a[2]) exit 0; else exit 1}'; then
        info "   restart deploy/$d"; kubectl rollout restart deploy/"$d" -n "$NS" >/dev/null 2>&1
        kubectl rollout status deploy/"$d" -n "$NS" --timeout=180s >/dev/null 2>&1 && { ok "   $d recovered"; HEALED=$((HEALED+1)); } || warn "   $d still not ready — inspect: kubectl describe deploy/$d -n $NS"
      fi
    done
  fi
fi

# ---- 2. Dependencies --------------------------------------------------------
say "2) Dependencies (Redis, PostgreSQL)"
for dep in "postgresql:PostgreSQL" "redis:Redis"; do
  sel="app.kubernetes.io/name=${dep%%:*}"; nice="${dep##*:}"
  if kubectl get pods -n "$NS" -l "$sel" --no-headers 2>/dev/null | grep -q .; then
    wait_ready "$NS" "$sel" 5 && ok "$nice ready" || finding "$nice not ready" "DB/cache still starting or crashed" "wait; if persistent, check its logs/PVC"
  else warn "$nice pods not found (external DB?)"; fi
done

# ---- 3. Gateway / Dashboard reachability (read-only, temp port-forward) ------
say "3) Gateway / Dashboard /hello"
PIDS=(); cleanup(){ for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done; }; trap cleanup EXIT
probe() { # svc-grep localport
  local svc; svc=$(kubectl get svc -n "$NS" -o name 2>/dev/null | grep -iE "$1" | head -1)
  [ -z "$svc" ] && { warn "no $1 service"; return; }
  kubectl port-forward -n "$NS" "$svc" "$2:$3" >/dev/null 2>&1 & PIDS+=($!); sleep 3
  local code; code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:$2/hello" || echo 000)
  [ "$code" = "200" ] && ok "$1 /hello -> 200" || finding "$1 /hello -> $code" "component unhealthy or still starting" "check its pod logs; ensure Redis/DB reachable"
}
probe gateway 18080 8080
probe dashboard 13000 3000

# ---- 4. Operator: stuck TykOasApiDefinitions --------------------------------
say "4) Operator API resources"
if kubectl get crd tykoasapidefinitions.tyk.tyk.io >/dev/null 2>&1; then
  STUCK=$(kubectl get tykoasapidefinition -n "$NS" -o json 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: sys.exit()
for it in d.get('items',[]):
    st=it.get('status',{}).get('latestTransaction',{}).get('status','')
    if st and st!='Successful': print(it['metadata']['name']+'|'+st)
" 2>/dev/null)
  if [ -z "$STUCK" ]; then ok "all TykOasApiDefinitions reconciled"; else
    while IFS='|' read -r name st; do
      [ -z "$name" ] && continue
      finding "TykOasApiDefinition '$name' status=$st" \
        "reconcile error, or a ConfigMap-only edit that didn't sync" \
        "re-apply the CR; for a versioned base see the version-apis guardrail (docs)"
    done <<< "$STUCK"
    if [ "$HEAL" = "1" ]; then
      say "   HEAL: nudging stuck resources to re-reconcile"
      while IFS='|' read -r name st; do
        [ -z "$name" ] && continue
        kubectl annotate tykoasapidefinition "$name" -n "$NS" tyk-launchpad/heal-nudge="retry" --overwrite >/dev/null 2>&1 \
          && info "   annotated $name to trigger reconcile (re-check status shortly)"
      done <<< "$STUCK"
    fi
  fi
else info "Operator CRDs not installed (skip)"; fi

# ---- 5. cert-manager (Operator prereq) --------------------------------------
say "5) cert-manager"
if kubectl get ns cert-manager >/dev/null 2>&1; then
  wait_ready cert-manager "" 5 && ok "cert-manager ready" || finding "cert-manager not ready" "pods still starting or misconfigured" "check cert-manager pods; Operator webhooks depend on it"
else info "cert-manager namespace not present (only needed for the Operator)"; fi

# ---- summary ----------------------------------------------------------------
say "Summary"
if [ "$FINDINGS" = "0" ]; then ok "healthy — no issues found in '$NS'"; else
  info "$FINDINGS finding(s)"; [ "$HEAL" = "1" ] && info "$HEALED auto-repaired"
  [ "$HEAL" = "0" ] && info "re-run with HEAL=1 to apply the safe repairs above:  NS=$NS HEAL=1 bash lib/doctor.sh"
fi
