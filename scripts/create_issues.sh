#!/bin/bash
# Creates and closes all issues for bugs encountered and fixed during development.
# Run from inside the canaryfs repo. Requires `gh auth login` first.

set -e

REPO="Hamzaaxx/projet-sys"

create_and_close() {
    local title="$1"
    local body="$2"
    local fix_commit="$3"

    echo ">>> Creating: ${title}"
    URL=$(gh issue create --repo "${REPO}" --title "${title}" --body "${body}")
    NUM=$(echo "${URL}" | grep -oP '\d+$')

    echo ">>> Closing #${NUM} (fixed in ${fix_commit})"
    gh issue close --repo "${REPO}" "${NUM}" --comment "Fixed in ${fix_commit}" --reason completed
    echo ""
}

# ──────────────────────────────────────────────────────────────────
create_and_close \
"-t flag does not use real POSIX threads" \
"The -t (thread) option originally used Bash background jobs (\`&\`), which create separate processes — not threads. The project requirements explicitly demand real thread-based execution.

**Expected:** Real POSIX pthreads sharing the same process memory.
**Actual:** Each \`&\` spawned a child process with its own memory space.

**Fix:** Implemented \`lib/monitor_thread.c\` using \`pthread_create\`/\`pthread_join\`. The Bash script auto-compiles it on first use of \`-t\` and invokes the binary with all canary file paths.

**Verification:**
\`\`\`
cat /proc/\$(pgrep monitor_thread)/status | grep Threads
# Threads: 5  (one process, multiple threads)
\`\`\`" \
"81e532f"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"MONITOR_THREAD_BIN defined before SCRIPT_DIR (variable ordering bug)" \
"In the main \`canaryfs\` script, \`MONITOR_THREAD_BIN=\"\${SCRIPT_DIR}/lib/monitor_thread\"\` was declared **before** \`SCRIPT_DIR\` itself was set. The path expanded to just \`/lib/monitor_thread\` and thread mode would fail.

**Fix:** Moved \`SCRIPT_DIR\` definition to the top of the script, before any variable that depends on it." \
"81e532f"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"Default log directory /var/log/canaryfs requires root" \
"Running \`./canaryfs ...\` as a non-root user fails with:
\`\`\`
ERROR: cannot create log directory /var/log/canaryfs
\`\`\`

This blocks all testing for normal users.

**Workarounds documented:**
- Option A: \`./canaryfs -l /tmp/canaryfs_logs ...\` (custom dir)
- Option B: \`sudo mkdir -p /var/log/canaryfs && sudo chown \$USER:\$USER /var/log/canaryfs\` (one-time setup)

**Fix:** Documented both workarounds in the README and demo script. The \`-l\` flag was already implemented." \
"a039c29"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"monitor_file produces duplicated file paths in alerts" \
"Alerts in fork/subshell modes were logged with corrupted paths:
\`\`\`
file=/tmp/honeypot/.env.env
file=/tmp/honeypot/id_rsaid_rsa
\`\`\`

**Root cause:** When \`inotifywait\` watches a single file, the output is just the full path (no \`%w%f\` split). The code tried to reconstruct the path as \`\${dir}\${file:-\$(basename ...)}\` which appended the basename to a path that already contained it.

**Fix:** When watching a single file, pass \`\${target_file}\` directly to \`_capture_forensics\` — no reconstruction needed." \
"3e77b2f"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"Forensic capture shows 'unknown' for fast commands like cat" \
"Triggering with \`cat /tmp/honeypot/.env\` produced:
\`\`\`
ALERT : canary accessed — pid=unknown process=unknown uid=unknown ppid=unknown
\`\`\`

**Root cause:** \`cat\` reads tiny files in microseconds. By the time \`inotifywait\` fires the event and we spawn \`lsof\` (which takes ~1-3ms), the file is already closed and \`lsof\` finds nothing.

**Fix:** Added a retry loop in both \`monitor.sh\` and \`monitor_thread.c\` — up to 5 attempts with 1ms delay between each. This catches more cases.

**Limitation:** Truly instant reads still escape detection. Full elimination would require **fanotify** (kernel API that includes PID directly in the event), which is documented as a future improvement.

**Verified working with:** \`less\`, \`nano\`, \`vim\`, \`cp\`, \`exec 3<\`." \
"3c0eba0"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"No signal handling — Ctrl+C leaks orphan inotifywait processes" \
"Pressing Ctrl+C on canaryfs left zombie watchers running in the background:
\`\`\`
ps aux | grep inotifywait
# Multiple orphans still alive
\`\`\`

These would keep consuming inotify watches and could prevent future runs.

**Fix:** Added a \`cleanup()\` function and \`trap cleanup SIGINT SIGTERM\` to \`canaryfs\`. On signal, it kills all child \`inotifywait\` and \`monitor_thread\` processes via \`pkill -P \$\$\` and exits cleanly.

**Verification:**
\`\`\`
./canaryfs -t -p 5 /tmp/honeypot &
# Ctrl+C
pgrep -af inotifywait    # → empty
\`\`\`" \
"3c0eba0"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"canaryfs.conf is never loaded — config file ignored" \
"The repository contained a \`canaryfs.conf\` file with default values, but the main script never sourced it. Users couldn't change defaults without editing the script.

**Fix:** Added the following block right after global variable definitions:

\`\`\`bash
if [[ -f \"\${SCRIPT_DIR}/canaryfs.conf\" ]]; then
    source \"\${SCRIPT_DIR}/canaryfs.conf\"
    LOG_FILE=\"\${LOG_DIR}/history.log\"
fi
\`\`\`

Command-line flags still take priority over config file values." \
"3c0eba0"

# ──────────────────────────────────────────────────────────────────
create_and_close \
"No documentation website for the project" \
"For the academic submission, a clear page-by-page explanation of every script was needed.

**Fix:** Added \`docs/index.html\` — a single-file responsive website with:
- Overview + project structure
- Full execution flow diagrams
- Per-file documentation (canaryfs, plant.sh, monitor.sh, monitor_thread.c, log.sh, alert.sh, restore.sh)
- Test scenarios explained
- Syntax highlighting via highlight.js
- Dark cybersecurity theme

Hostable on GitHub Pages by setting Source = \`main\` / \`/docs\`." \
"a039c29"

# ──────────────────────────────────────────────────────────────────
echo ""
echo "✓ All 8 issues created and closed."
echo "Visit: https://github.com/${REPO}/issues?q=is%3Aclosed"
