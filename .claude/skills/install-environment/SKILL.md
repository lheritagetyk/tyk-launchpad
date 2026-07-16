---
name: deploy-tyk
description: Deploy and configure Tyk (Gateway/Dashboard/Portal) onto Kubernetes or Docker by driving the official tyk-install repo. Use when the user wants to install, deploy, stand up, or configure Tyk.
---

# Deploy Tyk

You drive the official `vendor/tyk-install`, cloned fresh at runtime — you never copy
or reinvent it. Read `CLAUDE.md` in the repo root first; its hard rules override any
default behavior.

## Flow
0. **Sources** — `bash lib/ensure-sources.sh ensure` (clones latest official repos on
   first use). Then `bash lib/ensure-sources.sh check`; if it reports newer versions,
   ASK the user whether to `update` before continuing. `launch.sh` runs `ensure` for you.
1. **Preflight** — `bash lib/preflight.sh`. Surface: current kube context (confirm it's
   the cluster they mean), missing tools, namespace safety, whether a license is set.
2. **Confirm target** — release/namespace. Default namespace is `tyk` (official), but if
   preflight reports an existing Tyk release, propose a different namespace
   (`NS=tyk-eval`); only reuse `tyk` if the user says so (`FORCE=1`).
3. **License** — if unset, ask the user to (in their own terminal) copy `.env.example`
   to `.env` in `vendor/tyk-install/kubernetes/helm-self-managed/` and set
   `TYK_LICENSE_KEY`. Never handle the license value yourself.
4. **Deploy** — `./launch.sh` (or `RENDER_ONLY=1 ./launch.sh` to preview manifests
   without touching the cluster).
5. **Verify** — `bash lib/verify.sh`; report gateway/dashboard `/hello` and pod status.
6. **Report** — endpoints + how to reach them; do not print secrets.

## Safety
- Never deploy into a namespace with an existing Tyk release unless the user explicitly
  forces it. This protects running demos and customer environments.
- `RENDER_ONLY=1` is the safe way to show what would happen.

## Only self-managed on k8s is implemented today
For Docker / Hybrid / Operator / portal-bootstrap, say they're not built yet.
