#!/bin/bash
# lib/monitor.sh — Watch canary files with inotify and capture forensics on access

monitor_file() {
    local target_file="$1"

    inotifywait -m -e access,open,modify "${target_file}" 2>/dev/null \
    | while read -r dir event file; do
        _capture_forensics "${dir}${file:-$(basename "${target_file}")}" "${event}"
    done
}

monitor_directory() {
    local target_dir="$1"

    log_info "Watching directory: ${target_dir}"
    inotifywait -m -r -e access,open,modify \
        --format '%w%f %e %T' --timefmt '%Y-%m-%d-%H-%M-%S' \
        "${target_dir}" 2>/dev/null \
    | while read -r full_path event timestamp; do
        if grep -qxF "${full_path}" "${CANARY_REGISTRY}" 2>/dev/null; then
            _capture_forensics "${full_path}" "${event}"
        fi
    done
}

_capture_forensics() {
    local file="$1"
    local event="$2"

    local lsof_info proc_name pid uid ppid
    # Retry lsof up to 5 times — fast commands (cat) close file before lsof sees it
    for attempt in 1 2 3 4 5; do
        lsof_info=$(lsof "${file}" 2>/dev/null | tail -n +2 | head -1)
        [[ -n "${lsof_info}" ]] && break
        sleep 0.001
    done
    proc_name=$(echo "${lsof_info}" | awk '{print $1}')
    pid=$(echo "${lsof_info}"       | awk '{print $2}')
    uid=$(echo "${lsof_info}"       | awk '{print $3}')

    if [[ -z "${pid}" ]]; then
        pid="unknown"; proc_name="unknown"; uid="$(id -u)"
    fi

    ppid=$(grep PPid "/proc/${pid}/status" 2>/dev/null | awk '{print $2}')
    ppid="${ppid:-unknown}"

    local msg="canary accessed — file=${file} event=${event} pid=${pid} process=${proc_name} uid=${uid} ppid=${ppid}"
    log_alert "${msg}"
    fire_alert "${msg}"
}
