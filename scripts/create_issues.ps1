$Repo = "Hamzaaxx/projet-sys"

function CreateAndClose($title, $body, $fixCommit) {
    Write-Host ">>> Creating: $title" -ForegroundColor Cyan
    $url = gh issue create --repo $Repo --title $title --body $body
    $num = ($url -split '/')[-1]
    Write-Host ">>> Closing #$num (fixed in $fixCommit)" -ForegroundColor Green
    gh issue close --repo $Repo $num --comment "Fixed in $fixCommit" --reason completed
    Write-Host ""
}

# 1
$body1 = @'
The -t (thread) option originally used Bash background jobs, which create separate processes — not threads. The project requirements explicitly demand real thread-based execution.

**Expected:** Real POSIX pthreads sharing the same process memory.
**Actual:** Each background job spawned a child process with its own memory space.

**Fix:** Implemented `lib/monitor_thread.c` using `pthread_create`/`pthread_join`. The Bash script auto-compiles it on first use of `-t` and invokes the binary with all canary file paths.

**Verification:**
```
cat /proc/$(pgrep monitor_thread)/status | grep Threads
# Threads: 5  (one process, multiple threads)
```
'@
CreateAndClose "-t flag does not use real POSIX threads" $body1 "81e532f"

# 2
$body2 = @'
In the main `canaryfs` script, `MONITOR_THREAD_BIN="${SCRIPT_DIR}/lib/monitor_thread"` was declared **before** `SCRIPT_DIR` itself was set. The path expanded to just `/lib/monitor_thread` and thread mode would fail.

**Fix:** Moved `SCRIPT_DIR` definition to the top of the script, before any variable that depends on it.
'@
CreateAndClose "MONITOR_THREAD_BIN defined before SCRIPT_DIR (variable ordering bug)" $body2 "81e532f"

# 3
$body3 = @'
Running `./canaryfs ...` as a non-root user fails with:
```
ERROR: cannot create log directory /var/log/canaryfs
```

This blocks all testing for normal users.

**Workarounds documented:**
- Option A: `./canaryfs -l /tmp/canaryfs_logs ...` (custom dir)
- Option B: `sudo mkdir -p /var/log/canaryfs && sudo chown $USER:$USER /var/log/canaryfs` (one-time setup)

**Fix:** Documented both workarounds in the README and demo script. The `-l` flag was already implemented.
'@
CreateAndClose "Default log directory /var/log/canaryfs requires root" $body3 "a039c29"

# 4
$body4 = @'
Alerts in fork/subshell modes were logged with corrupted paths:
```
file=/tmp/honeypot/.env.env
file=/tmp/honeypot/id_rsaid_rsa
```

**Root cause:** When `inotifywait` watches a single file, the output is just the full path (no `%w%f` split). The code tried to reconstruct the path which appended the basename to a path that already contained it.

**Fix:** When watching a single file, pass `target_file` directly to `_capture_forensics` — no reconstruction needed.
'@
CreateAndClose "monitor_file produces duplicated file paths in alerts" $body4 "3e77b2f"

# 5
$body5 = @'
Triggering with `cat /tmp/honeypot/.env` produced:
```
ALERT : canary accessed — pid=unknown process=unknown uid=unknown ppid=unknown
```

**Root cause:** `cat` reads tiny files in microseconds. By the time `inotifywait` fires the event and we spawn `lsof` (which takes 1-3ms), the file is already closed and `lsof` finds nothing.

**Fix:** Added a retry loop in both `monitor.sh` and `monitor_thread.c` — up to 5 attempts with 1ms delay between each. This catches more cases.

**Limitation:** Truly instant reads still escape detection. Full elimination would require **fanotify** (kernel API that includes PID directly in the event), which is documented as a future improvement.

**Verified working with:** `less`, `nano`, `vim`, `cp`, `exec 3<`.
'@
CreateAndClose "Forensic capture shows 'unknown' for fast commands like cat" $body5 "3c0eba0"

# 6
$body6 = @'
Pressing Ctrl+C on canaryfs left zombie watchers running in the background. Multiple orphans were still alive after the parent exited.

These would keep consuming inotify watches and could prevent future runs.

**Fix:** Added a cleanup function and `trap cleanup SIGINT SIGTERM` to `canaryfs`. On signal, it kills all child `inotifywait` and `monitor_thread` processes via `pkill -P` and exits cleanly.

**Verification after fix:** `pgrep -af inotifywait` returns empty after Ctrl+C.
'@
CreateAndClose "No signal handling — Ctrl+C leaks orphan inotifywait processes" $body6 "3c0eba0"

# 7
$body7 = @'
The repository contained a `canaryfs.conf` file with default values, but the main script never sourced it. Users could not change defaults without editing the script.

**Fix:** Added a sourcing block right after global variable definitions that loads `canaryfs.conf` if it exists, then rebuilds dependent paths like `LOG_FILE`.

Command-line flags still take priority over config file values.
'@
CreateAndClose "canaryfs.conf is never loaded — config file ignored" $body7 "3c0eba0"

# 8
$body8 = @'
For the academic submission, a clear page-by-page explanation of every script was needed.

**Fix:** Added `docs/index.html` — a single-file responsive website with:
- Overview and project structure
- Full execution flow diagrams
- Per-file documentation (canaryfs, plant.sh, monitor.sh, monitor_thread.c, log.sh, alert.sh, restore.sh)
- Test scenarios explained
- Syntax highlighting via highlight.js
- Dark cybersecurity theme

Hostable on GitHub Pages by setting Source = `main` / `/docs`.
'@
CreateAndClose "No documentation website for the project" $body8 "a039c29"

Write-Host ""
Write-Host "All 8 issues created and closed." -ForegroundColor Green
Write-Host "Visit: https://github.com/$Repo/issues?q=is%3Aclosed" -ForegroundColor Yellow
