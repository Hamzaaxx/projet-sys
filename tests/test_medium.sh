#!/bin/bash
# TEST SCENARIO: MEDIUM — 50 canaries, 5 directories
# Goal: compare fork vs thread speed under moderate load

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_FILE="/tmp/canaryfs_medium_results.txt"

DIRS=()
for i in $(seq 1 5); do
    d="/tmp/canaryfs_test_medium_${i}"
    mkdir -p "${d}"
    DIRS+=("${d}")
done

> "${RESULTS_FILE}"
echo "=== MEDIUM TEST (50 canaries, 5 directories) ===" | tee -a "${RESULTS_FILE}"

for mode in fork thread subshell; do
    echo "" | tee -a "${RESULTS_FILE}"
    echo "--- Mode: ${mode} ---" | tee -a "${RESULTS_FILE}"

    PIDS=()
    START=$(date +%s%N)

    for dir in "${DIRS[@]}"; do
        "${SCRIPT_DIR}/canaryfs" -${mode:0:1} -p 10 "${dir}" &
        PIDS+=($!)
    done

    sleep 2

    # Trigger canaries in multiple directories simultaneously
    for dir in "${DIRS[@]}"; do
        cat "${dir}/.env" &>/dev/null &
        cat "${dir}/id_rsa" &>/dev/null &
    done
    wait

    sleep 1
    for pid in "${PIDS[@]}"; do kill "${pid}" 2>/dev/null; done
    END=$(date +%s%N)

    TOTAL_MS=$(( (END - START) / 1000000 ))
    echo "Total runtime : ${TOTAL_MS} ms" | tee -a "${RESULTS_FILE}"

    for dir in "${DIRS[@]}"; do
        sudo "${SCRIPT_DIR}/canaryfs" -r "${dir}"
    done
done

echo "" | tee -a "${RESULTS_FILE}"
echo "=== Medium test complete. Results: ${RESULTS_FILE} ===" | tee -a "${RESULTS_FILE}"
