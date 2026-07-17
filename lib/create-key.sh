#!/usr/bin/env bash
# Create a Tyk access key via the Dashboard API (POST /api/keys), bound to a policy.
# Binding to a policy is what avoids the classic versioning 403: the policy grants the
# base AND child version Ids, so the key inherits access to every version at once.
#
# Env:
#   DASH_URL     http://localhost:3300   Dashboard base URL
#   DASH_TOKEN   required   Dashboard user API access key (Authorization header)
#   POLICY_ID    required   policy id to bind (SecurityPolicy .status.pol_id)
#   ALIAS        launchpad-test-key      key alias
#   DRY_RUN      0          1 = show the request, send nothing
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${DASH_URL:=http://localhost:3300}"
: "${ALIAS:=launchpad-test-key}"
: "${DRY_RUN:=0}"
: "${POLICY_ID:?set POLICY_ID (SecurityPolicy .status.pol_id — see lib/apply-policy.sh)}"

BODY=$(cat <<JSON
{ "alias": "$ALIAS", "apply_policies": ["$POLICY_ID"] }
JSON
)

if [ "$DRY_RUN" = "1" ]; then
  say "DRY_RUN — would create a key (no request sent)"
  info "POST \$DASH_URL/api/keys"
  printf '%s\n' "$BODY" | sed 's/^/    /'
  exit 0
fi

: "${DASH_TOKEN:?set DASH_TOKEN (Dashboard user API access key)}"
say "Creating access key bound to policy $POLICY_ID"
RESP=$(curl -s -w '\n%{http_code}' -X POST "$DASH_URL/api/keys" \
  -H "Authorization: $DASH_TOKEN" -H "Content-Type: application/json" \
  --data-binary "$BODY")
CODE=$(printf '%s' "$RESP" | tail -1); OUT=$(printf '%s' "$RESP" | sed '$d')
[ "$CODE" = "200" ] || die "key creation failed (HTTP $CODE): $OUT"
KEY=$(printf '%s' "$OUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('key_id',''))" 2>/dev/null)
ok "key created"
[ -n "$KEY" ] && { info "key: $KEY"; info "test:  curl -H 'Authorization: $KEY' \$GW_URL/<listenPath>/"; } \
              || printf '%s\n' "$OUT"
