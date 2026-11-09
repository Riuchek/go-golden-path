#!/usr/bin/env bash
# Send a small mix of successful and declined orders so the RED dashboard moves.
# Usage: ./deploy/local/traffic.sh [base-url]
set -euo pipefail

url="${1:-http://localhost:8080}"

for i in $(seq 1 30); do
  curl -fsS -o /dev/null -X POST "${url}/v1/orders" \
    -H 'content-type: application/json' \
    -d '{"sku":"widget","qty":1}'
  if (( i % 5 == 0 )); then
    curl -fsS -o /dev/null -X POST "${url}/v1/orders" \
      -H 'content-type: application/json' \
      -H 'X-Demo-Fault: payment' \
      -d '{"sku":"widget","qty":1}' || true
  fi
done

echo "sent 30 orders, 6 of them declined"
