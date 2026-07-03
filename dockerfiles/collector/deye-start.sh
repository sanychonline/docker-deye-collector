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
  log "READ before START failed"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

CURRENT_STATE="$READ_REGISTER_STATE"
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" == "0001" ]]; then
  log "Already RUN"
  exit 0
fi

if [[ "$CURRENT_STATE" != "0000" ]]; then
  log "Unknown state, aborting"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

log "Sending START..."
RESPONSE=$(submit_custom_order "$DEYE_START_CONTENT")
ORDER_ID=$(extract_json_int_field "$RESPONSE" "orderId")
SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')

if [[ "$SUCCESS" != "true" || -z "$ORDER_ID" || "$ORDER_ID" == "null" ]]; then
  log "Failed to create START order"
  echo "$RESPONSE"
  exit 1
fi

log "START order submitted: $ORDER_ID"

if verify_state_transition "0001" 10 4; then
  log "State after START: $READ_REGISTER_STATE"
  if fetch_latest_status; then
    log "State collectionTime: ${COLLECTION_TIME:-unknown}"
    log "State collectionTimeHuman: $(format_collection_time "${COLLECTION_TIME:-}")"
  fi
  log "Inverter successfully started"
  exit 0
fi

log "State after START: ${READ_REGISTER_STATE:-unknown}"
if fetch_latest_status; then
  log "State collectionTime: ${COLLECTION_TIME:-unknown}"
  log "State collectionTimeHuman: $(format_collection_time "${COLLECTION_TIME:-}")"
fi
log "START verification failed"
exit 1
