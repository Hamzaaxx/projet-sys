#!/bin/bash
# lib/alert.sh — Send alerts to syslog and desktop when -a flag is set

fire_alert() {
    local message="$1"
    [[ "${ALERT_MODE}" != true ]] && return

    logger -t "canaryfs" -p auth.warning "${message}"

    if command -v notify-send &>/dev/null; then
        # When running as root (sudo), notify-send needs the real user's D-Bus session
        local real_user="${SUDO_USER:-$USER}"
        local real_uid
        real_uid=$(id -u "${real_user}" 2>/dev/null || echo "1000")
        DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${real_uid}/bus" \
            sudo -u "${real_user}" notify-send --urgency=critical "🚨 canaryfs ALERT" "${message}" 2>/dev/null \
        || notify-send --urgency=critical "🚨 canaryfs ALERT" "${message}" 2>/dev/null
    fi
}
