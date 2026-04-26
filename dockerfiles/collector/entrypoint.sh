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

echo "Starting API UI..."
/opt/venv/bin/gunicorn -w 2 -b 0.0.0.0:9090 api:app &

echo "Starting Alloy..."
exec alloy run /etc/alloy/config.alloy