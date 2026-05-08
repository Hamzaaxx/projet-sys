# 🐦 canaryfs — Honeypot Canary File System Monitor

> **ENSET Mohammedia 2026 — Module: Systèmes d'Exploitation**
> Université Hassan II de Casablanca

A Bash-based cybersecurity tool that plants **fake bait files** ("canaries") across the filesystem and silently monitors them using the Linux kernel's **inotify** and **fanotify** subsystems. The moment any user, process, or malware touches a canary file, canaryfs captures a full forensic snapshot — process name, PID, UID, parent PID — and fires an alert.

This technique is used in real enterprise environments under the name *Canary Tokens* or *Honeypot Files*.

---

## ✨ Features

- 🎯 **5 realistic bait file types** — `id_rsa`, `.env`, `credentials.json`, `shadow.bak`, `backup.sql`
- ⚡ **4 execution modes** — sequential (default), fork, real POSIX threads, subshell daemon
- 🔬 **Atomic forensic capture** via `fanotify` — even microsecond-fast `cat` reads are caught with full process info
- 🧠 **Real C/pthreads implementation** for the `-t` flag — verified with `/proc/<pid>/status`
- 📜 **Triple-output logging** — terminal + log file + syslog (optional)
- 🔔 **Desktop notifications** via `notify-send` (`-a` flag)
- 🛡️ **Root-only restore** (`-r`) prevents attackers from cleaning up after detection
- 🪝 **Clean signal handling** — Ctrl+C kills all watchers, no orphans
- 🎨 **Auto-loading config file** (`canaryfs.conf`)

---

## 🚀 Quick Start

```bash
# 1. Install dependencies
sudo apt install inotify-tools build-essential -y

# 2. Clone the repo
git clone https://github.com/Hamzaaxx/projet-sys.git canaryfs
cd canaryfs
chmod +x canaryfs lib/*.sh tests/*.sh

# 3. Setup log directory (one-time)
sudo mkdir -p /var/log/canaryfs
sudo chown $USER:$USER /var/log/canaryfs

# 4. Plant canaries and start monitoring
mkdir /tmp/honeypot
sudo ./canaryfs -t -p 5 /tmp/honeypot
```

In another terminal, simulate an attacker:
```bash
cat /tmp/honeypot/.env
```

🚨 An ALERT line appears immediately in the first terminal:
```
2026-05-08-09-00-12 : root : ALERT : canary accessed — file=/tmp/honeypot/.env event=OPEN pid=12345 process=cat uid=1000 ppid=12000
```

---

## 📋 Usage

```
canaryfs [OPTIONS] <target_directory>
```

### Options

| Flag | Description | Privileges |
|------|-------------|------------|
| `-h` | Display help and man-page | Any |
| `-f` | Deploy via fork (one child process per canary) | Any |
| `-t` | Real POSIX threads (C/pthreads + fanotify) | **Root** |
| `-s` | Run as background subshell daemon | Any |
| `-l <dir>` | Custom log directory (default: `/var/log/canaryfs`) | Any |
| `-r` | Remove all canaries and restore filesystem | **Root** |
| `-p <n>` | Number of canary files to plant (default: 10) | Any |
| `-a` | Alert mode: syslog + desktop notifications | Any |

### Examples

```bash
# Plant 10 canaries with thread mode (most reliable forensics)
sudo ./canaryfs -t -p 10 /home/user

# Fork mode with a custom log directory
./canaryfs -f -l /tmp/mylogs /var/www

# Run as background daemon, monitor /etc
./canaryfs -s /etc

# Enable desktop alerts and syslog logging
./canaryfs -a -t /home/user

# Remove all planted canaries (root only)
sudo ./canaryfs -r /home/user
```

---

## 🧠 How It Works

```
        ┌──────────────────────────┐
        │   ./canaryfs -t /target  │
        └──────────┬───────────────┘
                   │
        ┌──────────▼───────────────┐
        │    plant_canaries()      │  → writes 5 fake files
        └──────────┬───────────────┘
                   │
        ┌──────────▼───────────────┐
        │     run_thread()         │  → spawns C binary
        └──────────┬───────────────┘
                   │
        ┌──────────▼───────────────┐
        │  monitor_thread (C)      │  → fanotify_init()
        │  pthread_create × N      │  → one thread per file
        └──────────┬───────────────┘
                   │
                   │  [ATTACKER touches the file]
                   ▼
        ┌──────────────────────────┐
        │  fanotify event arrives  │
        │  (PID embedded in event) │
        └──────────┬───────────────┘
                   │
        ┌──────────▼───────────────┐
        │  /proc/<pid>/comm        │  → process name
        │  /proc/<pid>/status      │  → UID, PPID
        └──────────┬───────────────┘
                   │
        ┌──────────▼───────────────┐
        │  ALERT logged to:        │
        │  • terminal              │
        │  • history.log           │
        │  • syslog (if -a)        │
        │  • desktop (if -a)       │
        └──────────────────────────┘
```

