# tyk-launchpad

Your **Tyk professional-services engineer, as an AI agent.** Open this repo in Claude Code
(or any AI IDE) and just talk to it — it deploys, configures, and troubleshoots Tyk for you,
grounded entirely in **official Tyk sources**. It copies no Tyk code: it clones the official
repos fresh at runtime and drives them, so you always run the latest official Tyk — just faster.
On later runs it checks for newer versions and asks before updating.

## What it can do
- **Install** — stand up a full Tyk stack on Kubernetes (Gateway, Dashboard, Pump, Portal,
  Redis, Postgres, Operator) from the official `tyk-install`.
- **Author APIs** — scaffold + deploy Tyk OAS APIs via the Tyk Operator (CRDs).
- **Version APIs** — base/child OAS versioning.
- **Brand the portal** — customize + deploy a developer-portal theme (logo, colors) on top
  of the official default theme.
- **Products & plans** — package APIs into products/plans and publish to the portal catalogue.
- **Write plugins** — scaffold, build, and deploy a Tyk gateway plugin from the official
  `tyk-plugin-starter`.
- **Self-heal** — diagnose and repair a broken/unhealthy install.
- **Debug & answer** — troubleshoot and answer Tyk questions grounded in the official docs
  and any TykTechnologies repo.

## Use it (the easy way)
Open Claude Code and say, for example:
> *"Clone https://github.com/lheritagetyk/tyk-launchpad and help me install Tyk to my cluster."*

or, once you're in the repo:
> *"What can you help me with?"*  /  *"Add an API called payments to Tyk."*  /  *"Brand the portal."*

The agent reads `CLAUDE.md` + the skills in `.claude/skills/`, fetches the official sources,
checks your environment, and only asks you for the few things it can't do itself (your license,
which cluster, approvals).

## Prerequisites
- A Kubernetes cluster + `kubectl` pointed at it, and Helm 3.12+ (for deploys)
- A Tyk license key (for deploys)
- `git`, `python3`; the agent uses `gh` for GitHub lookups when debugging

## Without an AI IDE
Everything runs as plain scripts too:
```bash
git clone https://github.com/lheritagetyk/tyk-launchpad && cd tyk-launchpad

bash lib/ensure-sources.sh          # fetch official sources (check / update also available)

# Set your license the official way (separate terminal):
cp vendor/tyk-install/kubernetes/helm-self-managed/.env.example \
   vendor/tyk-install/kubernetes/helm-self-managed/.env
#   edit that .env and set TYK_LICENSE_KEY

RENDER_ONLY=1 ./launch.sh           # preview the install — touches nothing
./launch.sh                         # deploy (k8s self-managed)
```
Each capability is a script under `lib/` (`scaffold-oas.py`, `apply-oas-crd.sh`,
`set-versioning.py`, `build-theme.sh`, `upload-theme.sh`, `portal-api.sh`, …). See the
matching skill in `.claude/skills/` for how they fit together.

## Protecting an existing install
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
| `RENDER_ONLY` | `0` | `1` = template/preview only, never touch the cluster |
| `FORCE` | `0` | `1` = allow reusing a namespace with an existing release |

## What's built vs. planned
Built: install (k8s self-managed), author APIs, version APIs, portal theme, products/plans,
debug/ask. Planned: Docker substrate, Hybrid and standalone-Operator topologies.

## Works with any AI IDE
Using **Claude Code**? `CLAUDE.md` + the skills in `.claude/skills/` are the richer path.
Using **Cursor / Copilot / Codex / another LLM**? The root **`AGENTS.md`** is a tool-neutral
brief that maps every capability to the `lib/` scripts — so the toolkit works the same in any
agent.

## Design
See `CLAUDE.md` (or `AGENTS.md`) for the agent contract and hard rules: never copy Tyk code, stay vanilla
(official defaults), protect existing installs, official license + API handling, ground every
answer in official docs (`vendor/tyk-docs`). Official repos are cloned fresh into `vendor/` at
runtime (gitignored — nothing Tyk-shipped is committed); `ci/no-vendor-copy.sh` enforces it.
