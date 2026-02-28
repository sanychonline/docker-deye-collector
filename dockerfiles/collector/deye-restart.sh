#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID not set}"
APP_SECRET="${APP_SECRET:?APP_SECRET not set}"
EMAIL="${EMAIL:?EMAIL not set}"
PASSWORD="${PASSWORD:?PASSWORD not set}"
DEVICE_SN="${DEVICE_SN:?DEVICE_SN not set}"
BASE_URL="${BASE_URL:?BASE_URL not set}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

login() {
  log "Login..."

  SHA256=$(printf "%s" "$PASSWORD" | sha256sum | awk '{print $1}')

  ACCESS_TOKEN=$(curl -s -X POST \
    "${BASE_URL}/v1.0/account/token?appId=${APP_ID}" \
    -H "Content-Type: application/json" \
    -d "{
          \"appSecret\": \"${APP_SECRET}\",
          \"email\": \"${EMAIL}\",
          \"password\": \"${SHA256}\"
        }" | jq -r '.accessToken')

  if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
    log "Login failed"
    exit 1
  fi

  log "Token OK"
}

read_state() {
  ORDER_ID=$(curl -s -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"010300500001841B\",\"timeoutSeconds\":30}" \
    | jq -r '.orderId')

  sleep 2

  curl -s \
    "${BASE_URL}/v1.0/order/${ORDER_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq -r '.analysisResult' | cut -c7-10
}

send_stop() {
  log "Sending STOP..."

  ORDER_ID=$(curl -s -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"011000500001020000AA00\",\"timeoutSeconds\":30}" \
    | jq -r '.orderId')

  sleep 3

  STATUS=$(curl -s \
    "${BASE_URL}/v1.0/order/${ORDER_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq -r '.status')

  [[ "$STATUS" == "666" ]] || { log "STOP failed"; exit 1; }

  log "STOP accepted"
}

send_start() {
  log "Sending START..."

  ORDER_ID=$(curl -s -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"0110005000010200016BC0\",\"timeoutSeconds\":30}" \
    | jq -r '.orderId')

  sleep 3

  STATUS=$(curl -s \
    "${BASE_URL}/v1.0/order/${ORDER_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq -r '.status')

  [[ "$STATUS" == "666" ]] || { log "START failed"; exit 1; }

  log "START accepted"
}

### =========================
### MAIN
### =========================

login

CURRENT_STATE=$(read_state)
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" != "0001" ]]; then
  log "Inverter not in RUN state. Aborting restart."
  exit 1
fi

send_stop

STOP_STATE=$(read_state)
log "State after STOP: $STOP_STATE"

if [[ "$STOP_STATE" != "0000" ]]; then
  log "STOP verification failed"
  exit 1
fi

log "Waiting 10 seconds..."
sleep 10

send_start

START_STATE=$(read_state)
log "State after START: $START_STATE"

if [[ "$START_STATE" != "0001" ]]; then
  log "START verification failed"
  exit 1
fi

log "Restart successful"
exit 0