### Why fanotify and not just inotify?

The original implementation used `inotify + lsof`. The problem: by the time `lsof` ran, fast commands like `cat` had already closed the file, leading to `pid=unknown`.

**fanotify** is a Linux kernel API that includes the PID **directly inside the event**. No race condition. Every access is captured with full forensics — even microsecond-fast reads.

---

## 📁 Project Structure

```
canaryfs/
├── canaryfs                    # main executable script (entry point)
├── canaryfs.conf               # auto-loaded configuration defaults
├── demo.sh                     # 5-minute interactive demo
├── lib/
│   ├── plant.sh                # canary file generation
│   ├── monitor.sh              # inotify watcher + lsof forensics
│   ├── monitor_thread.c        # POSIX threads + fanotify (C)
│   ├── alert.sh                # syslog & desktop notifications
│   ├── log.sh                  # logging utilities
│   └── restore.sh              # root-only canary removal
├── tests/
│   ├── test_light.sh           # 5 canaries, 1 directory
│   ├── test_medium.sh          # 50 canaries, 5 directories
│   └── test_heavy.sh           # 200 canaries, 10 directories
├── docs/
│   └── index.html              # full documentation website
└── scripts/
    ├── create_issues.sh        # bash issue tracker
    └── create_issues.ps1       # powershell issue tracker
```

---

## 🛠️ Dependencies

| Package | Purpose | Install |
|---------|---------|---------|
| `bash >= 4.0` | Script runtime | preinstalled |
| `inotify-tools` | `inotifywait` for non-root modes | `sudo apt install inotify-tools` |
| `build-essential` | `gcc` to compile the C binary | `sudo apt install build-essential` |
| `lsof` | Forensic capture in fork/subshell modes | preinstalled |
| `logger` | Syslog support (`-a` flag) | preinstalled |
| `notify-send` | Desktop notifications (optional) | `sudo apt install libnotify-bin` |

---

## 📊 Test Scenarios

| Scenario | Canaries | Directories | Goal |
|----------|----------|-------------|------|
| **Light** | 5 | 1 | Baseline detection time |
| **Medium** | 50 | 5 | Compare fork vs thread speed |
| **Heavy** | 200 | 10 | Stress test all modes |

```bash
bash tests/test_light.sh
bash tests/test_medium.sh
bash tests/test_heavy.sh
```

Results are saved to `/tmp/canaryfs_*_results.txt`.

---

## 🚨 Error Codes

| Code | Meaning |
|------|---------|
| `100` | Unknown option |
| `101` | Missing target directory |
| `102` | inotifywait not installed |
| `103` | Target directory does not exist |
| `104` | Restore (`-r`) requires root |

---

## 📜 Log Format

```
2026-05-08-09-00-12 : kali : INFOS : Starting canaryfs on /tmp/honeypot [mode: thread]
2026-05-08-09-00-12 : kali : INFOS : Planted: /tmp/honeypot/.env
2026-05-08-09-00-15 : kali : ALERT : canary accessed — file=/tmp/honeypot/.env event=OPEN pid=4821 process=cat uid=1000 ppid=4800
2026-05-08-09-00-20 : kali : ERROR : inotifywait not found — install inotify-tools
```

Default location: `/var/log/canaryfs/history.log` (overridable with `-l`).

---

## 📚 Documentation

A full page-by-page explanation of every script lives in [`docs/index.html`](docs/index.html). Open it directly in a browser, or enable GitHub Pages on this repo with **Source = `main` branch / `/docs` folder**.

---

## 🎬 Demo

Run the interactive 7-step demo:
```bash
./demo.sh
```

It walks through every option, shows real pthread verification via `/proc`, demonstrates forensic capture, and tests the cleanup trap — perfect for a 5-minute presentation.

---

## 👥 Authors

**Team — ENSET Mohammedia 2026**
Module: Systèmes d'Exploitation Windows / Unix / Linux
Université Hassan II — Casablanca

---

## 📄 License

Academic project — ENSET Mohammedia 2026. All rights reserved.
