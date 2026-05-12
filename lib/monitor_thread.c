/*
 * monitor_thread.c — Real POSIX threads + fanotify forensic capture
 *
 * Uses fanotify (Linux kernel) which delivers the PID directly inside
 * the event, eliminating the race condition that affected the previous
 * inotify+lsof approach. Even fast commands like `cat` are now caught
 * with full process info.
 *
 * Requires CAP_SYS_ADMIN (run as root). Falls back gracefully with a
 * clear error message if launched without privileges.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <pwd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/fanotify.h>

/* Seconds between two alerts on the same file (avoids notification flood) */
#define ALERT_COOLDOWN_SEC 3
/* Ignore all events during the first N seconds (file manager scans new files) */
#define STARTUP_GRACE_SEC  5

static time_t start_time;   /* set in main(), shared across all threads */

/* System processes that routinely scan files — never alert on them.
 * Match is prefix-based so e.g. "tracker-miner-fs" matches "tracker". */
static const char *SYSTEM_PROC_BLACKLIST[] = {
    "tracker",       /* GNOME file indexer */
    "baloo",         /* KDE file indexer */
    "nautilus",      /* GNOME file manager */
    "dolphin",       /* KDE file manager */
    "thunar",        /* XFCE file manager */
    "gvfsd",         /* GNOME virtual filesystem */
    "gvfs",
    "thumbnail",     /* thumbnailers */
    "indexer",
    "updatedb",      /* mlocate */
    "mlocate",
    "plocate",
    "file",          /* mime detection */
    "find",
    "ls",            /* shell listing */
    "stat",
    "antivirus",     /* ClamAV etc. */
    "clamd",
    "freshclam",
    "systemd",
    "dbus",
    NULL
};

static int is_system_process(const char *name) {
    for (int i = 0; SYSTEM_PROC_BLACKLIST[i] != NULL; i++) {
        size_t plen = strlen(SYSTEM_PROC_BLACKLIST[i]);
        if (strncmp(name, SYSTEM_PROC_BLACKLIST[i], plen) == 0)
            return 1;
    }
    return 0;
}

typedef struct {
    char   file[512];
    char   log_file[512];
    time_t last_alert;   /* timestamp of last alert fired for this file */
} WatchArgs;

/* Map fanotify event mask to a short event name */
static const char *event_name(uint64_t mask) {
    if (mask & FAN_OPEN)   return "OPEN";
    if (mask & FAN_ACCESS) return "ACCESS";
    if (mask & FAN_MODIFY) return "MODIFY";
    return "UNKNOWN";
}

/* Read /proc/<pid>/comm and /proc/<pid>/status to fill in process info */
static void resolve_proc_info(int pid, char *proc_name, char *uid_str, char *ppid_str) {
    char path[64], buf[256];

    snprintf(path, sizeof(path), "/proc/%d/comm", pid);
    FILE *fp = fopen(path, "r");
    if (fp) {
        if (fgets(proc_name, 128, fp))
            proc_name[strcspn(proc_name, "\n")] = '\0';
        else strcpy(proc_name, "unknown");
        fclose(fp);
    } else strcpy(proc_name, "unknown");

    strcpy(uid_str,  "unknown");
    strcpy(ppid_str, "unknown");
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    fp = fopen(path, "r");
    if (fp) {
        while (fgets(buf, sizeof(buf), fp)) {
            if (strncmp(buf, "Uid:",  4) == 0) sscanf(buf + 4, "%31s", uid_str);
            if (strncmp(buf, "PPid:", 5) == 0) sscanf(buf + 5, "%31s", ppid_str);
        }
        fclose(fp);
    }
}

/* Write one ALERT line to terminal + log file */
static void write_alert(const char *log_file, const char *canary_file,
                        const char *event, int pid,
                        const char *proc_name, const char *uid, const char *ppid) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char timestamp[32];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d-%H-%M-%S", t);

    const char *username = getpwuid(getuid()) ? getpwuid(getuid())->pw_name : "unknown";

    char line[2048];
    snprintf(line, sizeof(line),
        "%s : %s : ALERT : canary accessed — file=%s event=%s pid=%d process=%s uid=%s ppid=%s\n",
        timestamp, username, canary_file, event, pid, proc_name, uid, ppid);

    fputs(line, stdout); fflush(stdout);
    FILE *fp = fopen(log_file, "a");
    if (fp) { fputs(line, fp); fclose(fp); }
}

