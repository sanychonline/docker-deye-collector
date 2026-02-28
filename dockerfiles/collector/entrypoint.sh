#!/bin/sh
set -e

echo "Starting Deye collector..."

(
  while true; do
    /opt/deye/deye-connector.sh || echo "collector failed"
    sleep 60
  done
) &

echo "Starting metrics HTTP server..."
python3 -m http.server 9101 --directory /metrics &

echo "Starting API server..."
python /opt/deye/api.py &

echo "Starting Alloy..."
exec alloy run /etc/alloy/config.alloy