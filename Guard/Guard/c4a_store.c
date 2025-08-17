#include "include.h"
#include "c4a_types.h"
#include "c4a_store.h"
#include "error.h"
#include <sqlite3.h>

static char *path_join2(const char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    int need_slash = (la > 0 && a[la-1] != '/');
    char *p = malloc(la + need_slash + lb + 1);
    if (!p) return NULL;
    memcpy(p, a, la);
    if (need_slash) p[la++] = '/';
    memcpy(p + la, b, lb);
    p[la + lb] = '\0';
    return p;
}

static int ensure_parent_dir(const char *file_path) {
    // Best-effort: create parent directories if missing.
    char tmp[PATH_MAX];
    snprintf(tmp, sizeof(tmp), "%s", file_path);
    char *slash = strrchr(tmp, '/');
    if (!slash) return 0;
    *slash = '\0';
    struct stat st;
    if (stat(tmp, &st) == 0 && S_ISDIR(st.st_mode)) return 0;
    // Attempt to create recursively (shallow)
    if (mkdir(tmp, 0755) == 0) return 0;
    return errno;
}

static void set_default_globals(C4aGlobalSettings *g) {
    g->cycle_frequency_in_seconds = 60;
    g->final_multiplier = 1.05;
    g->globaltemp = 1.0;
    g->can_fail_tasks = 1;
    g->grade_tasks = 1;
    g->min_grade_to_pass = 0.95;
    g->ambient_temp = 1.0;
    g->early_exit_enforment = 1;
    g->early_exit_multiplyer = 10.0;
    g->failed_multiplyer = 1.5;
}

