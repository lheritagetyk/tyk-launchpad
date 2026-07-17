#!/usr/bin/env bash
# Scaffold a NEW portal theme project in a directory the customer chooses, starting from
# the official portal-default-theme. This is the documented workflow (copy the default
# theme, rename it, modify it) — the scaffolded theme is the customer's own artifact, not
# committed to tyk-launchpad.
#
#   NAME=my-brand DEST=~/themes bash lib/new-theme.sh   # creates ~/themes/my-brand
#
# Env:
#   NAME   required   theme name (also stamped into theme.json; MUST NOT be "default")
#   DEST   required   parent directory to create the theme in (ask the user)
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${NAME:?set NAME (your theme name, e.g. NAME=acme-brand)}"
: "${DEST:?set DEST (directory to create the theme in — ask the user where they want it)}"
[ "$NAME" != "default" ] || die "theme name must NOT be 'default' (the portal forbids editing the default theme)"

STARTER="$LAUNCHPAD_ROOT/vendor/portal-default-theme"
SRC="$STARTER/src"
TARGET="${DEST%/}/$NAME"

require python3
[ -e "$TARGET" ] && die "target already exists: $TARGET (choose another NAME or DEST)"
[ -d "$SRC" ] || { info "fetching portal-default-theme…"; bash "$LAUNCHPAD_ROOT/lib/ensure-sources.sh" ensure >/dev/null 2>&1; }
[ -d "$SRC" ] || die "portal-default-theme not available — check network/git access"

# Match the theme to the deployed portal release if we can see it (themes are per-release).
PORTAL_IMG=$(kubectl get deploy,statefulset -A -o jsonpath='{range .items[*]}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null | grep -i dev-portal | head -1) || true
[ -n "$PORTAL_IMG" ] && info "deployed portal image: $PORTAL_IMG — if this is a released version, check out the matching portal-default-theme tag before scaffolding (git -C vendor/portal-default-theme tag)"

say "Scaffolding theme '$NAME' from the official portal-default-theme -> $TARGET"
mkdir -p "$TARGET"
( cd "$SRC" && tar -cf - . ) | ( cd "$TARGET" && tar -xf - )

# rename in the manifest (required — the portal will not accept a theme named "default")
python3 - "$TARGET/theme.json" "$NAME" <<'PY'
import json,sys
p=sys.argv[1]; tj=json.load(open(p)); tj["name"]=sys.argv[2]
json.dump(tj,open(p,'w'),indent=2)
PY
ok "created $TARGET (theme.json name = $NAME)"

say "Customize it (documented in vendor/tyk-docs/portal/customization/branding.mdx)"
info "  logo:   $TARGET/assets/images/dev-portal-logo.svg"
info "  colors: $TARGET/assets/stylesheets/main.css   (the --tdp-* CSS variables)"
say "Then deploy"
info "  THEME_DIR=$TARGET PORTAL_URL=… PORTAL_TOKEN=… bash lib/upload-theme.sh"