/* Thread function — one thread per canary file */
void *watch_file(void *arg) {
    WatchArgs *w = (WatchArgs *)arg;

    /* fanotify gives us PID + fd in the event itself */
    int fan = fanotify_init(FAN_CLASS_NOTIF | FAN_CLOEXEC, O_RDONLY);
    if (fan == -1) {
        fprintf(stderr, "thread: fanotify_init failed for %s: %s\n",
                w->file, strerror(errno));
        free(w);
        return NULL;
    }

    if (fanotify_mark(fan, FAN_MARK_ADD,
                      FAN_OPEN | FAN_ACCESS | FAN_MODIFY,
                      AT_FDCWD, w->file) == -1) {
        fprintf(stderr, "thread: fanotify_mark failed for %s: %s\n",
                w->file, strerror(errno));
        close(fan);
        free(w);
        return NULL;
    }

    char buf[4096];
    ssize_t len;
    while ((len = read(fan, buf, sizeof(buf))) > 0) {
        struct fanotify_event_metadata *meta;
        for (meta = (struct fanotify_event_metadata *)buf;
             FAN_EVENT_OK(meta, len);
             meta = FAN_EVENT_NEXT(meta, len)) {

            /* Skip events fired by the monitor itself */
            if (meta->pid == getpid()) {
                if (meta->fd >= 0) close(meta->fd);
                continue;
            }

            time_t now = time(NULL);

            /* Grace period: ignore events right after startup (file manager scans) */
            if (now - start_time < STARTUP_GRACE_SEC) {
                if (meta->fd >= 0) close(meta->fd);
                continue;
            }

            char proc_name[128] = "unknown";
            char uid_str[32]    = "unknown";
            char ppid_str[32]   = "unknown";

            resolve_proc_info(meta->pid, proc_name, uid_str, ppid_str);

            /* Skip known system processes (indexers, file managers, etc.) */
            if (is_system_process(proc_name)) {
                if (meta->fd >= 0) close(meta->fd);
                continue;
            }

            /* Cooldown: skip if same file alerted less than ALERT_COOLDOWN_SEC ago */
            if (now - w->last_alert < ALERT_COOLDOWN_SEC) {
                if (meta->fd >= 0) close(meta->fd);
                continue;
            }
            w->last_alert = now;

            write_alert(w->log_file, w->file, event_name(meta->mask),
                        meta->pid, proc_name, uid_str, ppid_str);

            if (meta->fd >= 0) close(meta->fd);
        }
    }

    close(fan);
    free(w);
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: monitor_thread <log_file> <file1> [file2 ...]\n");
        return 1;
    }

    if (geteuid() != 0) {
        fprintf(stderr, "ERROR: -t (thread mode) uses fanotify which requires root.\n");
        fprintf(stderr, "       Run with:  sudo ./canaryfs -t ...\n");
        fprintf(stderr, "       Or use a non-root mode:  ./canaryfs -f ...  /  -s ...\n");
        return 2;
    }

    start_time = time(NULL);   /* record startup time for grace period */

    char *log_file = argv[1];
    int n = argc - 2;

    pthread_t *threads = malloc((size_t)n * sizeof(pthread_t));
    if (!threads) { perror("malloc"); return 1; }

    for (int i = 0; i < n; i++) {
        WatchArgs *w = malloc(sizeof(WatchArgs));
        if (!w) { perror("malloc"); continue; }
        strncpy(w->file,     argv[i + 2], 511); w->file[511]     = '\0';
        strncpy(w->log_file, log_file,    511); w->log_file[511] = '\0';
        if (pthread_create(&threads[i], NULL, watch_file, w) != 0) {
            perror("pthread_create");
            free(w);
            threads[i] = 0;
        }
    }

    for (int i = 0; i < n; i++)
        if (threads[i]) pthread_join(threads[i], NULL);

    free(threads);
    return 0;
}
