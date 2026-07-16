#!/usr/bin/env bash
# Guardrail: fail if any Tyk-shipped artifact has been copied OUT of vendor/.
# Enforces the "reference, never duplicate" rule. Run in CI and locally.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

# 1. No values.yaml / .env.example / chart templates outside vendor/ (ignore build artifacts)
while IFS= read -r f; do
  echo "COPIED Tyk artifact outside vendor/: $f"; fail=1
done < <(find . -path ./vendor -prune -o -path ./.git -prune -o \
           -path ./.build -prune -o -path ./dist -prune -o -path ./.render -prune -o \
           \( -name 'values.yaml' -o -name '.env.example' -o -name 'Chart.yaml' \) -print 2>/dev/null)

# 2. portal-theme/ must be an OVERLAY (diffs), not a full copy of the vendored theme.
#    Heuristic: flag if it contains a src/ tree mirroring the vendored theme root.
if [ -d portal-theme/src ] && [ -d vendor/portal-default-theme/src ]; then
  echo "portal-theme/src looks like a full theme copy — keep only your overlay diff."; fail=1
fi

[ "$fail" = "0" ] && echo "no-vendor-copy: OK (nothing Tyk-shipped copied outside vendor/)"
exit $fail
