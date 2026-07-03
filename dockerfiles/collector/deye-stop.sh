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
  TOTAL_INVERTER_OUTPUT_POWER=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="TotalInverterOutputPower") | .value // 0')
  TOTAL_CONSUMPTION_POWER=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="TotalConsumptionPower") | .value // 0')

  if [[ -z "$DEVICE_STATE" ]]; then
    log "Device state is empty"
    echo "$LATEST_RESPONSE"
    exit 1
  fi

  if jq -e '(
      (.deviceDataList[0].dataList[] | select(.key=="TotalInverterOutputPower") | (.value|tonumber)) > 0
    ) or (
      (.deviceDataList[0].dataList[] | select(.key=="TotalConsumptionPower") | (.value|tonumber)) > 0
    )' >/dev/null 2>&1 <<<"$LATEST_RESPONSE"; then
    echo "0001"
  elif [[ "$DEVICE_STATE" == "1" || "$DEVICE_STATE" == "2" ]]; then
    echo "0000"
  else
    echo "OFFLINE"
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

send_stop() {
  log "Sending STOP..."

  RESPONSE=$(curl_json -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"011000500001020000AA00\",\"timeoutSeconds\":30}")

  ORDER_ID=$(echo "$RESPONSE" | jq -r '.orderId // empty')
  SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')

  if [[ "$SUCCESS" != "true" || -z "$ORDER_ID" || "$ORDER_ID" == "null" ]]; then
    log "Failed to create STOP order"
    echo "$RESPONSE"
    exit 1
  fi

  log "STOP order submitted: $ORDER_ID"
}

### =========================
### MAIN
### =========================

login

CURRENT_STATE=$(read_state)
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" == "0000" ]]; then
  log "Already STOP"
  exit 0
fi

if [[ "$CURRENT_STATE" != "0001" ]]; then
  log "Unknown state, aborting"
  exit 1
fi

send_stop

if wait_for_state "0000"; then
  NEW_STATE=$(read_state)
  log "State after STOP: $NEW_STATE"
  log "Inverter successfully stopped"
  exit 0
else
  NEW_STATE=$(read_state)
  log "State after STOP: $NEW_STATE"
  log "STOP verification failed"
  exit 1
fi
