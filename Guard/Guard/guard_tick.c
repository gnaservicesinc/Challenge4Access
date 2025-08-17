#include "include.h"
#include <strings.h>
#include "c4a_types.h"
#include "c4a_store.h"
#include "detection.h"
#include "guard_tick.h"
#include "tasks.h"
#include "c4a_time.h"
#include "c4a_requests.h"

static double now_seconds(void) {
    return c4a_mono_now();
}

static char *now_iso8601(void) {
    time_t t = time(NULL);
    struct tm tmv; localtime_r(&t, &tmv);
    char *buf = malloc(32);
    if (!buf) return NULL;
    strftime(buf, 32, "%Y-%m-%dT%H:%M:%S", &tmv);
    return buf;
}

static time_t parse_iso8601_s(const char *s) {
    if (!s || !*s) return 0;
    struct tm tmv; memset(&tmv, 0, sizeof(tmv));
    char *r = strptime(s, "%Y-%m-%dT%H:%M:%S", &tmv);
    if (!r) return 0;
    return mktime(&tmv);
}

static double parse_epoch_or_iso(const char *s) {
    if (!s || !*s) return 0.0;
    // If numeric, parse as epoch seconds
    const char *p = s;
    int digit = 1;
    while (*p) { if (*p < '0' || *p > '9') { digit = 0; break; } p++; }
    if (digit) {
        return strtod(s, NULL);
    }
    time_t t = parse_iso8601_s(s);
    if (t <= 0) return 0.0;
    return (double)t;
}

