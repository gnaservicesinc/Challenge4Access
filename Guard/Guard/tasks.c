#include "include.h"
#include "tasks.h"

static int has_multiple_options(const C4aApp *app) {
    int n = 0;
    n += app->settings.task_maths_available ? 1 : 0;
    n += app->settings.task_lines_available ? 1 : 0;
    n += app->settings.task_clicks_available ? 1 : 0;
    n += app->settings.task_count_available ? 1 : 0;
    return n > 1;
}

static const char *pick_default_task(const C4aApp *app) {
    if (app->settings.task_maths_available) return "maths";
    if (app->settings.task_lines_available) return "lines";
    if (app->settings.task_clicks_available) return "clicks";
    if (app->settings.task_count_available) return "count";
    return "maths"; // default
}

static const char *choose_task_dialog(const C4aApp *app) {
    // Build a comma-separated list in AppleScript list literal
    char script[1024] = {0};
    char options[512] = {0};
    int first = 1;
    if (app->settings.task_maths_available) { strcat(options, first?"\"maths\"":" ,\"maths\""); first=0; }
    if (app->settings.task_lines_available) { strcat(options, first?"\"lines\"":" ,\"lines\""); first=0; }
    if (app->settings.task_clicks_available) { strcat(options, first?"\"clicks\"":" ,\"clicks\""); first=0; }
    if (app->settings.task_count_available) { strcat(options, first?"\"count\"":" ,\"count\""); first=0; }
    snprintf(script, sizeof(script),
             "osascript -e 'choose from list {%s} with prompt \"Choose a task to proceed\" default items {\"%s\"}'",
             options, pick_default_task(app));
    FILE *fp = popen(script, "r");
    if (!fp) return pick_default_task(app);
    static char choice[64];
    if (fgets(choice, sizeof(choice), fp) == NULL) { pclose(fp); return pick_default_task(app); }
    pclose(fp);
    // Trim newline
    size_t len = strlen(choice);
    if (len>0 && (choice[len-1]=='\n' || choice[len-1]=='\r')) choice[len-1]='\0';
    if (strlen(choice)==0 || strcmp(choice, "false")==0) return pick_default_task(app);
    return choice;
}

static const char *pick_task_type(const C4aApp *app) {
    if (has_multiple_options(app)) {
        return choose_task_dialog(app);
    }
    return pick_default_task(app);
}

double c4a_compute_N(const C4aContext *ctx, const C4aApp *app) {
    double Nt = app->memory.current_temperature;
    double gt = ctx->globals.globaltemp;
    double N = Nt;
    if (gt > 0.0) {
        if (Nt < gt) {
            double d = (gt - Nt) / gt;
            N = Nt * (1.0 - 0.5 * d);
        } else if (Nt > gt) {
            double d = (Nt - gt) / gt;
            N = Nt * (1.0 + d);
        }
    }
    N *= ctx->globals.final_multiplier;
    if (N < 0.0) N = 0.0;
    return N;
}

static int find_launch_task_script(char *buf, size_t buflen) {
    const char *candidates[] = {
        "/opt/c4a/bin/launch_task",
        "Challenge4Access/scripts/launch_task",
        NULL
    };
    for (int i = 0; candidates[i]; ++i) {
        if (access(candidates[i], X_OK) == 0) { snprintf(buf, buflen, "%s", candidates[i]); return 0; }
    }
    return -1;
}

int c4a_launch_task_for_app(const C4aContext *ctx, const C4aApp *app, const char *type_hint, double N, int *passed, int *early_exit) {
    (void)ctx;
    *passed = 0; *early_exit = 0;
    char spath[PATH_MAX] = {0};
    if (find_launch_task_script(spath, sizeof(spath)) != 0) {
        syslog(LOG_WARNING, "No task launcher found; denying by default");
        return 0;
    }
    const char *typ = type_hint ? type_hint : pick_task_type(app);
    char nbuf[64]; snprintf(nbuf, sizeof(nbuf), "%.3f", N);
    char gbuf[8]; snprintf(gbuf, sizeof(gbuf), "%d", ctx->globals.grade_tasks ? 1 : 0);
    char mbuf[32]; snprintf(mbuf, sizeof(mbuf), "%.2f", ctx->globals.min_grade_to_pass);

    pid_t pid = fork();
    if (pid < 0) { return -1; }
    if (pid == 0) {
        // Child: exec launcher
        execl(spath, spath, typ, nbuf, gbuf, mbuf, (char*)NULL);
        _exit(111);
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        *early_exit = 1; return -1;
    }
    if (WIFSIGNALED(status)) { *early_exit = 1; return 0; }
    if (!WIFEXITED(status)) { *early_exit = 1; return 0; }
    int code = WEXITSTATUS(status);
    // Convention: launcher returns 0 or 1; anything else treated as fail
    if (code == 1) { *passed = 1; }
    else { *passed = 0; }
    return 0;
}
