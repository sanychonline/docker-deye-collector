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

curl_json() {
  curl -fsS --connect-timeout 10 --max-time 30 "$@"
}

login() {
  log "Login..."

  SHA256=$(printf "%s" "$PASSWORD" | sha256sum | awk '{print $1}')

  ACCESS_TOKEN=$(curl_json -X POST \
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

fetch_latest_status() {
  LATEST_RESPONSE=$(curl_json -X POST \
    "${BASE_URL}/v1.0/device/latest" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceList\":[\"${DEVICE_SN}\"]}")

  SUCCESS=$(echo "$LATEST_RESPONSE" | jq -r '.success // false')
  if [[ "$SUCCESS" != "true" ]]; then
    log "Latest device status request failed"
    echo "$LATEST_RESPONSE"
    exit 1
  fi

  COLLECTION_TIME=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].collectionTime // empty')
}

read_state() {
  fetch_latest_status

  DEVICE_STATE=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].deviceState // empty')

  if [[ -z "$DEVICE_STATE" ]]; then
    log "Device state is empty"
    echo "$LATEST_RESPONSE"
    exit 1
  fi

  if [[ "$DEVICE_STATE" == "1" ]]; then
    echo "0001"
  elif [[ "$DEVICE_STATE" == "2" ]]; then
    echo "0000"
  else
    echo "OFFLINE"
  fi
}

wait_for_state() {
  EXPECTED_STATE="$1"
  MIN_COLLECTION_TIME="$2"

  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
    CURRENT_STATE=$(read_state)
    if [[ -n "${COLLECTION_TIME:-}" && "$COLLECTION_TIME" =~ ^[0-9]+$ && "$COLLECTION_TIME" -lt "$MIN_COLLECTION_TIME" ]]; then
      log "Waiting for fresh cloud snapshot (collectionTime=${COLLECTION_TIME}, need >= ${MIN_COLLECTION_TIME})"
      sleep 5
      continue
    fi
    [[ "$CURRENT_STATE" == "$EXPECTED_STATE" ]] && return 0
    sleep 5
  done

  return 1
}

send_start() {
  log "Sending START..."

  RESPONSE=$(curl_json -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"0110005000010200016BC0\",\"timeoutSeconds\":30}")

  ORDER_ID=$(echo "$RESPONSE" | jq -r '.orderId // empty')
  SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')

  if [[ "$SUCCESS" != "true" || -z "$ORDER_ID" || "$ORDER_ID" == "null" ]]; then
    log "Failed to create START order"
    echo "$RESPONSE"
    exit 1
  fi

  log "START order submitted: $ORDER_ID"
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

COMMAND_TS=$(date +%s)

if wait_for_state "0001" "$COMMAND_TS"; then
  NEW_STATE=$(read_state)
  log "State after START: $NEW_STATE"
  log "State collectionTime: ${COLLECTION_TIME:-unknown}"
  log "Inverter successfully started"
  exit 0
else
  NEW_STATE=$(read_state)
  log "State after START: $NEW_STATE"
  log "State collectionTime: ${COLLECTION_TIME:-unknown}"
  log "START verification failed"
  exit 1
fi
