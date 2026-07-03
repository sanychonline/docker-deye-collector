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
}

read_state() {
  fetch_latest_status

  DEVICE_STATE=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].deviceState // empty')
  if [[ -z "$DEVICE_STATE" ]]; then
    log "Device state is empty"
    echo "$LATEST_RESPONSE"
    exit 1
  fi

  if [[ "$DEVICE_STATE" != "1" ]]; then
    echo "OFFLINE"
    return 0
  fi

  if jq -e '(
      (.deviceDataList[0].dataList[] | select(.key=="TotalInverterOutputPower") | (.value|tonumber)) > 0
    ) or (
      (.deviceDataList[0].dataList[] | select(.key=="TotalConsumptionPower") | (.value|tonumber)) > 0
    ) or (
      (.deviceDataList[0].dataList[] | select(.key=="BatteryPower") | (.value|tonumber)) != 0
    )' >/dev/null 2>&1 <<<"$LATEST_RESPONSE"; then
    echo "0001"
  else
    echo "0000"
  fi
}

wait_for_state() {
  EXPECTED_STATE="$1"

  for _ in 1 2 3 4 5 6; do
    CURRENT_STATE=$(read_state)
    [[ "$CURRENT_STATE" == "$EXPECTED_STATE" ]] && return 0
    sleep 5
  done

  return 1
}

send_start() {
  log "Sending START..."

  ORDER_ID=$(curl_json -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"0110005000010200016BC0\",\"timeoutSeconds\":30}" \
    | jq -r '.orderId')

  if [[ -z "$ORDER_ID" || "$ORDER_ID" == "null" ]]; then
    log "Failed to create START order"
    exit 1
  fi

  sleep 2

  for _ in 1 2 3 4 5; do
    RESULT=$(curl_json \
      "${BASE_URL}/v1.0/order/${ORDER_ID}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}")

    STATUS=$(echo "$RESULT" | jq -r '.status // empty')
    [[ -n "$STATUS" ]] && break
    sleep 2
  done

  if [[ -z "${STATUS:-}" ]]; then
    log "START status is empty"
    echo "${RESULT:-}"
    exit 1
  fi

  if [[ "$STATUS" != "666" ]]; then
    log "START command failed"
    echo "$RESULT"
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

if wait_for_state "0001"; then
  NEW_STATE=$(read_state)
  log "State after START: $NEW_STATE"
  log "Inverter successfully started"
  exit 0
else
  NEW_STATE=$(read_state)
  log "State after START: $NEW_STATE"
  log "START verification failed"
  exit 1
fi
