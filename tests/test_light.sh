#!/bin/bash
# TEST SCENARIO: LIGHT — 5 canaries, 1 directory
# Goal: measure baseline detection time across all 3 modes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="/tmp/canaryfs_test_light"
RESULTS_FILE="/tmp/canaryfs_light_results.txt"

mkdir -p "${TEST_DIR}"
> "${RESULTS_FILE}"

echo "=== LIGHT TEST (5 canaries, 1 directory) ===" | tee -a "${RESULTS_FILE}"

for mode in fork thread subshell; do
    echo "" | tee -a "${RESULTS_FILE}"
    echo "--- Mode: ${mode} ---" | tee -a "${RESULTS_FILE}"

    START=$(date +%s%N)
    "${SCRIPT_DIR}/canaryfs" -${mode:0:1} -p 5 "${TEST_DIR}" &
    WATCHER_PID=$!

    sleep 1   # give watcher time to start

    # Trigger a canary access
    TRIGGER_START=$(date +%s%N)
    cat "${TEST_DIR}/.env" &>/dev/null
    TRIGGER_END=$(date +%s%N)

    sleep 1   # allow detection to fire
    kill "${WATCHER_PID}" 2>/dev/null
    END=$(date +%s%N)

    TOTAL_MS=$(( (END - START) / 1000000 ))
    TRIGGER_MS=$(( (TRIGGER_END - TRIGGER_START) / 1000000 ))

    echo "Total runtime : ${TOTAL_MS} ms" | tee -a "${RESULTS_FILE}"
    echo "Trigger time  : ${TRIGGER_MS} ms" | tee -a "${RESULTS_FILE}"

    sudo "${SCRIPT_DIR}/canaryfs" -r "${TEST_DIR}"
done

echo "" | tee -a "${RESULTS_FILE}"
echo "=== Light test complete. Results: ${RESULTS_FILE} ===" | tee -a "${RESULTS_FILE}"
