#!/bin/bash
# lib/restore.sh — Remove all planted canary files (root only)

run_restore() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Option -r requires root privileges"
        show_help; exit 104
    fi

    if [[ ! -f "${CANARY_REGISTRY}" ]]; then
        log_info "No canary registry found — nothing to restore"
        return 0
    fi

    local count=0
    log_info "Removing all planted canaries ..."

    while IFS= read -r canary_file; do
        if [[ -f "${canary_file}" ]]; then
            rm -f "${canary_file}"
            log_info "Removed: ${canary_file}"
            (( count++ ))
        fi
    done < "${CANARY_REGISTRY}"

    rm -f "${CANARY_REGISTRY}"
    log_info "Restore complete — ${count} canary files removed"
}
