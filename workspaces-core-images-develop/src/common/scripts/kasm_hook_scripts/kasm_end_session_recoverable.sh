#!/usr/bin/env bash

APP_NAME=$(basename "$0")

log () {
    if [ ! -z "${1}" ]; then
        LOG_LEVEL="${2:-DEBUG}"
        INGEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${INGEST_DATE} ${LOG_LEVEL} (${APP_NAME}): $1"
        if [ ! -z "${KASM_API_JWT}" ]  && [ ! -z "${KASM_API_HOST}" ]  && [ ! -z "${KASM_API_PORT}" ]; then
            http_proxy="" https_proxy="" curl https://${KASM_API_HOST}:${KASM_API_PORT}/api/kasm_session_log?token=${KASM_API_JWT} --max-time 1 -X POST -H 'Content-Type: application/json' -d '[{ "host": "'"${KASM_ID}"'", "application": "Session", "ingest_date": "'"${INGEST_DATE}"'", "message": "'"$1"'", "levelname": "'"${LOG_LEVEL}"'", "process": "'"${APP_NAME}"'", "kasm_user_name": "'"${KASM_USER_NAME}"'", "kasm_id": "'"${KASM_ID}"'" }]' -k -s
        fi
    fi
}

cleanup() {
    log "The kasm_end_session_recoverable script was interrupted." "ERROR"
}

trap cleanup 2 6 9 15

log "Executing kasm_end_session_recoverable.sh" "INFO"

if [ ! -z "$KASM_PROFILE_LDR" ]; then
    case "$KASM_PROFILE_LDR" in
    0)
        echo "V1 Profile Sync configured, no action required."
    ;;
    1|2)
        log 'Syncing profile up with v2 profilesync.'
        http_proxy="" https_proxy="" /usr/bin/kasm-profile-sync-2 --action push --ignore-ssl --report-status
        PROFILE_SYNC_STATUS=$?
        if [ $PROFILE_SYNC_STATUS -ne 0 ]; then
            log "Failed to syncronize user profile, see debug logs." "ERROR"
            exit 74
        else
            log "Profile upload complete."
        fi 
    ;;
    *)
        log 'Unkown KASM_PROFILE_LDR setting'
    ;;
    esac

fi

echo "Done"