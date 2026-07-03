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
  log "READ before RESTART failed"
  echo "${READ_ORDER_RESPONSE:-}"
  exit 1
fi

CURRENT_STATE="$READ_REGISTER_STATE"
log "Current state: $CURRENT_STATE"

if [[ "$CURRENT_STATE" != "0001" ]]; then
  log "Inverter not in RUN state. Aborting restart."
  exit 1
fi

log "Sending STOP..."
STOP_RESPONSE=$(submit_custom_order "$DEYE_STOP_CONTENT")
STOP_ORDER_ID=$(echo "$STOP_RESPONSE" | jq -r '.orderId // empty')
STOP_SUCCESS=$(echo "$STOP_RESPONSE" | jq -r '.success // false')

if [[ "$STOP_SUCCESS" != "true" || -z "$STOP_ORDER_ID" || "$STOP_ORDER_ID" == "null" ]]; then
  log "Failed to create STOP order"
  echo "$STOP_RESPONSE"
  exit 1
fi

log "STOP order submitted: $STOP_ORDER_ID"

if verify_state_transition "0000" 10 4; then
  log "State after STOP: $READ_REGISTER_STATE"
  if fetch_latest_status; then
    log "State collectionTime after STOP: ${COLLECTION_TIME:-unknown}"
    log "State collectionTimeHuman after STOP: $(format_collection_time "${COLLECTION_TIME:-}")"
  fi
else
  log "State after STOP: ${READ_REGISTER_STATE:-unknown}"
  if fetch_latest_status; then
    log "State collectionTime after STOP: ${COLLECTION_TIME:-unknown}"
    log "State collectionTimeHuman after STOP: $(format_collection_time "${COLLECTION_TIME:-}")"
  fi
  log "STOP verification failed"
  exit 1
fi

log "Waiting 10 seconds..."
sleep 10

log "Sending START..."
START_RESPONSE=$(submit_custom_order "$DEYE_START_CONTENT")
START_ORDER_ID=$(echo "$START_RESPONSE" | jq -r '.orderId // empty')
START_SUCCESS=$(echo "$START_RESPONSE" | jq -r '.success // false')

if [[ "$START_SUCCESS" != "true" || -z "$START_ORDER_ID" || "$START_ORDER_ID" == "null" ]]; then
  log "Failed to create START order"
  echo "$START_RESPONSE"
  exit 1
fi

log "START order submitted: $START_ORDER_ID"

if verify_state_transition "0001" 10 4; then
  log "State after START: $READ_REGISTER_STATE"
  if fetch_latest_status; then
    log "State collectionTime after START: ${COLLECTION_TIME:-unknown}"
    log "State collectionTimeHuman after START: $(format_collection_time "${COLLECTION_TIME:-}")"
  fi
  log "Restart successful"
  exit 0
fi

log "State after START: ${READ_REGISTER_STATE:-unknown}"
if fetch_latest_status; then
  log "State collectionTime after START: ${COLLECTION_TIME:-unknown}"
  log "State collectionTimeHuman after START: $(format_collection_time "${COLLECTION_TIME:-}")"
fi
log "START verification failed"
exit 1
