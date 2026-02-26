#!/usr/bin/env bash

set -euo pipefail

APP_ID="${APP_ID:?APP_ID not set}"
APP_SECRET="${APP_SECRET:?APP_SECRET not set}"
EMAIL="${EMAIL:?EMAIL not set}"
PASSWORD="${PASSWORD:?PASSWORD not set}"
DEVICE_SN="${DEVICE_SN:?DEVICE_SN not set}"

BASE_URL="${BASE_URL:-https://eu1-developer.deyecloud.com}"
OUT_DIR="${OUT_DIR:-/metrics}"
OUT_FILE="${OUT_DIR}/deye.prom"
TMP_FILE="${OUT_FILE}.tmp"

mkdir -p "$OUT_DIR"

# SHA256 password
SHA256=$(printf "%s" "$PASSWORD" | sha256sum | awk '{print $1}')

# GET TOKEN
TOKEN_RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/v1.0/account/token?appId=${APP_ID}" \
  -H "Content-Type: application/json" \
  -d "{
        \"appSecret\": \"${APP_SECRET}\",
        \"email\": \"${EMAIL}\",
        \"password\": \"${SHA256}\"
      }")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.accessToken // empty')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Token error"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

# GET DEVICE DATA
DATA_RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/v1.0/device/latest" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "{
        \"deviceList\": [\"${DEVICE_SN}\"]
      }")

SUCCESS=$(echo "$DATA_RESPONSE" | jq -r '.success')

if [[ "$SUCCESS" != "true" ]]; then
  echo "Device data error"
  echo "$DATA_RESPONSE"
  exit 1
fi

echo "# Deye inverter metrics" > "$TMP_FILE"

COUNTER_PATTERN="Total|Daily|Energy|Production|Consumption"

echo "$DATA_RESPONSE" | \
jq -r '.deviceDataList[0].dataList[] 
  | select(.key != null)
  | "\(.key)|\(.value)"' | \
while IFS="|" read -r KEY VALUE; do

  METRIC=$(echo "$KEY" \
    | sed 's/[^a-zA-Z0-9]/_/g' \
    | tr '[:upper:]' '[:lower:]')

  VALUE=${VALUE:-0}

  if [[ "$VALUE" == "null" || -z "$VALUE" ]]; then
    VALUE=0
  fi

  if [[ "$KEY" =~ $COUNTER_PATTERN ]]; then
    TYPE="counter"
  else
    TYPE="gauge"
  fi

  echo "# TYPE deye_${METRIC} ${TYPE}" >> "$TMP_FILE"
  echo "deye_${METRIC} ${VALUE}" >> "$TMP_FILE"

done

mv "$TMP_FILE" "$OUT_FILE"