static int load_globals_from_db(const char *db_path, C4aGlobalSettings *out) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open(db_path, &db);
    if (rc != SQLITE_OK) {
        syslog(LOG_ERR, "global open failed: %s", sqlite3_errmsg(db));
        if (db) sqlite3_close(db);
        return -1;
    }
    const char *create_sql =
        "CREATE TABLE IF NOT EXISTS globsl_settings ("
        "unique_id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 1,"
        "cycle_frequency_in_seconds INTEGER NOT NULL,"
        "final_multiplier FLOAT NOT NULL DEFAULT 1.05,"
        "globaltemp FLOAT NOT NULL DEFAULT 1.0,"
        "can_fail_tasks BOOLEAN NOT NULL DEFAULT 1,"
        "grade_tasks BOOLEAN NOT NULL DEFAULT 1,"
        "min_grade_to_pass FLOAT NOT NULL DEFAULT 0.95,"
        "ambient_temp FLOAT NOT NULL DEFAULT 1.0,"
        "early_exit_enforment BOOLEAN NOT NULL DEFAULT 1,"
        "early_exit_multiplyer FLOAT NOT NULL DEFAULT 10.0,"
        "failed_multiplyer FLOAT NOT NULL DEFAULT 1.5,"
        "burn_warning_ratio FLOAT NOT NULL DEFAULT 0.9,"
        "permanent_burn_reward FLOAT NOT NULL DEFAULT 0.5,"
        "extend_burn_reward_per_hour FLOAT NOT NULL DEFAULT 0.005,"
        "temp_increase_reward_ratio FLOAT NOT NULL DEFAULT 0.05);";
    rc = sqlite3_exec(db, create_sql, NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        syslog(LOG_ERR, "global create failed: %d", rc);
        sqlite3_close(db);
        return -1;
    }
    const char *count_sql = "SELECT COUNT(*) FROM globsl_settings";
    sqlite3_stmt *st = NULL;
    rc = sqlite3_prepare_v2(db, count_sql, -1, &st, NULL);
    if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    int have = 0;
    if (sqlite3_step(st) == SQLITE_ROW) { have = sqlite3_column_int(st, 0); }
    sqlite3_finalize(st);
    if (have == 0) {
    const char *ins =
            "INSERT INTO globsl_settings (cycle_frequency_in_seconds,final_multiplier,globaltemp,can_fail_tasks,grade_tasks,min_grade_to_pass,ambient_temp,early_exit_enforment,early_exit_multiplyer,failed_multiplyer,burn_warning_ratio,permanent_burn_reward,extend_burn_reward_per_hour,temp_increase_reward_ratio)"
            " VALUES (60,1.05,1.0,1,1,0.95,1.0,1,10.0,1.5,0.9,0.5,0.005,0.05)";
        rc = sqlite3_exec(db, ins, NULL, NULL, NULL);
        if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    }
    const char *sel =
        "SELECT cycle_frequency_in_seconds,final_multiplier,globaltemp,can_fail_tasks,grade_tasks,min_grade_to_pass,ambient_temp,early_exit_enforment,early_exit_multiplyer,failed_multiplyer,burn_warning_ratio,permanent_burn_reward,extend_burn_reward_per_hour,temp_increase_reward_ratio FROM globsl_settings ORDER BY unique_id LIMIT 1";
    rc = sqlite3_prepare_v2(db, sel, -1, &st, NULL);
    if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    if (sqlite3_step(st) == SQLITE_ROW) {
        out->cycle_frequency_in_seconds = sqlite3_column_int(st, 0);
        out->final_multiplier = sqlite3_column_double(st, 1);
        out->globaltemp = sqlite3_column_double(st, 2);
        out->can_fail_tasks = sqlite3_column_int(st, 3);
        out->grade_tasks = sqlite3_column_int(st, 4);
        out->min_grade_to_pass = sqlite3_column_double(st, 5);
        out->ambient_temp = sqlite3_column_double(st, 6);
        out->early_exit_enforment = sqlite3_column_int(st, 7);
        out->early_exit_multiplyer = sqlite3_column_double(st, 8);
        out->failed_multiplyer = sqlite3_column_double(st, 9);
        out->burn_warning_ratio = sqlite3_column_double(st, 10);
        out->permanent_burn_reward = sqlite3_column_double(st, 11);
        out->extend_burn_reward_per_hour = sqlite3_column_double(st, 12);
        out->temp_increase_reward_ratio = sqlite3_column_double(st, 13);
    } else {
        sqlite3_finalize(st);
        sqlite3_close(db);
        return -1;
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
    return 0;
}

