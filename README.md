# tyk-launchpad

Get a working, correctly-configured **Tyk** deployment fast — guided, repeatable, and
built **entirely on the official [`tyk-install`](https://github.com/TykTechnologies/tyk-install)
repo**. tyk-launchpad copies no Tyk code: it clones the official repos fresh at runtime
and drives them, so you always run the latest official Tyk — just faster. On later runs
it checks for newer official versions and asks before updating.

Two ways to use it:
- **Plain:** run `./launch.sh` and answer a couple of prompts.
- **With Claude Code / an AI IDE:** open the repo and say *"install Tyk to my k8s cluster."*
  The `deploy-tyk` skill drives the same scripts and helps troubleshoot.

## What's here now
- ✅ Kubernetes / **Self-Managed** (Gateway + Dashboard + Pump + Portal + Redis + Postgres)
- ⏳ Docker substrate, Hybrid, Operator, config bootstrap (org/API/policy/portal), portal theme

## Prerequisites
- A Kubernetes cluster + `kubectl` pointed at it
- Helm 3.12+
- A Tyk license key

## Quick start
```bash
git clone <this-repo> && cd tyk-launchpad

# 1. Fetch the latest official Tyk sources into vendor/ (also runs automatically):
bash lib/ensure-sources.sh          # `check` for updates, `update` to pull latest

# 2. Set your license the official way (separate terminal):
cp vendor/tyk-install/kubernetes/helm-self-managed/.env.example \
   vendor/tyk-install/kubernetes/helm-self-managed/.env
#   edit that .env and set TYK_LICENSE_KEY

# 3. Preview what would be deployed — touches nothing:
RENDER_ONLY=1 ./launch.sh

# 4. Deploy (into namespace 'tyk' by default):
./launch.sh
```

### Protecting an existing install
tyk-launchpad **refuses to deploy into a namespace that already holds a Tyk release.**
If you already run Tyk in `tyk`, deploy an evaluation elsewhere:
```bash
NS=tyk-eval ./launch.sh
```
Use `FORCE=1` only if you truly intend to reuse an occupied namespace.

## Knobs (env vars)
| var | default | meaning |
|-----|---------|---------|
| `NS` | `tyk` | target namespace |
| `RELEASE` | `tyk` | Helm release name |
| `RENDER_ONLY` | `0` | `1` = template manifests only, never touch the cluster |
| `FORCE` | `0` | `1` = allow reusing a namespace with an existing release |

## Design
See `CLAUDE.md` for the agent contract and the hard rules (never copy Tyk code, stay
vanilla, protect existing installs, official license + API handling). Official repos are
cloned fresh into `vendor/` at runtime (gitignored — nothing Tyk-shipped is committed);
`ci/no-vendor-copy.sh` enforces that nothing Tyk-shipped is copied out.
