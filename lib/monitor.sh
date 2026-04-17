#!/bin/bash
# lib/monitor.sh — inotify watcher logic

monitor_file() {
    local target_file="$1"

    inotifywait -m -e access,open,read,modify "${target_file}" 2>/dev/null \
    | while read -r dir event file; do
        local full_path="${dir}${file:-$(basename "${target_file}")}"
        _capture_forensics "${full_path}" "${event}"
    done
}

monitor_directory() {
    local target_dir="$1"

    log_info "Watching directory: ${target_dir}"
    inotifywait -m -r -e access,open,read,modify \
        --format '%w%f %e %T' --timefmt '%Y-%m-%d-%H-%M-%S' \
        "${target_dir}" 2>/dev/null \
    | while read -r full_path event timestamp; do
        # Only alert if the accessed file is a registered canary
        if grep -qxF "${full_path}" "${CANARY_REGISTRY}" 2>/dev/null; then
            _capture_forensics "${full_path}" "${event}"
        fi
    done
}

_capture_forensics() {
    local file="$1"
    local event="$2"

    # Find processes currently accessing the file
    local lsof_info
    lsof_info=$(lsof "${file}" 2>/dev/null | tail -n +2 | head -1)

    local proc_name pid uid ppid
    proc_name=$(echo "${lsof_info}" | awk '{print $1}')
    pid=$(echo "${lsof_info}"       | awk '{print $2}')
    uid=$(echo "${lsof_info}"       | awk '{print $3}')

    # Fallback to /proc if lsof gives nothing
    if [[ -z "${pid}" ]]; then
        pid="unknown"
        proc_name="unknown"
        uid="$(id -u)"
    fi

    ppid=$(cat "/proc/${pid}/status" 2>/dev/null | grep PPid | awk '{print $2}')
    ppid="${ppid:-unknown}"

    local alert_msg="canary accessed — file=${file} event=${event} pid=${pid} process=${proc_name} uid=${uid} ppid=${ppid}"
    log_alert "${alert_msg}"
    fire_alert "${alert_msg}"
}
