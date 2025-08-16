#include "include.h"
#include <strings.h>
#include "detection.h"

static const char *fallback_script_paths[] = {
    "/opt/c4a/bin/pcheck.sh",
    "/usr/local/bin/pcheck.sh",
    "/usr/bin/pcheck.sh",
    NULL
};

static int find_script(char *buf, size_t buflen) {
    for (int i = 0; fallback_script_paths[i]; ++i) {
        if (access(fallback_script_paths[i], X_OK) == 0) {
            snprintf(buf, buflen, "%s", fallback_script_paths[i]);
            return 0;
        }
    }
    // Try relative repo path during dev
    const char *rel = "Challenge4Access/scripts/pcheck.sh";
    if (access(rel, X_OK) == 0) { snprintf(buf, buflen, "%s", rel); return 0; }
    return -1;
}

static int call_pcheck(const char *mode, const char *data, pid_t *out, int max, int *count_out) {
    *count_out = 0;
    char spath[PATH_MAX] = {0};
    if (find_script(spath, sizeof(spath)) != 0) return 0;
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "\"%s\" %s \"%s\"", spath, mode, data ? data : "");
    FILE *fp = popen(cmd, "r");
    if (!fp) return -1;
    char line[256];
    while (fgets(line, sizeof(line), fp) != NULL) {
        char *end = NULL;
        long v = strtol(line, &end, 10);
        if (end == line) continue;
        if (*count_out < max) out[(*count_out)++] = (pid_t)v;
    }
    pclose(fp);
    return 0;
}

int c4a_detect_pids_for_app(const C4aApp *app, pid_t *out, int max, int *count_out) {
    if (!app || !app->settings.trigger_id_type) { *count_out = 0; return 0; }
    const char *type = app->settings.trigger_id_type;
    const char *data = app->settings.trigger_id_data ? app->settings.trigger_id_data : "";
    if (strcasecmp(type, "name") == 0) return call_pcheck("name", data, out, max, count_out);
    if (strcasecmp(type, "command") == 0) return call_pcheck("command", data, out, max, count_out);
    if (strcasecmp(type, "external") == 0) return call_pcheck("external", data, out, max, count_out);
    if (strcasecmp(type, "url") == 0) { *count_out = 0; return 0; }
    *count_out = 0; return 0;
}

int c4a_kill_pids(pid_t *pids, int n) {
    int killed = 0;
    for (int i = 0; i < n; ++i) {
        if (pids[i] <= 1) continue;
        if (kill(pids[i], SIGTERM) == 0) killed++;
    }
    sleep(1);
    for (int i = 0; i < n; ++i) {
        if (pids[i] <= 1) continue;
        kill(pids[i], SIGKILL);
    }
    return killed;
}

int c4a_block_url(const char *pattern) {
    if (!pattern || !*pattern) return 0;
    // Safari: close tabs whose URL contains pattern
    char cmd1[1024];
    snprintf(cmd1, sizeof(cmd1),
             "osascript -e 'tell application \"Safari\" to set ks to {}' "
             "-e 'tell application \"Safari\" to repeat with w in windows' "
             "-e 'repeat with t in tabs of w' "
             "-e 'if (URL of t as string) contains \"%s\" then set end of ks to {w,t}' "
             "-e 'end repeat' -e 'end repeat' "
             "-e 'repeat with k in ks' -e 'try' -e 'tell item 1 of k to close (item 2 of k)' -e 'end try' -e 'end repeat' >/dev/null 2>&1",
             pattern);
    system(cmd1);
    // Chrome: close tabs whose URL contains pattern
    char cmd2[1024];
    snprintf(cmd2, sizeof(cmd2),
             "osascript -e 'tell application \"Google Chrome\" to set ks to {}' "
             "-e 'tell application \"Google Chrome\" to repeat with w in windows' "
             "-e 'repeat with t in tabs of w' "
             "-e 'if (URL of t as string) contains \"%s\" then set end of ks to {w,t}' "
             "-e 'end repeat' -e 'end repeat' "
             "-e 'repeat with k in ks' -e 'try' -e 'tell item 1 of k to close (item 2 of k)' -e 'end try' -e 'end repeat' >/dev/null 2>&1",
             pattern);
    system(cmd2);
    // Firefox (best-effort via UI scripting): close windows whose title contains pattern (affects current tab)
    char cmd3[1024];
    snprintf(cmd3, sizeof(cmd3),
             "osascript -e 'tell application \"Firefox\" to activate' "
             "-e 'tell application \"System Events\" to tell process \"Firefox\" to set ks to {}' "
             "-e 'tell application \"System Events\" to tell process \"Firefox\" to repeat with w in windows' "
             "-e 'try' "
             "-e 'set t to name of w' "
             "-e 'if t contains \"%s\" then set end of ks to w' "
             "-e 'end try' "
             "-e 'end repeat' "
             "-e 'tell application \"System Events\" to repeat with w in ks' "
             "-e 'try' -e 'set frontmost of application \"Firefox\" to true' -e 'perform action \"AXRaise\" of w' -e 'keystroke \"w\" using command down' -e 'end try' -e 'end repeat' >/dev/null 2>&1",
             pattern);
    system(cmd3);
    return 0;
}