static int load_app_rows(sqlite3 *db, const char *group_key, C4aContext *ctx) {
    const char *sel =
        "SELECT unique_id,display_name,trigger_id_type,trigger_id_data,"
        "always_blocked,always_discouraged,sensitivity,starting_temperature,heat_rate,cool_rate,"
        "seconds_of_usage_before_new_task,temperature_refresh_interval_in_seconds,heat,"
        "task_maths_available,task_lines_available,task_clicks_available,task_count_available,"
        "conbustion_possible,can_recover_from_conbustion_possible,conbustion_temp,recovery_length_in_hours_from_conbustion"
        " FROM app_settings";
    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(db, sel, -1, &st, NULL);
    if (rc != SQLITE_OK) return -1;
    while ((rc = sqlite3_step(st)) == SQLITE_ROW) {
        C4aApp *app = calloc(1, sizeof(C4aApp));
        if (!app) break;
#define DUPCOL(i) strdup((const char*)sqlite3_column_text(st, (i)))
        app->settings.unique_id = DUPCOL(0);
        app->settings.display_name = DUPCOL(1);
        app->settings.trigger_id_type = DUPCOL(2);
        app->settings.trigger_id_data = DUPCOL(3);
        app->settings.always_blocked = sqlite3_column_int(st, 4);
        app->settings.always_discouraged = sqlite3_column_int(st, 5);
        app->settings.sensitivity = sqlite3_column_double(st, 6);
        app->settings.starting_temperature = sqlite3_column_double(st, 7);
        app->settings.heat_rate = sqlite3_column_double(st, 8);
        app->settings.cool_rate = sqlite3_column_double(st, 9);
        app->settings.seconds_of_usage_before_new_task = sqlite3_column_int(st, 10);
        app->settings.temperature_refresh_interval_in_seconds = sqlite3_column_double(st, 11);
        app->settings.heat = sqlite3_column_double(st, 12);
        app->settings.task_maths_available = sqlite3_column_int(st, 13);
        app->settings.task_lines_available = sqlite3_column_int(st, 14);
        app->settings.task_clicks_available = sqlite3_column_int(st, 15);
        app->settings.task_count_available = sqlite3_column_int(st, 16);
        app->settings.conbustion_possible = sqlite3_column_int(st, 17);
        app->settings.can_recover_from_conbustion_possible = sqlite3_column_int(st, 18);
        app->settings.conbustion_temp = sqlite3_column_double(st, 19);
        app->settings.recovery_length_in_hours_from_conbustion = sqlite3_column_int(st, 20);
        app->settings.group_key = strdup(group_key);
        // Duplicate unique_id handling: first wins; others ignored or fatal per _FAIL_ON_WARNINGS_
        if (app->settings.unique_id) {
            for (size_t i = 0; i < ctx->app_count; ++i) {
                if (ctx->apps[i] && ctx->apps[i]->settings.unique_id && strcmp(ctx->apps[i]->settings.unique_id, app->settings.unique_id) == 0) {
                    guard_error("Duplicate app unique_id '%s' in group '%s'.", app->settings.unique_id, group_key);
#if _FAIL_ON_WARNINGS_
                    guard_critical("Duplicate app unique_id detected and _FAIL_ON_WARNINGS_ is set. Aborting.");
#endif
                    c4a_free_app(app);
                    app = NULL;
                    break;
                }
            }
            if (!app) continue;
        }
        // Defaults for memory
        app->memory.cooled = 1;
        app->memory.current_temperature = app->settings.starting_temperature;
        app->allowed = 0;

        C4aApp **napps = realloc(ctx->apps, (ctx->app_count + 1) * sizeof(C4aApp*));
        if (!napps) { c4a_free_app(app); break; }
        ctx->apps = napps;
        ctx->apps[ctx->app_count++] = app;
    }
    sqlite3_finalize(st);
    return 0;
}

