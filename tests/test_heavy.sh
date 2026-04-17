#!/bin/bash
# TEST SCENARIO: HEAVY — 200 canaries, 10 recursive directories
# Goal: stress test all 3 modes, measure detection latency under max load

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_FILE="/tmp/canaryfs_heavy_results.txt"

BASE="/tmp/canaryfs_test_heavy"
DIRS=()
for i in $(seq 1 10); do
    d="${BASE}/dir_${i}"
    mkdir -p "${d}"
    DIRS+=("${d}")
done

> "${RESULTS_FILE}"
echo "=== HEAVY TEST (200 canaries, 10 directories) ===" | tee -a "${RESULTS_FILE}"

for mode in fork thread subshell; do
    echo "" | tee -a "${RESULTS_FILE}"
    echo "--- Mode: ${mode} ---" | tee -a "${RESULTS_FILE}"

    PIDS=()
    START=$(date +%s%N)

    for dir in "${DIRS[@]}"; do
        "${SCRIPT_DIR}/canaryfs" -${mode:0:1} -p 20 "${dir}" &
        PIDS+=($!)
    done

    sleep 3

    # Trigger all canary types simultaneously across all directories
    TRIGGER_START=$(date +%s%N)
    for dir in "${DIRS[@]}"; do
        for f in .env id_rsa credentials.json shadow.bak backup.sql; do
            [[ -f "${dir}/${f}" ]] && cat "${dir}/${f}" &>/dev/null &
        done
    done
    wait
    TRIGGER_END=$(date +%s%N)

    sleep 2
    for pid in "${PIDS[@]}"; do kill "${pid}" 2>/dev/null; done
    END=$(date +%s%N)

    TOTAL_MS=$(( (END - START) / 1000000 ))
    TRIGGER_MS=$(( (TRIGGER_END - TRIGGER_START) / 1000000 ))
    CANARY_COUNT=$(wc -l < /tmp/.canaryfs_registry 2>/dev/null || echo "?")

    echo "Total runtime    : ${TOTAL_MS} ms"  | tee -a "${RESULTS_FILE}"
    echo "Trigger duration : ${TRIGGER_MS} ms" | tee -a "${RESULTS_FILE}"
    echo "Canaries watched : ${CANARY_COUNT}"   | tee -a "${RESULTS_FILE}"

    for dir in "${DIRS[@]}"; do
        sudo "${SCRIPT_DIR}/canaryfs" -r "${dir}"
    done
done

rm -rf "${BASE}"
echo "" | tee -a "${RESULTS_FILE}"
echo "=== Heavy test complete. Results: ${RESULTS_FILE} ===" | tee -a "${RESULTS_FILE}"
