#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/deye-lib.sh"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Login..."
if ! login; then
  log "Login failed"
  exit 1
fi
log "Token OK"

if ! read_register_state 3 1 >/dev/null; then
  log "READ before STOP failed"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

CURRENT_STATE="$READ_REGISTER_STATE"
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" == "0000" ]]; then
  log "Already STOP"
  exit 0
fi

if [[ "$CURRENT_STATE" != "0001" ]]; then
  log "Unknown state, aborting"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

log "Sending STOP..."
RESPONSE=$(submit_custom_order "$DEYE_STOP_CONTENT")
ORDER_ID=$(echo "$RESPONSE" | jq -r '.orderId // empty')
SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')

if [[ "$SUCCESS" != "true" || -z "$ORDER_ID" || "$ORDER_ID" == "null" ]]; then
  log "Failed to create STOP order"
  echo "$RESPONSE"
  exit 1
fi

log "STOP order submitted: $ORDER_ID"

if verify_state_transition "0000" 10 4; then
  log "State after STOP: $READ_REGISTER_STATE"
  if fetch_latest_status; then
    log "State collectionTime: ${COLLECTION_TIME:-unknown}"
    log "State collectionTimeHuman: $(format_collection_time "${COLLECTION_TIME:-}")"
  fi
  log "Inverter successfully stopped"
  exit 0
fi

log "State after STOP: ${READ_REGISTER_STATE:-unknown}"
if fetch_latest_status; then
  log "State collectionTime: ${COLLECTION_TIME:-unknown}"
  log "State collectionTimeHuman: $(format_collection_time "${COLLECTION_TIME:-}")"
fi
log "STOP verification failed"
exit 1
