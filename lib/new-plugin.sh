#!/usr/bin/env bash
# Scaffold a NEW Tyk plugin project from the official tyk-plugin-starter — the
# "start here" for Tyk plugins. The starter is designed to be used as a template;
# this creates the user's own project from it (fresh git history), it does not
# vendor Tyk code into tyk-launchpad.
#
#   NAME=my-plugin bash lib/new-plugin.sh            # scaffold ../my-plugin
#   NAME=my-plugin DEST=~/work bash lib/new-plugin.sh  # scaffold ~/work/my-plugin
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${NAME:?set NAME (your plugin project name, e.g. NAME=rate-tagger)}"
STARTER="$LAUNCHPAD_ROOT/vendor/tyk-plugin-starter"
# default: create alongside tyk-launchpad, not inside it (it's the customer's own project)
DEST="${DEST:-$(cd "$LAUNCHPAD_ROOT/.." && pwd)}"
TARGET="$DEST/$NAME"

require git
[ -e "$TARGET" ] && die "target already exists: $TARGET (choose another NAME or DEST)"
[ -d "$STARTER" ] || { info "fetching the plugin starter…"; bash "$LAUNCHPAD_ROOT/lib/ensure-sources.sh" ensure >/dev/null 2>&1; }
[ -d "$STARTER" ] || die "tyk-plugin-starter not available — check network/git access"

say "Scaffolding '$NAME' from the official tyk-plugin-starter"
mkdir -p "$TARGET"
# copy the starter (minus its git history and any build output) into the new project
( cd "$STARTER" && git archive --format=tar HEAD ) | ( cd "$TARGET" && tar -xf - )
ok "created $TARGET"

say "Making it your project (fresh git history)"
( cd "$TARGET" && git init -q && git add -A && git commit -q -m "Initial $NAME from tyk-plugin-starter" ) \
  && ok "git initialised" || warn "git init skipped"

say "Next steps (local loop — no Tyk gateway needed)"
info "  cd $TARGET"
info "  npm install"
info "  npm test          # runs in pure Node (vitest)"
info "  npm run build     # -> dist/plugin.js"
info "  npm run build:bundle   # -> dist/bundle.zip (deploy artifact)"
info "Grounding for writing the plugin: $STARTER/AGENTS.md and $STARTER/examples/"
