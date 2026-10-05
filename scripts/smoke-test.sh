#!/usr/bin/env bash
# Usage: smoke-test.sh <base-url> [expected-version]
# Polls /health until it returns 200 (and the expected version, if given).
set -euo pipefail
URL="${1:?base url required}"; WANT="${2:-}"
for i in $(seq 1 30); do
  BODY=$(curl -fsS --max-time 5 "$URL/health" 2>/dev/null || true)
  if [ -n "$BODY" ] && { [ -z "$WANT" ] || echo "$BODY" | grep -q "$WANT"; }; then
    echo "OK on attempt $i: $BODY"; exit 0
  fi
  echo "attempt $i/30 not ready yet..."; sleep 10
done
echo "Smoke test FAILED for $URL"; exit 1
