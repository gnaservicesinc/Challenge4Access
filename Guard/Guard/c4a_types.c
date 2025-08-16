#include "include.h"
#include "c4a_types.h"

static void free_str(char **p) {
    if (p && *p) { free(*p); *p = NULL; }
}

void c4a_free_app(C4aApp *app) {
    if (!app) return;
    free_str(&app->settings.unique_id);
    free_str(&app->settings.display_name);
    free_str(&app->settings.trigger_id_type);
    free_str(&app->settings.trigger_id_data);
    free_str(&app->settings.group_key);
    free_str(&app->memory.last_seen_running_timestamp);
    free_str(&app->memory.date_time_of_last_free_open);
    free_str(&app->memory.last_open_time);
    free_str(&app->memory.last_burned_date_time);
    free(app);
}

void c4a_free_context(C4aContext *ctx) {
    if (!ctx) return;
    if (ctx->apps) {
        for (size_t i = 0; i < ctx->app_count; ++i) {
            c4a_free_app(ctx->apps[i]);
        }
        free(ctx->apps);
    }
    free(ctx);
}

C4aContext *c4a_context_new(void) {
    C4aContext *ctx = calloc(1, sizeof(C4aContext));
    if (!ctx) return NULL;
    ctx->globals.cycle_frequency_in_seconds = 60;
    ctx->globals.final_multiplier = 1.05;
    ctx->globals.globaltemp = 1.0;
    ctx->globals.can_fail_tasks = 1;
    ctx->globals.grade_tasks = 1;
    ctx->globals.min_grade_to_pass = 0.95;
    ctx->globals.ambient_temp = 1.0;
    ctx->globals.early_exit_enforment = 1;
    ctx->globals.early_exit_multiplyer = 10.0;
    ctx->globals.failed_multiplyer = 1.5;
    return ctx;
}

