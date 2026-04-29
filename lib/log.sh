#!/bin/bash
# lib/log.sh — Logging utilities

init_log_dir() {
    mkdir -p "${LOG_DIR}" || { echo "ERROR: cannot create log dir ${LOG_DIR}" >&2; exit 1; }
    touch "${LOG_FILE}"
}

_log() {
    local level="$1"
    local message="$2"
    echo "$(date +'%Y-%m-%d-%H-%M-%S') : $(whoami) : ${level} : ${message}" | tee -a "${LOG_FILE}"
}

log_info()  { _log "INFOS" "$1"; }
log_error() { _log "ERROR" "$1" >&2; }
log_alert() { _log "ALERT" "$1"; }
