#!/usr/bin/env bash
# Thin authenticated client for the Tyk Enterprise Developer Portal API, per the
# official contract in vendor/tyk-docs/swagger/enterprise-developer-portal-swagger.yaml.
# Base path is /portal-api; auth is the admin token in the Authorization header.
#
#   lib/portal-api.sh GET  /products
#   lib/portal-api.sh POST /plans      body.json
#   lib/portal-api.sh POST /catalogues body.json
#
# Env:
#   PORTAL_URL    required   portal origin, e.g. http://localhost:3001
#   PORTAL_TOKEN  required   admin authorisation token (never printed/committed)
#   PORTAL_BASE   /portal-api   API base path (from the swagger `servers`)
#   DRY_RUN       0          1 = validate + show the request, do NOT call the portal
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

METHOD="${1:?usage: portal-api.sh <METHOD> <PATH> [body.json]}"
APIPATH="${2:?usage: portal-api.sh <METHOD> <PATH> [body.json]}"
BODY="${3:-}"
: "${PORTAL_BASE:=/portal-api}"; : "${DRY_RUN:=0}"

if [ -n "$BODY" ]; then
  [ -f "$BODY" ] || die "body file not found: $BODY"
  python3 -c "import json,sys; json.load(open('$BODY'))" || die "body is not valid JSON: $BODY"
fi

if [ "$DRY_RUN" = "1" ]; then
  say "DRY_RUN — would call the portal (no request sent)"
  info "$METHOD \${PORTAL_URL}${PORTAL_BASE}${APIPATH}"
  [ -n "$BODY" ] && { info "body ($BODY):"; sed 's/^/    /' "$BODY"; }
  exit 0
fi

: "${PORTAL_URL:?set PORTAL_URL (e.g. http://localhost:3001)}"
: "${PORTAL_TOKEN:?set PORTAL_TOKEN (portal admin authorisation token)}"
URL="${PORTAL_URL}${PORTAL_BASE}${APIPATH}"

say "$METHOD $URL"
if [ -n "$BODY" ]; then
  RESP=$(curl -s -w '\n%{http_code}' -X "$METHOD" "$URL" \
    -H "Authorization: $PORTAL_TOKEN" -H "Content-Type: application/json" \
    --data-binary @"$BODY")
else
  RESP=$(curl -s -w '\n%{http_code}' -X "$METHOD" "$URL" -H "Authorization: $PORTAL_TOKEN")
fi
CODE=$(printf '%s' "$RESP" | tail -1); BODYOUT=$(printf '%s' "$RESP" | sed '$d')
printf '%s\n' "$BODYOUT" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$BODYOUT"
case "$CODE" in
  2*) ok "HTTP $CODE" ;;
  *)  die "HTTP $CODE" ;;
esac
