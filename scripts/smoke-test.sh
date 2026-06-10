#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://staging.dacn.local}"
TIMEOUT_SEC="${TIMEOUT_SEC:-10}"

base="${BASE_URL%/}"
paths=(
  "/"
  "/api/health"
  "/api/auth/health"
  "/api/products/health"
  "/api/order/health"
)

failed=false

for path in "${paths[@]}"; do
  url="$base$path"
  status="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_SEC" "$url" || true)"
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "PASS $url -> $status"
  else
    echo "FAIL $url -> ${status:-000}"
    failed=true
  fi
done

if [[ "$failed" == "true" ]]; then
  exit 1
fi

echo "Smoke test passed for $base"
