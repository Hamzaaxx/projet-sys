#!/bin/bash
# lib/log.sh — Logging utilities

init_log_dir() {
    mkdir -p "${LOG_DIR}" 2>/dev/null || {
        echo "ERROR: cannot create log directory ${LOG_DIR}" >&2
        exit 1
    }
    touch "${LOG_FILE}"
}

_timestamp() {
    date +"%Y-%m-%d-%H-%M-%S"
}

_log() {
    local level="$1"
    local message="$2"
    local entry="$(_timestamp) : $(whoami) : ${level} : ${message}"
    # Write to terminal AND log file simultaneously
    echo "${entry}" | tee -a "${LOG_FILE}"
}

log_info()  { _log "INFOS" "$1"; }
log_error() { _log "ERROR" "$1" >&2; }
log_alert() { _log "ALERT" "$1"; }
