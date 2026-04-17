#!/bin/bash
# lib/alert.sh — Alert and notification logic

fire_alert() {
    local message="$1"

    # Always print to terminal (already done by log_alert via tee)

    if [[ "${ALERT_MODE}" == true ]]; then
        # Write to syslog
        logger -t "${PROGRAM_NAME}" -p auth.warning "${message}"

        # Desktop notification if available
        if command -v notify-send &>/dev/null; then
            notify-send --urgency=critical \
                "canaryfs ALERT" \
                "${message}"
        fi
    fi
}
