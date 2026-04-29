#!/bin/bash
# lib/alert.sh — Send alerts to syslog and desktop when -a flag is set

fire_alert() {
    local message="$1"
    [[ "${ALERT_MODE}" != true ]] && return

    logger -t "canaryfs" -p auth.warning "${message}"

    if command -v notify-send &>/dev/null; then
        notify-send --urgency=critical "canaryfs ALERT" "${message}"
    fi
}