static int ensure_app_memory(const char *mem_db_path, const char *unique_id, C4aAppMemory *mem) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open(mem_db_path, &db);
    if (rc != SQLITE_OK) { if (db) sqlite3_close(db); return -1; }
    const char *create_sql =
        "CREATE TABLE IF NOT EXISTS app_memories ("
        "mID INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 1,"
        "app_unique_id STRING UNIQUE NOT NULL,"
        "cooled BOOLEAN NOT NULL DEFAULT 1,"
        "last_seen_running_timestamp STRING,"
        "lifetime_opens INTEGER,"
        "opens_since_last_cooled INTEGER DEFAULT 0,"
        "date_time_of_last_free_open STRING,"
        "current_heat FLOAT NOT NULL DEFAULT 0.0,"
        "last_heat FLOAT NOT NULL DEFAULT 0.0,"
        "current_temperature FLOAT NOT NULL DEFAULT 1.0,"
        "last_open_time STRING,"
        "burned BOOLEAN NOT NULL DEFAULT 0,"
        "burned_forever BOOLEAN NOT NULL DEFAULT 0,"
        "lifetime_numbr_of_times_burned INTEGER NOT NULL DEFAULT 0,"
        "hours_remaining_until_not_burned FLOAT DEFAULT 0,"
        "last_burned_date_time STRING)";
    rc = sqlite3_exec(db, create_sql, NULL, NULL, NULL);
    if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    sqlite3_stmt *st = NULL;
    const char *sel = "SELECT cooled,last_seen_running_timestamp,lifetime_opens,opens_since_last_cooled,date_time_of_last_free_open,current_heat,last_heat,current_temperature,last_open_time,burned,burned_forever,lifetime_numbr_of_times_burned,hours_remaining_until_not_burned,last_burned_date_time FROM app_memories WHERE app_unique_id=?";
    rc = sqlite3_prepare_v2(db, sel, -1, &st, NULL);
    if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    sqlite3_bind_text(st, 1, unique_id, -1, SQLITE_STATIC);
    int step = sqlite3_step(st);
    if (step == SQLITE_ROW) {
        mem->cooled = sqlite3_column_int(st, 0);
        free(mem->last_seen_running_timestamp); mem->last_seen_running_timestamp = strdup((const char*)sqlite3_column_text(st, 1));
        mem->lifetime_opens = sqlite3_column_int64(st, 2);
        mem->opens_since_last_cooled = sqlite3_column_int64(st, 3);
        free(mem->date_time_of_last_free_open); mem->date_time_of_last_free_open = strdup((const char*)sqlite3_column_text(st, 4));
        mem->current_heat = sqlite3_column_double(st, 5);
        mem->last_heat = sqlite3_column_double(st, 6);
        mem->current_temperature = sqlite3_column_double(st, 7);
        free(mem->last_open_time); mem->last_open_time = strdup((const char*)sqlite3_column_text(st, 8));
        mem->burned = sqlite3_column_int(st, 9);
        mem->burned_forever = sqlite3_column_int(st, 10);
        mem->lifetime_numbr_of_times_burned = sqlite3_column_int64(st, 11);
        mem->hours_remaining_until_not_burned = sqlite3_column_double(st, 12);
        free(mem->last_burned_date_time); mem->last_burned_date_time = strdup((const char*)sqlite3_column_text(st, 13));
        sqlite3_finalize(st);
        sqlite3_close(db);
        return 0;
    }
    sqlite3_finalize(st);
    const char *ins = "INSERT OR IGNORE INTO app_memories (app_unique_id) VALUES (?)";
    rc = sqlite3_prepare_v2(db, ins, -1, &st, NULL);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(st, 1, unique_id, -1, SQLITE_STATIC);
        sqlite3_step(st);
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
    return 0;
}

static int save_app_memory_impl(const char *mem_db_path, const char *unique_id, const C4aAppMemory *m) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open(mem_db_path, &db);
    if (rc != SQLITE_OK) { if (db) sqlite3_close(db); return -1; }
    const char *up =
        "UPDATE app_memories SET "
        "cooled=?,last_seen_running_timestamp=?,lifetime_opens=?,opens_since_last_cooled=?,date_time_of_last_free_open=?,"
        "current_heat=?,last_heat=?,current_temperature=?,last_open_time=?,"
        "burned=?,burned_forever=?,lifetime_numbr_of_times_burned=?,hours_remaining_until_not_burned=?,last_burned_date_time=?"
        " WHERE app_unique_id=?";
    sqlite3_stmt *st = NULL;
    rc = sqlite3_prepare_v2(db, up, -1, &st, NULL);
    if (rc != SQLITE_OK) { sqlite3_close(db); return -1; }
    sqlite3_bind_int(st, 1, m->cooled);
    sqlite3_bind_text(st, 2, m->last_seen_running_timestamp ? m->last_seen_running_timestamp : "", -1, SQLITE_STATIC);
    sqlite3_bind_int64(st, 3, m->lifetime_opens);
    sqlite3_bind_int64(st, 4, m->opens_since_last_cooled);
    sqlite3_bind_text(st, 5, m->date_time_of_last_free_open ? m->date_time_of_last_free_open : "", -1, SQLITE_STATIC);
    sqlite3_bind_double(st, 6, m->current_heat);
    sqlite3_bind_double(st, 7, m->last_heat);
    sqlite3_bind_double(st, 8, m->current_temperature);
    sqlite3_bind_text(st, 9, m->last_open_time ? m->last_open_time : "", -1, SQLITE_STATIC);
    sqlite3_bind_int(st, 10, m->burned);
    sqlite3_bind_int(st, 11, m->burned_forever);
    sqlite3_bind_int64(st, 12, m->lifetime_numbr_of_times_burned);
    sqlite3_bind_double(st, 13, m->hours_remaining_until_not_burned);
    sqlite3_bind_text(st, 14, m->last_burned_date_time ? m->last_burned_date_time : "", -1, SQLITE_STATIC);
    sqlite3_bind_text(st, 15, unique_id, -1, SQLITE_STATIC);
    sqlite3_step(st);
    sqlite3_finalize(st);
    sqlite3_close(db);
    return 0;
}

