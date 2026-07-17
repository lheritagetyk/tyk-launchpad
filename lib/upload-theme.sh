#!/usr/bin/env bash
# Upload + activate a portal theme via the official Tyk Enterprise Developer Portal API
# (POST /themes/upload, POST /themes/{id}/activate). Auth = portal admin authorisation
# token (see vendor/tyk-docs/product-stack/tyk-enterprise-developer-portal/api-documentation/tyk-edp-api.mdx).
#
# Env (give it a theme directory OR a prebuilt zip):
#   THEME_DIR    a scaffolded theme dir (see lib/new-theme.sh) — zipped here
#   THEME_ZIP    or a prebuilt theme zip
#   PORTAL_URL   required   e.g. http://localhost:3001  (or the portal service URL)
#   PORTAL_TOKEN required   admin authorisation token (never printed/committed)
#   ACTIVATE     1          also activate the uploaded theme (set 0 to skip)
#   DRY_RUN      0          1 = validate inputs + zip, do NOT call the portal
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${ACTIVATE:=1}"; : "${DRY_RUN:=0}"; : "${THEME_DIR:=}"; : "${THEME_ZIP:=}"

# If given a theme directory, validate the portal's 5MB/file limit and zip it.
if [ -n "$THEME_DIR" ]; then
  [ -d "$THEME_DIR" ] || die "THEME_DIR not found: $THEME_DIR"
  [ -f "$THEME_DIR/theme.json" ] || die "$THEME_DIR is not a theme (no theme.json)"
  require zip
  BIG=$(find "$THEME_DIR" -type f -size +5M 2>/dev/null || true)
  [ -z "$BIG" ] || die "these files exceed the 5MB per-file portal limit:\n$BIG"
  TNAME=$(python3 -c "import json;print(json.load(open('$THEME_DIR/theme.json'))['name'])")
  [ "$TNAME" != "default" ] || die "theme.json name is 'default' — rename it (the portal forbids editing the default theme)"
  mkdir -p "$LAUNCHPAD_ROOT/dist"
  THEME_ZIP="$LAUNCHPAD_ROOT/dist/$TNAME-theme.zip"; rm -f "$THEME_ZIP"
  ( cd "$THEME_DIR" && zip -qr "$THEME_ZIP" . )
  ok "packed $THEME_DIR -> $THEME_ZIP ($(du -h "$THEME_ZIP" | cut -f1))"
fi

: "${THEME_ZIP:?set THEME_DIR (a scaffolded theme dir) or THEME_ZIP (a prebuilt zip)}"
[ -f "$THEME_ZIP" ] || die "THEME_ZIP not found: $THEME_ZIP"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY_RUN — validating without calling the portal"
  unzip -l "$THEME_ZIP" >/dev/null 2>&1 || die "not a valid zip: $THEME_ZIP"
  ok "zip valid: $THEME_ZIP ($(du -h "$THEME_ZIP" | cut -f1))"
  info "would POST $THEME_ZIP -> \$PORTAL_URL/themes/upload  then activate"
  exit 0
fi

: "${PORTAL_URL:?set PORTAL_URL (e.g. http://localhost:3001)}"
: "${PORTAL_TOKEN:?set PORTAL_TOKEN (portal admin authorisation token)}"

say "Uploading theme -> $PORTAL_URL/themes/upload"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$PORTAL_URL/themes/upload" \
  -H "Authorization: $PORTAL_TOKEN" \
  -F "file=@$THEME_ZIP")
CODE=$(printf '%s' "$RESP" | tail -1); BODY=$(printf '%s' "$RESP" | sed '$d')
[ "$CODE" = "200" ] || [ "$CODE" = "201" ] || die "upload failed (HTTP $CODE): $BODY"
ok "uploaded (HTTP $CODE)"

if [ "$ACTIVATE" = "1" ]; then
  TID=$(printf '%s' "$BODY" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(d.get('id') or d.get('theme_id') or d.get('ID') or '')
except Exception: print('')" 2>/dev/null)
  if [ -n "$TID" ]; then
    say "Activating theme $TID"
    AC=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$PORTAL_URL/themes/$TID/activate" -H "Authorization: $PORTAL_TOKEN")
    [ "$AC" = "200" ] && ok "activated theme $TID" || warn "activate returned HTTP $AC — activate manually in the portal"
  else
    warn "could not parse theme id from upload response — activate in the portal UI (Themes)"
  fi
fi
say "Done"
