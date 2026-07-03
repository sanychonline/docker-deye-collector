#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/deye-lib.sh"
READ_ORDER_MAX_POLLS=4
READ_ORDER_POLL_SLEEP=2

echo "== LOGIN =="

if ! login; then
  echo "Login failed"
  exit 1
fi

echo "Token OK"
echo

echo "== LIVE REGISTER READ 0x0050 =="

if ! read_register_state 2 1 >/dev/null; then
  echo "READ register polling failed"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

echo "readOrderId: ${READ_ORDER_ID}"
echo "analysisResult: ${READ_ANALYSIS_RESULT}"
echo "registerState: ${READ_REGISTER_STATE}"
echo

echo "== DEVICE LATEST STATUS =="

if ! fetch_latest_status; then
  echo "Latest device status request failed"
  echo "${LATEST_RESPONSE:-}"
  exit 1
fi

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
if [[ -n "$COLLECTION_TIME" && "$COLLECTION_TIME" =~ ^[0-9]+$ ]]; then
  COLLECTION_AGE=$((NOW_TS - COLLECTION_TIME))
fi

echo "deviceState: ${DEVICE_STATE}"
echo "collectionTime: $(format_collection_time "${COLLECTION_TIME:-}")"
echo "collectionAgeSeconds: ${COLLECTION_AGE}"
echo "TotalInverterOutputPower: ${TOTAL_INVERTER_OUTPUT_POWER} W"
echo "TotalConsumptionPower: ${TOTAL_CONSUMPTION_POWER} W"
echo "BatteryPower: ${BATTERY_POWER} W"
echo "SOC: ${SOC} %"

if [[ "$READ_REGISTER_STATE" == "0001" ]]; then
  echo "INVERTER: RUN"
elif [[ "$READ_REGISTER_STATE" == "0000" ]]; then
  echo "INVERTER: STOP_OR_IDLE"
else
  echo "INVERTER: UNKNOWN_REGISTER_STATE"
fi
