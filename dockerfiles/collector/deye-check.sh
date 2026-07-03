#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID not set}"
APP_SECRET="${APP_SECRET:?APP_SECRET not set}"
EMAIL="${EMAIL:?EMAIL not set}"
PASSWORD="${PASSWORD:?PASSWORD not set}"
DEVICE_SN="${DEVICE_SN:?DEVICE_SN not set}"
BASE_URL="${BASE_URL:?BASE_URL not set}"

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

echo "== LOGIN =="

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
  echo "Login failed"
  exit 1
fi

echo "Token OK"
echo

echo "== DEVICE LATEST STATUS =="

LATEST_RESPONSE=$(curl_json -X POST \
  "${BASE_URL}/v1.0/device/latest" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"deviceList\":[\"${DEVICE_SN}\"]}")

SUCCESS=$(echo "$LATEST_RESPONSE" | jq -r '.success // false')
if [[ "$SUCCESS" != "true" ]]; then
  echo "Latest device status request failed"
  echo "$LATEST_RESPONSE"
  exit 1
fi

DEVICE_STATE=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].deviceState // empty')
COLLECTION_TIME=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].collectionTime // empty')
TOTAL_INVERTER_OUTPUT_POWER=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="TotalInverterOutputPower") | .value // empty')
TOTAL_CONSUMPTION_POWER=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="TotalConsumptionPower") | .value // empty')
BATTERY_POWER=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="BatteryPower") | .value // empty')
SOC=$(echo "$LATEST_RESPONSE" | jq -r '.deviceDataList[0].dataList[] | select(.key=="SOC") | .value // empty')

TOTAL_INVERTER_OUTPUT_POWER=${TOTAL_INVERTER_OUTPUT_POWER:-0}
TOTAL_CONSUMPTION_POWER=${TOTAL_CONSUMPTION_POWER:-0}
BATTERY_POWER=${BATTERY_POWER:-0}
SOC=${SOC:-0}
NOW_TS=$(date +%s)
COLLECTION_AGE="unknown"
COLLECTION_TIME_HUMAN=$(format_collection_time "$COLLECTION_TIME")

if [[ -n "$COLLECTION_TIME" ]]; then
  COLLECTION_AGE=$((NOW_TS - COLLECTION_TIME))
fi

if [[ -z "$DEVICE_STATE" ]]; then
  echo "Device state is empty"
  echo "$LATEST_RESPONSE"
  exit 1
fi

echo "deviceState: $DEVICE_STATE"
echo "collectionTime: $COLLECTION_TIME_HUMAN"
echo "collectionAgeSeconds: $COLLECTION_AGE"
echo "TotalInverterOutputPower: $TOTAL_INVERTER_OUTPUT_POWER W"
echo "TotalConsumptionPower: $TOTAL_CONSUMPTION_POWER W"
echo "BatteryPower: $BATTERY_POWER W"
echo "SOC: $SOC %"

IS_RUNNING=false
if jq -e '(
    (.deviceDataList[0].dataList[] | select(.key=="TotalInverterOutputPower") | (.value|tonumber)) > 0
  ) or (
    (.deviceDataList[0].dataList[] | select(.key=="TotalConsumptionPower") | (.value|tonumber)) > 0
  )' >/dev/null 2>&1 <<<"$LATEST_RESPONSE"; then
  IS_RUNNING=true
fi

if [[ "$IS_RUNNING" == "true" ]]; then
  echo "INVERTER: RUN"
elif [[ "$DEVICE_STATE" == "1" || "$DEVICE_STATE" == "2" ]]; then
  echo "INVERTER: STOP_OR_IDLE"
else
  echo "INVERTER: OFFLINE_OR_UNAVAILABLE"
fi
