#!/usr/bin/env bash
# Fetch the official Tyk source repos FRESH into vendor/ (a gitignored runtime cache).
# We never commit or copy Tyk-shipped code — we clone the latest official repos on
# first use and offer to update them thereafter.
#
#   lib/ensure-sources.sh            # ensure present: clone any that are missing (first run)
#   lib/ensure-sources.sh check      # report which sources have a newer version upstream
#   lib/ensure-sources.sh update [name...]   # pull latest for all (or the named) sources
#
# The agent runs `ensure` on first use, then `check`, and ASKS the user before `update`.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

VENDOR="$LAUNCHPAD_ROOT/vendor"
mkdir -p "$VENDOR"

# name | git url | ref (branch) | mode(full|sparse)
SOURCES=(
  "tyk-install|https://github.com/TykTechnologies/tyk-install.git|main|full"
  "portal-default-theme|https://github.com/TykTechnologies/portal-default-theme.git|main|full"
  "tyk-plugin-starter|https://github.com/TykTechnologies/tyk-plugin-starter.git|main|full"
  "tyk-docs|https://github.com/TykTechnologies/tyk-docs.git|main|sparse"
)

_clone() { # name url ref mode
  local name=$1 url=$2 ref=$3 mode=$4 dir="$VENDOR/$1"
  if [ "$mode" = "sparse" ]; then
    # docs grounding only — blobless + sparse so we skip the ~292M of images
    git clone --depth 1 --filter=blob:none --sparse --branch "$ref" "$url" "$dir" >/dev/null 2>&1 \
      || die "clone failed: $url"
    # keep everything except the ~292M of images; swagger stays (authoritative API contracts)
    git -C "$dir" sparse-checkout set --no-cone '/*' '!/img/' >/dev/null 2>&1
  else
    git clone --depth 1 --branch "$ref" "$url" "$dir" >/dev/null 2>&1 || die "clone failed: $url"
  fi
  ok "$name @ $(git -C "$dir" rev-parse --short HEAD) (fresh clone, ref=$ref)"
}

_remote_sha() { git ls-remote "$1" "refs/heads/$2" 2>/dev/null | cut -f1; }
_local_sha()  { git -C "$1" rev-parse HEAD 2>/dev/null; }

cmd_ensure() {
  say "Fetching the official Tyk sources into vendor/ (fresh clone, not committed)"
  local cloned=0
  for s in "${SOURCES[@]}"; do IFS='|' read -r name url ref mode <<<"$s"
    if [ -d "$VENDOR/$name/.git" ]; then
      ok "$name present @ $(_local_sha "$VENDOR/$name" | cut -c1-7)"
    else
      info "cloning $name (latest, ref=$ref)…"; _clone "$name" "$url" "$ref" "$mode"; cloned=1
    fi
  done
  say "Sources ready."
  info "Next: tell the agent what you want, or run ./launch.sh to install."
  [ "$cloned" = "0" ] && info "(already had everything — run 'check' to look for updates)"
}

cmd_check() {
  say "Checking for newer official versions upstream"
  local any=0
  for s in "${SOURCES[@]}"; do IFS='|' read -r name url ref mode <<<"$s"
    [ -d "$VENDOR/$name/.git" ] || { warn "$name not present yet (run: ensure)"; continue; }
    local r l; r=$(_remote_sha "$url" "$ref"); l=$(_local_sha "$VENDOR/$name")
    if [ -n "$r" ] && [ "${r:0:12}" != "${l:0:12}" ]; then
      warn "$name — UPDATE available (local ${l:0:7} → upstream ${r:0:7}, ref=$ref)"; any=1
    else
      ok "$name up to date (${l:0:7})"
    fi
  done
  [ "$any" = "0" ] && info "all sources current" || info "run: lib/ensure-sources.sh update   (or name a source)"
}

cmd_update() {
  local want=("$@")
  say "Updating official sources to latest"
  for s in "${SOURCES[@]}"; do IFS='|' read -r name url ref mode <<<"$s"
    if [ ${#want[@]} -gt 0 ]; then case " ${want[*]} " in *" $name "*) ;; *) continue;; esac; fi
    if [ ! -d "$VENDOR/$name/.git" ]; then info "$name absent — cloning"; _clone "$name" "$url" "$ref" "$mode"; continue; fi
    git -C "$VENDOR/$name" fetch --depth 1 origin "$ref" >/dev/null 2>&1 || { warn "$name fetch failed"; continue; }
    git -C "$VENDOR/$name" reset --hard "origin/$ref" >/dev/null 2>&1
    [ "$mode" = "sparse" ] && git -C "$VENDOR/$name" sparse-checkout reapply >/dev/null 2>&1
    ok "$name updated → $(_local_sha "$VENDOR/$name" | cut -c1-7)"
  done
}

case "${1:-ensure}" in
  ensure) cmd_ensure ;;
  check)  cmd_check ;;
  update) shift; cmd_update "$@" ;;
  *) die "usage: ensure-sources.sh [ensure|check|update [name...]]" ;;
esac
