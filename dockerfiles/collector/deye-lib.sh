#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID not set}"
APP_SECRET="${APP_SECRET:?APP_SECRET not set}"
EMAIL="${EMAIL:?EMAIL not set}"
PASSWORD="${PASSWORD:?PASSWORD not set}"
DEVICE_SN="${DEVICE_SN:?DEVICE_SN not set}"
BASE_URL="${BASE_URL:?BASE_URL not set}"

DEYE_READ_CONTENT="010300500001841B"
DEYE_START_CONTENT="0110005000010200016BC0"
DEYE_STOP_CONTENT="011000500001020000AA00"
READ_ORDER_MAX_POLLS="${READ_ORDER_MAX_POLLS:-12}"
READ_ORDER_POLL_SLEEP="${READ_ORDER_POLL_SLEEP:-2}"

curl_json() {
  curl -fsS --connect-timeout 10 --max-time 30 "$@"
}

format_collection_time() {
  local ts="$1"

  if [[ -z "$ts" || ! "$ts" =~ ^[0-9]+$ ]]; then
    echo "unknown"
    return
  fi

  TZ="${TZ:-Europe/Kiev}" date -d "@$ts" '+%Y-%m-%d %H:%M:%S %Z'
}

login() {
  local sha256
  sha256=$(printf "%s" "$PASSWORD" | sha256sum | awk '{print $1}')

  ACCESS_TOKEN=$(curl_json -X POST \
    "${BASE_URL}/v1.0/account/token?appId=${APP_ID}" \
    -H "Content-Type: application/json" \
    -d "{
          \"appSecret\": \"${APP_SECRET}\",
          \"email\": \"${EMAIL}\",
          \"password\": \"${sha256}\"
        }" | jq -r '.accessToken')

  [[ -n "$ACCESS_TOKEN" && "$ACCESS_TOKEN" != "null" ]]
}

submit_custom_order() {
  local content="$1"

  curl_json -X POST \
    "${BASE_URL}/v1.0/order/customControl" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"${content}\",\"timeoutSeconds\":30}"
}

poll_order_result() {
  local order_id="$1"
  local max_polls="${2:-$READ_ORDER_MAX_POLLS}"
  local poll_sleep="${3:-$READ_ORDER_POLL_SLEEP}"

  local i response status code
  for ((i=1; i<=max_polls; i++)); do
    response=$(curl -sS --connect-timeout 10 --max-time 30 \
      "${BASE_URL}/v1.0/order/${order_id}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}")

    status=$(echo "$response" | jq -r '.status // empty')
    code=$(echo "$response" | jq -r '.code // empty')

    if [[ "$status" == "666" ]]; then
      printf '%s' "$response"
      return 0
    fi

    # Deye sometimes returns "orderid is wrong" for a newly-created order
    # before the backend converges. Treat it as retryable.
    if [[ "$code" == "2101043" || "$status" == "0" || "$status" == "100" || -z "$status" ]]; then
      sleep "$poll_sleep"
      continue
    fi

    printf '%s' "$response"
    return 1
  done

  printf '%s' "${response:-}"
  return 1
}

fetch_latest_status() {
  LATEST_RESPONSE=$(curl_json -X POST \
    "${BASE_URL}/v1.0/device/latest" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"deviceList\":[\"${DEVICE_SN}\"]}")

  SUCCESS=$(echo "$LATEST_RESPONSE" | jq -r '.success // false')
  [[ "$SUCCESS" == "true" ]]

  DEVICE_STATE=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].deviceState // empty')
  COLLECTION_TIME=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].collectionTime // empty')
}

read_register_state_once() {
  local create_response read_success read_order_id order_response analysis_result register_state

  create_response=$(submit_custom_order "$DEYE_READ_CONTENT")
  read_success=$(echo "$create_response" | jq -r '.success // false')
  read_order_id=$(echo "$create_response" | jq -r '.orderId // empty')

  if [[ "$read_success" != "true" || -z "$read_order_id" || "$read_order_id" == "null" ]]; then
    printf '%s' "$create_response"
    return 1
  fi

  order_response=$(poll_order_result "$read_order_id") || {
    printf '%s' "${order_response:-$create_response}"
    return 1
  }

  analysis_result=$(echo "$order_response" | jq -r '.analysisResult // empty')
  register_state=$(echo "$analysis_result" | cut -c7-10)

  if [[ "$register_state" != "0000" && "$register_state" != "0001" ]]; then
    printf '%s' "$order_response"
    return 1
  fi

  READ_ORDER_ID="$read_order_id"
  READ_ORDER_RESPONSE="$order_response"
  READ_ANALYSIS_RESULT="$analysis_result"
  READ_REGISTER_STATE="$register_state"
  return 0
}

read_register_state() {
  local cycles="${1:-2}"
  local pause_seconds="${2:-1}"
  local attempt last_response

  for ((attempt=1; attempt<=cycles; attempt++)); do
    if read_register_state_once; then
      return 0
    fi
    last_response="${READ_ORDER_RESPONSE:-}"
    sleep "$pause_seconds"
  done

  printf '%s' "${last_response:-}"
  return 1
}

verify_state_transition() {
  local expected_state="$1"
  local attempts="${2:-10}"
  local pause_seconds="${3:-4}"
  local i

  for ((i=1; i<=attempts; i++)); do
    if read_register_state 3 2 >/dev/null; then
      [[ "$READ_REGISTER_STATE" == "$expected_state" ]] && return 0
    fi
    sleep "$pause_seconds"
  done

  return 1
}
