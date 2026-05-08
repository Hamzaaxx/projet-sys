#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <pwd.h>

typedef struct {
    char file[512];
    char log_file[512];
} WatchArgs;

static void write_alert(const char *log_file, const char *canary_file,
                        const char *event, const char *pid,
                        const char *process, const char *uid, const char *ppid) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char timestamp[32];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d-%H-%M-%S", t);

    const char *username = getpwuid(getuid()) ? getpwuid(getuid())->pw_name : "unknown";

    char line[2048];
    snprintf(line, sizeof(line),
        "%s : %s : ALERT : canary accessed — file=%s event=%s pid=%s process=%s uid=%s ppid=%s\n",
        timestamp, username, canary_file, event, pid, process, uid, ppid);

    /* print to terminal */
    fputs(line, stdout);
    fflush(stdout);

    /* append to log file */
    FILE *fp = fopen(log_file, "a");
    if (fp) {
        fputs(line, fp);
        fclose(fp);
    }
}

static void capture_forensics(const char *canary_file, const char *event,
                               const char *log_file) {
    char cmd[1024];
    char lsof_out[512] = {0};
    char proc_name[128] = "unknown";
    char pid_str[32]    = "unknown";
    char uid_str[32]    = "unknown";
    char ppid_str[32]   = "unknown";

    /* run lsof — retry up to 5 times within 5ms because fast commands
       (like cat) close the file before lsof can see them */
    snprintf(cmd, sizeof(cmd), "lsof '%s' 2>/dev/null | awk 'NR==2'", canary_file);
    for (int attempt = 0; attempt < 5; attempt++) {
        FILE *fp = popen(cmd, "r");
        if (fp) {
            lsof_out[0] = '\0';
            if (fgets(lsof_out, sizeof(lsof_out), fp) && lsof_out[0] != '\0') {
                sscanf(lsof_out, "%127s %31s %31s", proc_name, pid_str, uid_str);
                pclose(fp);
                break;
            }
            pclose(fp);
        }
        usleep(1000);  /* 1 ms */
    }

    /* read ppid from /proc if pid is known */
    if (strcmp(pid_str, "unknown") != 0) {
        char proc_path[64];
        snprintf(proc_path, sizeof(proc_path), "/proc/%s/status", pid_str);
        FILE *ps = fopen(proc_path, "r");
        if (ps) {
            char buf[128];
            while (fgets(buf, sizeof(buf), ps)) {
                if (strncmp(buf, "PPid:", 5) == 0) {
                    sscanf(buf + 5, "%31s", ppid_str);
                    break;
                }
            }
            fclose(ps);
        }
    }

    write_alert(log_file, canary_file, event, pid_str, proc_name, uid_str, ppid_str);
}

void *watch_file(void *arg) {
    WatchArgs *w = (WatchArgs *)arg;

    char cmd[600];
    snprintf(cmd, sizeof(cmd),
        "inotifywait -m -e access,open,modify --format '%%e' '%s' 2>/dev/null",
        w->file);

    FILE *fp = popen(cmd, "r");
    if (!fp) {
        free(w);
        return NULL;
    }

    char event[64];
    while (fgets(event, sizeof(event), fp)) {
        /* strip newline */
        event[strcspn(event, "\n")] = '\0';
        capture_forensics(w->file, event, w->log_file);
    }

    pclose(fp);
    free(w);
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: monitor_thread <log_file> <file1> [file2 ...]\n");
        return 1;
    }

    char *log_file = argv[1];
    int n = argc - 2;

    pthread_t *threads = malloc((size_t)n * sizeof(pthread_t));
    if (!threads) {
        perror("malloc");
        return 1;
    }

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

    for (int i = 0; i < n; i++) {
        if (threads[i]) pthread_join(threads[i], NULL);
    }

    free(threads);
    return 0;
}
