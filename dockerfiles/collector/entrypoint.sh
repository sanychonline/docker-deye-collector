#!/bin/sh
set -e

echo "Starting Deye collector..."

(
  while true; do
    /opt/deye/deye-connector.sh || echo "collector failed"
    sleep 5
  done
) &

echo "Starting HTTP server..."
python3 -m http.server 9101 --directory /metrics &

echo "Starting Alloy..."
exec alloy run /etc/alloy/config.alloy