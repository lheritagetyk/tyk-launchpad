#!/usr/bin/env bash
# Build a deployable portal theme = official default theme (vendor/portal-default-theme)
# + our brand overlay (portal-theme/). Output is a gitignored build artifact, like
# compiling — no Tyk-shipped code is copied into the tracked tree.
#
# Produces dist/<name>-theme.zip ready for `lib/upload-theme.sh`.
#
# Env:
#   THEME_SRC   auto   base theme dir (default: vendor/portal-default-theme/src)
#   OVERLAY     auto   overlay dir (default: portal-theme)
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

THEME_SRC="${THEME_SRC:-$LAUNCHPAD_ROOT/vendor/portal-default-theme/src}"
OVERLAY="${OVERLAY:-$LAUNCHPAD_ROOT/portal-theme}"
BUILD="$LAUNCHPAD_ROOT/.build/theme"
DIST="$LAUNCHPAD_ROOT/dist"

[ -d "$THEME_SRC" ] || die "base theme missing at $THEME_SRC — run: bash lib/ensure-sources.sh ensure"
# Seed the working overlay from the shipped templates on first use (the real overlay is
# gitignored — it's the customer's own branding, not toolkit content).
[ -f "$OVERLAY/overlay.json" ] || { [ -f "$OVERLAY/overlay.json.example" ] && cp "$OVERLAY/overlay.json.example" "$OVERLAY/overlay.json" && info "seeded overlay.json from template — edit it with your brand"; }
[ -f "$OVERLAY/brand.css" ]   || { [ -f "$OVERLAY/brand.css.example" ]   && cp "$OVERLAY/brand.css.example"   "$OVERLAY/brand.css"; }
[ -f "$OVERLAY/overlay.json" ] || die "overlay.json missing in $OVERLAY (and no overlay.json.example to seed from)"
require python3; require zip

NAME=$(python3 -c "import json;print(json.load(open('$OVERLAY/overlay.json'))['name'])")
[ "$NAME" != "default" ] || die "overlay name must NOT be 'default' (the portal forbids editing the default theme)"

say "1) Stage official theme -> build dir"
rm -rf "$BUILD"; mkdir -p "$BUILD" "$DIST"
cp -R "$THEME_SRC/." "$BUILD/"
ok "staged $(find "$BUILD" -type f | wc -l | tr -d ' ') files"

say "2) Apply overlay '$NAME'"
# 2a. stamp theme.json (name/version/author) — rename is REQUIRED
python3 - "$BUILD/theme.json" "$OVERLAY/overlay.json" <<'PY'
import json,sys
tj=json.load(open(sys.argv[1])); ov=json.load(open(sys.argv[2]))
for k in ("name","version","author"):
    if k in ov: tj[k]=ov[k]
json.dump(tj,open(sys.argv[1],'w'),indent=2)
print("   theme.json name ->", tj["name"])
PY
# 2b. brand.css — append after the theme's main.css so our vars win
if [ -f "$OVERLAY/brand.css" ]; then
  printf '\n/* --- tyk-launchpad brand overlay --- */\n' >> "$BUILD/assets/stylesheets/main.css"
  cat "$OVERLAY/brand.css" >> "$BUILD/assets/stylesheets/main.css"
  ok "brand.css appended to assets/stylesheets/main.css"
fi
# 2c. asset overrides — any file under portal-theme/assets replaces the same theme path
if [ -d "$OVERLAY/assets" ]; then
  (cd "$OVERLAY/assets" && find . -type f) | while read -r rel; do
    mkdir -p "$BUILD/assets/$(dirname "$rel")"
    cp "$OVERLAY/assets/$rel" "$BUILD/assets/$rel"
    ok "override asset: assets/$rel"
  done
fi

say "3) Validate upload limits (per-file < 5MB)"
BIG=$(find "$BUILD" -type f -size +5M 2>/dev/null || true)
[ -z "$BIG" ] || die "these files exceed the 5MB per-file portal limit:\n$BIG"
ok "all files within per-file limit"

say "4) Zip -> dist/$NAME-theme.zip"
ZIP="$DIST/$NAME-theme.zip"; rm -f "$ZIP"
(cd "$BUILD" && zip -qr "$ZIP" .)
ok "built $ZIP ($(du -h "$ZIP" | cut -f1))"
info "next: PORTAL_URL=... PORTAL_TOKEN=... THEME_ZIP=$ZIP bash lib/upload-theme.sh"