int c4a_reload_globals(C4aContext *ctx) {
    if (!ctx) return -1;
    set_default_globals(&ctx->globals);
    char *gpath = path_join2(GLOBAL_SETTINGS_DIR, "global.sqlite");
    if (!gpath) return -1;
    if (!file_exists(gpath)) {
        int pe = ensure_parent_dir(gpath);
        if (pe != 0) {
            syslog(LOG_WARNING, "globals parent dir not creatable (%d); using defaults", pe);
            free(gpath);
            return 0;
        }
    }
    if (load_globals_from_db(gpath, &ctx->globals) != 0) {
        syslog(LOG_WARNING, "loading globals failed; using defaults");
    }
    free(gpath);
    return 0;
}

int c4a_load_apps(C4aContext *ctx) {
    if (!ctx) return -1;
    DIR *d = opendir(APP_SETTINGS_DIR);
    if (!d) {
        syslog(LOG_WARNING, "APP_SETTINGS_DIR not readable; no apps loaded");
        return 0;
    }
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        const char *nm = ent->d_name;
        size_t ln = strlen(nm);
        if (ln < 6) continue;
        if (strcmp(nm + ln - 5, ".sqlv") != 0) continue;
        char *path = path_join2(APP_SETTINGS_DIR, nm);
        if (!path) continue;
        sqlite3 *db = NULL;
        if (sqlite3_open(path, &db) != SQLITE_OK) {
            syslog(LOG_WARNING, "open app settings failed: %s", path);
            free(path);
            continue;
        }
        load_app_rows(db, path, ctx);
        sqlite3_close(db);
        free(path);
    }
    closedir(d);

    for (size_t i = 0; i < ctx->app_count; ++i) {
        C4aApp *app = ctx->apps[i];
        const char *base = APP_MEMORIES_DIR;
        const char *uid = app->settings.unique_id ? app->settings.unique_id : "unknown";
        size_t len = strlen(base) + 1 + strlen(uid) + strlen(".sqlite") + 1;
        char *fname = malloc(len);
        if (fname) {
            snprintf(fname, len, "%s/%s.sqlite", base, uid);
            if (!file_exists(fname)) { ensure_parent_dir(fname); }
            ensure_app_memory(fname, uid, &app->memory);
            free(fname);
        }
    }
    return 0;
}

int c4a_save_app_memory(C4aContext *ctx, C4aApp *app) {
    (void)ctx;
    if (!app) return -1;
    const char *base = APP_MEMORIES_DIR;
    const char *uid = app->settings.unique_id ? app->settings.unique_id : "unknown";
    size_t len = strlen(base) + 1 + strlen(uid) + strlen(".sqlite") + 1;
    char *fname = malloc(len);
    if (!fname) return -1;
    snprintf(fname, len, "%s/%s.sqlite", base, uid);
    int rc = save_app_memory_impl(fname, uid, &app->memory);
    free(fname);
    return rc;
}

int c4a_bootstrap(C4aContext *ctx) {
    if (!ctx) return -1;
    c4a_reload_globals(ctx);
    c4a_load_apps(ctx);
    return 0;
}
