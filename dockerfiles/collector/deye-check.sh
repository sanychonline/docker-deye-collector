#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID not set}"
APP_SECRET="${APP_SECRET:?APP_SECRET not set}"
EMAIL="${EMAIL:?EMAIL not set}"
PASSWORD="${PASSWORD:?PASSWORD not set}"
DEVICE_SN="${DEVICE_SN:?DEVICE_SN not set}"

BASE_URL="https://eu1-developer.deyecloud.com"

echo "== LOGIN =="

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
  echo "Login failed"
  exit 1
fi

echo "Token OK"
echo

echo "== READ REGISTER 0x0050 =="

ORDER_ID=$(curl -s -X POST \
  "${BASE_URL}/v1.0/order/customControl" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"deviceSn\":\"${DEVICE_SN}\",\"content\":\"010300500001841B\",\"timeoutSeconds\":30}" \
  | jq -r '.orderId')

sleep 2

STATE=$(curl -s \
  "${BASE_URL}/v1.0/order/${ORDER_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq -r '.analysisResult' | cut -c7-10)

echo "Raw value: $STATE"

if [[ "$STATE" == "0001" ]]; then
  echo "INVERTER: RUN"
elif [[ "$STATE" == "0000" ]]; then
  echo "INVERTER: STOP"
else
  echo "INVERTER: UNKNOWN ($STATE)"
fi
