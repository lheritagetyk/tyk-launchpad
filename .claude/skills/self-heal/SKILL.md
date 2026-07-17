---
name: self-heal
description: Diagnose and repair a broken or unhealthy Tyk install. Use when the user says something is broken, not working, crashing, unreachable, stuck, or asks you to fix/heal/troubleshoot the deployment.
---

# Self-heal a Tyk install

You are the PS engineer fixing a live system. Work the loop: **diagnose → ground →
propose → (on confirm) repair → re-verify → repeat.** Read-only first; never guess.

## Loop
1. **Diagnose (read-only)** — `NS=<ns> bash lib/doctor.sh`. It scans pods, dependencies,
   gateway/dashboard `/hello`, Operator CRD reconcile status, and cert-manager, and prints
   findings each with a likely cause + fix.
2. **Ground** — for anything non-obvious, confirm the cause in the official docs
   (`vendor/tyk-docs`) or source (`bash lib/tyk-source.sh <repo>`), and read the actual
   logs: `kubectl logs`, `kubectl describe`, `kubectl get tykoasapidefinition -o yaml`.
   Cite where you confirmed it.
3. **Propose** — tell the user what's wrong and the exact fix. If it's a namespace running
   their workload, get an explicit OK before changing anything.
4. **Repair** — apply the safe fix. For the doctor's built-in safe repairs:
   `NS=<ns> HEAL=1 bash lib/doctor.sh` (rollout restart for post-reboot ordering crashes,
   wait-for-ready, re-reconcile a stuck CRD). For anything riskier, do it deliberately and
   explain it — never delete PVCs/namespaces/data as a "fix".
5. **Re-verify** — re-run `doctor` (and `lib/verify.sh` for installs) until healthy, or
   report clearly what's still stuck and what you'd try next.

## Known Tyk failure patterns (detect → documented fix, cite the source)
- **Pods CrashLoopBackOff right after a cluster/Docker restart** → dependency ordering
  (app started before Redis/Postgres were Ready). Fix: wait for deps, then
  `kubectl rollout restart` the app. Usually self-recovers.
- **TykOasApiDefinition stuck (not `Successful`)** → reconcile error or a ConfigMap-only
  edit that didn't sync. Re-apply the CR; a versioned *base* update has its own recovery —
  see the `version-apis` skill's guardrail. Confirm in docs +
  `gh search issues --owner TykTechnologies "<symptom>"`.
- **Gateway/Dashboard `/hello` ≠ 200 but pod Running** → Redis/DB connectivity or license.
  Check the pod logs; verify the `tyk-conf` secret and DB connection strings.
- **cert-manager not ready** → the Operator's webhooks depend on it; heal cert-manager first.

## Safety
Diagnose is always safe (read-only). Repairs are conservative and recoverable, gated behind
`HEAL=1`, and must never run against a namespace the user didn't ask you to fix. When unsure
whether a fix is safe, propose it and let the user decide.
