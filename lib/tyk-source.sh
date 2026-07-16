#!/usr/bin/env bash
# Fetch ANY official TykTechnologies repo on demand, for debugging / answering
# questions (source code, configs, tests). Shallow-clones into vendor/_ref/<repo>
# (gitignored cache). Reference only — never copy this code into the project tree.
#
#   lib/tyk-source.sh <repo> [ref]      # clone/update github.com/TykTechnologies/<repo>
#   lib/tyk-source.sh tyk               # e.g. the Gateway source (OSS)
#   lib/tyk-source.sh tyk-pump          # the Pump source (OSS)
#   lib/tyk-source.sh tyk-operator legacy   # archived repos: pass the branch that has code
#
# NOTE: some repos are archived or closed-source. e.g. tyk-operator went CLOSED-SOURCE
# in Oct 2024 — the repo is archived, pre-close code lives on the `legacy` branch, and
# the DOCS (vendor/tyk-docs) are canonical for the Operator. When unsure a repo is
# current, discover it first:  gh search repos --owner TykTechnologies "<keyword>"
#
# Then grep vendor/_ref/<repo> to ground your answer. For issues/PRs, prefer `gh`:
#   gh search issues --owner TykTechnologies "<query>"
#   gh issue list --repo TykTechnologies/<repo> --search "<query>"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

REPO="${1:?usage: tyk-source.sh <repo> [ref]}"
REF="${2:-}"
DIR="$LAUNCHPAD_ROOT/vendor/_ref/$REPO"
URL="https://github.com/TykTechnologies/$REPO.git"
mkdir -p "$LAUNCHPAD_ROOT/vendor/_ref"

if [ -d "$DIR/.git" ]; then
  say "Updating vendor/_ref/$REPO"
  git -C "$DIR" fetch --depth 1 origin "${REF:-HEAD}" >/dev/null 2>&1 || true
  git -C "$DIR" reset --hard "${REF:+origin/$REF}" >/dev/null 2>&1 || git -C "$DIR" reset --hard @{u} >/dev/null 2>&1 || true
else
  say "Cloning github.com/TykTechnologies/$REPO (shallow, reference-only)"
  if [ -n "$REF" ]; then
    git clone --depth 1 --branch "$REF" "$URL" "$DIR" >/dev/null 2>&1 || die "clone failed — is '$REPO' a real TykTechnologies repo? (check: gh repo view TykTechnologies/$REPO)"
  else
    git clone --depth 1 "$URL" "$DIR" >/dev/null 2>&1 || die "clone failed — is '$REPO' a real TykTechnologies repo?"
  fi
fi
ok "$REPO @ $(git -C "$DIR" rev-parse --short HEAD) -> vendor/_ref/$REPO"
info "grep it, e.g.:  grep -rn \"<symbol>\" vendor/_ref/$REPO --include='*.go'"
