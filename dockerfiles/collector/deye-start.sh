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

extract_order_id() {
  printf '%s' "$1" | sed -n 's/.*"orderId":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1
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
  READ_RESPONSE=$(curl -s -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"010300500001841B\",\"timeoutSeconds\":30}")

  ORDER_ID=$(extract_order_id "$READ_RESPONSE")
  [[ -n "$ORDER_ID" ]] || { echo "$READ_RESPONSE"; exit 1; }

  sleep 2

  curl -s \
    "${BASE_URL}/v1.0/order/${ORDER_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq -r '.analysisResult' | cut -c7-10
}

send_start() {
  log "Sending START..."

  START_RESPONSE=$(curl -s -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"0110005000010200016BC0\",\"timeoutSeconds\":30}")

  ORDER_ID=$(extract_order_id "$START_RESPONSE")

  if [[ -z "$ORDER_ID" ]]; then
    log "START command failed"
    echo "$START_RESPONSE"
    exit 1
  fi

  sleep 3

  RESULT=$(curl -s \
    "${BASE_URL}/v1.0/order/${ORDER_ID}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")

  STATUS=$(echo "$RESULT" | jq -r '.status')

  if [[ "$STATUS" != "666" ]]; then
    log "START command failed"
    exit 1
  fi

  log "START command accepted"
}

### =========================
### MAIN
### =========================

login

CURRENT_STATE=$(read_state)
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" == "0001" ]]; then
  log "Already RUN"
  exit 0
fi

if [[ "$CURRENT_STATE" != "0000" ]]; then
  log "Unknown state, aborting"
  exit 1
fi

send_start

NEW_STATE=$(read_state)
log "State after START: $NEW_STATE"

if [[ "$NEW_STATE" == "0001" ]]; then
  log "Inverter successfully started"
  exit 0
else
  log "START verification failed"
  exit 1
fi