int guard_tick(C4aContext *ctx) {
    if (!ctx) return -1;
    if (ctx->app_count == 0) {
        syslog(LOG_NOTICE, "Guard loop: 0 apps configured");
        return 0;
    }
    double tnow = now_seconds();

    double ambient_sum = 0.0; int ambient_n = 0;
    // Process any user requests first
    c4a_process_requests(ctx);
    for (size_t i = 0; i < ctx->app_count; ++i) {
        C4aApp *app = ctx->apps[i];

        int cnt = 0; pid_t pids[64] = {0};
        c4a_detect_pids_for_app(app, pids, 64, &cnt);
        app->pids_len = cnt;
        app->is_running = (cnt > 0);

        if (app->memory.cooled == 0) { ambient_sum += app->memory.current_temperature; ambient_n++; }

        if (app->settings.always_blocked || app->memory.burned || app->memory.burned_forever) {
            app->allowed = 0;
            if (cnt > 0) {
                syslog(LOG_NOTICE, "Blocking %s (%s) pids=%d", app->settings.display_name ?: "app", app->settings.unique_id ?: "", cnt);
                c4a_kill_pids(pids, cnt);
            }
            if (app->settings.trigger_id_type && strcasecmp(app->settings.trigger_id_type, "url") == 0) {
                c4a_block_url(app->settings.trigger_id_data);
            }
        }

        if (app->allowed) {
            if (app->is_running && app->memory.last_open_time == NULL) {
                app->memory.last_open_time = now_iso8601();
                free(app->memory.last_seen_running_timestamp);
                app->memory.last_seen_running_timestamp = strdup(app->memory.last_open_time);
                app->allowed_since_mono = tnow;
            }
            if (!app->is_running) {
                app->allowed = 0;
                free(app->memory.last_open_time); app->memory.last_open_time = NULL;
                char *ts = now_iso8601();
                free(app->memory.last_seen_running_timestamp);
                app->memory.last_seen_running_timestamp = ts;
            }
            if (app->is_running && app->settings.seconds_of_usage_before_new_task > 0) {
                if (app->allowed_since_mono > 0 && (tnow - app->allowed_since_mono) >= app->settings.seconds_of_usage_before_new_task) {
                    app->allowed = 0;
                    free(app->memory.last_open_time); app->memory.last_open_time = NULL;
                    char *ts = now_iso8601();
                    free(app->memory.last_seen_running_timestamp);
                    app->memory.last_seen_running_timestamp = ts;
                }
            }
        }

        if (app->is_running) {
            app->memory.current_heat += app->settings.heat;
            app->memory.last_heat = app->memory.current_heat;
            app->memory.current_temperature += app->settings.heat_rate + app->settings.sensitivity * (app->settings.heat + app->memory.opens_since_last_cooled);
        } else {
            if (!app->memory.cooled) {
                double nt = app->memory.current_temperature - app->settings.cool_rate;
                if (nt < app->settings.starting_temperature) nt = app->settings.starting_temperature;
                app->memory.current_temperature = nt;
                if (nt == app->settings.starting_temperature && app->memory.opens_since_last_cooled > 0) {
                    app->memory.opens_since_last_cooled -= 1;
                    if (app->memory.opens_since_last_cooled == 0) app->memory.cooled = 1;
                }
            }
        }

        if (app->settings.conbustion_possible && app->memory.current_temperature >= app->settings.conbustion_temp) {
            app->memory.burned = 1;
            app->memory.lifetime_numbr_of_times_burned += 1;
            free(app->memory.last_burned_date_time);
            app->memory.last_burned_date_time = now_iso8601();
            if (!app->settings.can_recover_from_conbustion_possible) {
                app->memory.burned_forever = 1;
            } else {
                app->memory.hours_remaining_until_not_burned = (double)app->settings.recovery_length_in_hours_from_conbustion + (double)app->memory.opens_since_last_cooled + (double)app->memory.lifetime_numbr_of_times_burned;
                app->last_burn_check_mono = tnow;
            }
            // Notify user via BurnNotice app if available
            char cmd[1024];
            snprintf(cmd, sizeof(cmd), "/usr/bin/open -n -a '/opt/c4a/Applications/BurnNotice.app' --args burned '%s' '%s' '%.2f' '%.2f' '%s'", app->settings.unique_id ?: "", app->settings.display_name ?: "App", app->memory.current_temperature, app->settings.conbustion_temp, app->memory.burned_forever ? "forever" : "temp");
            system(cmd);
        }

        // Near-burn warning
        if (!app->memory.burned && app->settings.conbustion_possible && app->settings.conbustion_temp > 0) {
            double ratio = app->memory.current_temperature / app->settings.conbustion_temp;
            double warn_ratio = ctx->globals.burn_warning_ratio > 0 ? ctx->globals.burn_warning_ratio : 0.9;
            if (ratio >= warn_ratio) {
                if (tnow - app->last_warn_mono > 60.0) {
                    char cmdw[1024];
                    snprintf(cmdw, sizeof(cmdw), "/usr/bin/open -n -a '/opt/c4a/Applications/BurnNotice.app' --args warning '%s' '%s' '%.2f' '%.2f'", app->settings.unique_id ?: "", app->settings.display_name ?: "App", app->memory.current_temperature, app->settings.conbustion_temp);
                    system(cmdw);
                    app->last_warn_mono = tnow;
                }
            }
        }

        // Burn recovery countdown based on monotonic time
        if (app->memory.burned && !app->memory.burned_forever && app->last_burn_check_mono > 0 && app->memory.hours_remaining_until_not_burned > 0.0) {
            double delta = tnow - app->last_burn_check_mono;
            if (delta > 0) {
                app->memory.hours_remaining_until_not_burned -= (delta / 3600.0);
                if (app->memory.hours_remaining_until_not_burned <= 0.0) {
                    app->memory.hours_remaining_until_not_burned = 0.0;
                    app->memory.burned = 0;
                }
                app->last_burn_check_mono = tnow;
            }
        }

        // If not allowed and app is running: possibly grant free open, else block and gate
        if (!app->allowed && !app->memory.burned && !app->memory.burned_forever) {
            if (app->is_running) {
                // Daily free open if cooled and last free open > 24h ago (trusted epoch)
                if (app->memory.cooled) {
                    double nowe = c4a_trusted_epoch_now();
                    double last = parse_epoch_or_iso(app->memory.date_time_of_last_free_open);
                    if (last <= 0 || (nowe - last) >= 86400.0) {
                        app->allowed = 1;
                        app->allowed_since_mono = tnow;
                        app->memory.cooled = 0;
                        app->memory.opens_since_last_cooled += 1;
                        free(app->memory.last_open_time); app->memory.last_open_time = now_iso8601();
                        free(app->memory.last_seen_running_timestamp);
                        app->memory.last_seen_running_timestamp = strdup(app->memory.last_open_time);
                        app->memory.lifetime_opens += 1;
                        // Store trusted epoch as integer string
                        char buf[32]; snprintf(buf, sizeof(buf), "%.0f", nowe);
                        free(app->memory.date_time_of_last_free_open);
                        app->memory.date_time_of_last_free_open = strdup(buf);
                        c4a_save_app_memory(ctx, app);
                        goto next_app; // Skip blocking/gating
                    }
                }
                if (cnt > 0) { c4a_kill_pids(pids, cnt); }
                if (app->settings.trigger_id_type && strcasecmp(app->settings.trigger_id_type, "url") == 0) {
                    c4a_block_url(app->settings.trigger_id_data);
                }
                // Compute N and launch task
                double N = c4a_compute_N(ctx, app);
                int passed = 0, early = 0;
                c4a_launch_task_for_app(ctx, app, NULL, N, &passed, &early);
                if (early && ctx->globals.early_exit_enforment) {
                    app->memory.burned = 1;
                    app->memory.lifetime_numbr_of_times_burned += 1;
                    free(app->memory.last_burned_date_time);
                    app->memory.last_burned_date_time = now_iso8601();
                    if (!app->settings.can_recover_from_conbustion_possible) {
                        app->memory.burned_forever = 1;
                    } else {
                        app->memory.hours_remaining_until_not_burned = (double)app->settings.recovery_length_in_hours_from_conbustion + (double)app->memory.opens_since_last_cooled + (double)app->memory.lifetime_numbr_of_times_burned;
                    }
                } else if (passed) {
                    app->allowed = 1;
                    app->allowed_since_mono = tnow;
                    app->memory.cooled = 0;
                    app->memory.opens_since_last_cooled += 1;
                    free(app->memory.last_open_time); app->memory.last_open_time = now_iso8601();
                    free(app->memory.last_seen_running_timestamp);
                    app->memory.last_seen_running_timestamp = strdup(app->memory.last_open_time);
                    app->memory.lifetime_opens += 1;
                } else {
                    if (ctx->globals.can_fail_tasks) {
                        app->memory.current_temperature *= ctx->globals.failed_multiplyer;
                    }
                }
            } else if (app->settings.trigger_id_type && strcasecmp(app->settings.trigger_id_type, "url") == 0) {
                // For URLs we enforce by closing tabs even if not running PID-wise
                c4a_block_url(app->settings.trigger_id_data);
            }
        }

        c4a_save_app_memory(ctx, app);
next_app:;
    }

    if (ambient_n > 0) { ctx->globals.ambient_temp = ambient_sum / (double)ambient_n; }
    // Periodic time sync (hourly)
    static double last_sync = 0.0;
    if (last_sync == 0.0 || (tnow - last_sync) >= 3600.0) {
        c4a_time_sync();
        last_sync = tnow;
    }
    return 0;
}
