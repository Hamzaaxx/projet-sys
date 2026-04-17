# canaryfs — Honeypot Canary File System Monitor

**Module:** Théorie des systèmes d'exploitation & SE Windows/Unix/Linux  
**Institution:** ENSET Mohammedia — Université Hassan II de Casablanca  
**Deadline:** 14/05/2026 at 23:59:59

---

## What is canaryfs?

`canaryfs` is a Bash-based cybersecurity tool that plants fake "bait" files
across your filesystem and silently monitors them for unauthorized access.
The moment any user, process, or malware touches a canary file, the tool
captures a full forensic snapshot and fires an alert.

This technique is used in real enterprise environments under the name
"canary tokens" or "honeypot files".

---

## Usage

```bash
canaryfs [options] <target_directory>
```

### Options

| Option | Description | Privileges |
|--------|-------------|------------|
| `-h` | Display this help / man-page documentation | Any user |
| `-f` | Deploy canaries via fork (parallel child processes) | Any user |
| `-t` | Monitor canaries via threads (parallel background watchers) | Any user |
| `-s` | Run watcher as a persistent background subshell (daemon mode) | Any user |
| `-l <dir>` | Set custom log directory (default: `/var/log/canaryfs`) | Any user |
| `-r` | Remove all canaries and restore filesystem state | **Root only** |
| `-p <n>` | Number of canary files to plant (default: 10) | Any user |
| `-a` | Alert mode: write to syslog + send desktop notification | Any user |

### Examples

```bash
# Plant 10 canaries in /home/hamza and monitor with threads
canaryfs -t -p 10 /home/hamza

# Deploy canaries in parallel using fork, with custom log directory
canaryfs -f -l /tmp/mylogs /var/www

# Run as daemon in background subshell
canaryfs -s /etc

# Remove all planted canaries (root required)
sudo canaryfs -r /home/hamza
```

---

## Canary File Types

| Filename | Mimics |
|----------|--------|
| `id_rsa` | SSH private key |
| `.env` | Environment file with fake secrets |
| `credentials.json` | AWS / GCP credentials |
| `shadow.bak` | Password hash backup |
| `backup.sql` | Database dump |

---

## Log Format

All events are logged to `/var/log/canaryfs/history.log`:

```
yyyy-mm-dd-hh-mm-ss : username : INFOS : standard output message
yyyy-mm-dd-hh-mm-ss : username : ERROR : error message
yyyy-mm-dd-hh-mm-ss : username : ALERT : canary accessed — file=<path> pid=<n> process=<name> uid=<n> ppid=<n>
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| `100` | Non-existent option entered |
| `101` | Missing mandatory parameter (target directory) |
| `102` | inotifywait not available on this system |
| `103` | Target directory does not exist |
| `104` | Restore (-r) requires root privileges |

After every error, the `-h` help message is displayed automatically.

---

## Test Scenarios

| Scenario | Canary Count | Directories | Goal |
|----------|-------------|-------------|------|
| Light | 5 | 1 | Measure baseline detection time |
| Medium | 50 | 5 | Compare fork vs thread speed |
| Heavy | 200 | 10+ recursive | Stress test all 3 modes under load |

---

## Project Structure

```
canaryfs/
├── canaryfs              # Main executable script
├── lib/
│   ├── plant.sh          # Canary file generation logic
│   ├── monitor.sh        # inotify watcher logic
│   ├── alert.sh          # Alert and notification logic
│   ├── restore.sh        # Canary removal and restore logic
│   └── log.sh            # Logging utilities
├── canaries/
│   ├── id_rsa.tpl        # SSH key template
│   ├── env.tpl           # .env file template
│   ├── credentials.tpl   # AWS credentials template
│   ├── shadow.tpl        # shadow.bak template
│   └── backup.tpl        # SQL dump template
├── tests/
│   ├── test_light.sh     # Light scenario (5 canaries)
│   ├── test_medium.sh    # Medium scenario (50 canaries)
│   └── test_heavy.sh     # Heavy scenario (200 canaries)
├── README.md
└── canaryfs.conf         # Default configuration file
```

---

## Dependencies

- `bash` >= 4.0
- `inotify-tools` (`inotifywait`) — install with `sudo apt install inotify-tools`
- `logger` — for syslog alerts (usually pre-installed)
- `notify-send` — for desktop notifications (optional, `-a` flag)

---

## Authors

Team ID: `Team-XX`  
Module: Systèmes d'Exploitation — ENSET Mohammedia 2026
