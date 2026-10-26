#!/bin/sh
# Simple traffic generator for the local demo.
#   ERROR_RATE - fraction of /api/simulate/error calls that return 500 (default 0.01)
#   SLOW_MS    - delay used for the occasional slow request (default 300)
# Trigger alerts:  ERROR_RATE=0.2 docker compose -f local/docker-compose.yml up -d loadgen
BASE="http://demo-api:8080"
i=0
echo "loadgen: error_rate=${ERROR_RATE} slow_ms=${SLOW_MS}"
while true; do
  i=$((i + 1))
  curl -s -o /dev/null "$BASE/api/orders"
  curl -s -o /dev/null "$BASE/api/orders/$((i % 6))"   # ids 0 and 5 return 404
  curl -s -o /dev/null "$BASE/api/simulate/error?rate=${ERROR_RATE}"
  if [ $((i % 10)) -eq 0 ]; then
    curl -s -o /dev/null "$BASE/api/simulate/latency?ms=${SLOW_MS}"
  fi
  sleep 0.2
done
