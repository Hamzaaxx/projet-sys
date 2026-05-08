#!/bin/bash
# canaryfs — 5-minute demo script for ENSET Mohammedia presentation
# Run this side-by-side with a second terminal for triggering canaries

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

pause() {
    echo ""
    echo -e "${YELLOW}── press ENTER to continue ──${NC}"
    read -r
}

step() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  STEP $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}$2${NC}"
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}" || exit 1

# ──────────────────────────────────────────────────────────────
clear
echo -e "${GREEN}"
cat <<'EOF'
   ┌─────────────────────────────────────────────────────────┐
   │                                                         │
   │   canaryfs — Honeypot Canary File System Monitor        │
   │   ENSET Mohammedia 2026 — Systèmes d'Exploitation       │
   │                                                         │
   │   5-minute demonstration                                │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"
pause

# ──────────────────────────────────────────────────────────────
step "1/7" "Show the help — six mandatory options"
echo "Command:  ./canaryfs -h"
pause
./canaryfs -h
pause

# ──────────────────────────────────────────────────────────────
step "2/7" "Plant 5 canaries in /tmp/honeypot using THREAD mode (real POSIX pthreads via C)"

sudo ./canaryfs -r /tmp/honeypot 2>/dev/null
rm -rf /tmp/honeypot && mkdir /tmp/honeypot

echo "Command:  ./canaryfs -t -p 5 /tmp/honeypot"
echo ""
echo "This will:"
echo "  • compile lib/monitor_thread.c with gcc -lpthread"
echo "  • plant 5 fake files (id_rsa, .env, credentials.json, ...)"
echo "  • spawn one POSIX thread per file"
pause

./canaryfs -t -p 5 /tmp/honeypot &
WATCHER=$!
sleep 3

# ──────────────────────────────────────────────────────────────
step "3/7" "Verify the threads are real (one process, multiple threads)"

echo "Command:  ps aux | grep monitor_thread"
ps aux | grep '[m]onitor_thread'
echo ""
echo "Command:  cat /proc/\$(pgrep monitor_thread)/status | grep Threads"
PID=$(pgrep monitor_thread | head -1)
[[ -n "$PID" ]] && cat /proc/$PID/status | grep Threads
echo ""
echo "Command:  ls /tmp/honeypot"
ls /tmp/honeypot
pause

# ──────────────────────────────────────────────────────────────
step "4/7" "Simulate a SLOW attacker (full forensic capture)"

echo "Triggering with:  exec 3</tmp/honeypot/.env  (holds file open 2 sec)"
echo ""
echo "Watch for the ALERT line in the output above..."
sleep 1
( exec 3</tmp/honeypot/.env; sleep 2; exec 3<&- )
sleep 2

echo ""
echo -e "${GREEN}✓ Full forensics captured: pid, process=zsh, uid, ppid${NC}"
pause

# ──────────────────────────────────────────────────────────────
step "5/7" "Simulate a FAST attacker (race condition with cat)"

echo "Triggering with:  cat /tmp/honeypot/id_rsa  (closes file in microseconds)"
echo ""
cat /tmp/honeypot/id_rsa > /dev/null
sleep 1

echo ""
echo -e "${YELLOW}Note: cat is so fast that lsof can't catch it → 'unknown'${NC}"
echo "This is a known limitation of inotify-based monitors."
echo "Production tools use fanotify which embeds PID in the kernel event."
pause

# ──────────────────────────────────────────────────────────────
step "6/7" "Stop watcher cleanly with SIGINT (Ctrl+C trap)"

echo "Sending SIGINT to PID ${WATCHER}..."
kill -SIGINT "${WATCHER}" 2>/dev/null
sleep 2
echo ""
echo "Verify no orphan watchers:"
echo "Command:  pgrep -af inotifywait"
pgrep -af inotifywait || echo "  (none — clean exit)"
pause

# ──────────────────────────────────────────────────────────────
step "7/7" "Restore — remove all canaries (root only)"

echo "Command:  sudo ./canaryfs -r /tmp/honeypot"
sudo ./canaryfs -r /tmp/honeypot
echo ""
echo "Command:  ls /tmp/honeypot"
ls /tmp/honeypot
pause

# ──────────────────────────────────────────────────────────────
clear
echo -e "${GREEN}"
cat <<'EOF'
   ┌─────────────────────────────────────────────────────────┐
   │                                                         │
   │   ✓  Demo complete                                      │
   │                                                         │
   │   Summary                                               │
   │   ───────                                               │
   │   • 8 options (-h -f -t -s -l -r -p -a)                 │
   │   • 4 execution modes (default, fork, thread, subshell) │
   │   • Real POSIX pthreads via C (lib/monitor_thread.c)    │
   │   • inotify + lsof + /proc forensic capture             │
   │   • Clean signal handling and cleanup                   │
   │   • Full logging to /var/log/canaryfs/history.log       │
   │                                                         │
   │   Repo:   github.com/Hamzaaxx/projet-sys                │
   │   Docs:   docs/index.html                               │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"
