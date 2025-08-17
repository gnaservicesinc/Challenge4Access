#include "include.h"
#include "c4a_types.h"
#include "c4a_requests.h"
#include <sqlite3.h>

static C4aApp *find_app_by_uid(C4aContext *ctx, const char *uid) {
    if (!ctx || !uid) return NULL;
    for (size_t i = 0; i < ctx->app_count; ++i) {
        C4aApp *a = ctx->apps[i];
        if (a && a->settings.unique_id && strcmp(a->settings.unique_id, uid) == 0) return a;
    }
    return NULL;
}

static void reward_all_others(C4aContext *ctx, C4aApp *target, double delta) {
    if (!ctx) return;
    for (size_t i = 0; i < ctx->app_count; ++i) {
        C4aApp *a = ctx->apps[i];
        if (!a || a == target) continue;
        double nt = a->memory.current_temperature - delta;
        if (nt < a->settings.starting_temperature) nt = a->settings.starting_temperature;
        a->memory.current_temperature = nt;
    }
}

static void ensure_requests_schema(sqlite3 *db) {
    const char *sql =
        "CREATE TABLE IF NOT EXISTS requests ("
        " id INTEGER PRIMARY KEY AUTOINCREMENT,"
        " ts INTEGER NOT NULL,"
        " user TEXT,"
        " type TEXT NOT NULL,"
        " app_unique_id TEXT,"
        " value REAL DEFAULT 0.0);";
    sqlite3_exec(db, sql, NULL, NULL, NULL);
}

int c4a_process_requests(C4aContext *ctx) {
    sqlite3 *db = NULL;
    if (sqlite3_open(REQUESTS_DB_PATH, &db) != SQLITE_OK) {
        return -1;
    }
    ensure_requests_schema(db);
    const char *sel = "SELECT id,type,app_unique_id,value FROM requests ORDER BY id";
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, sel, -1, &st, NULL) != SQLITE_OK) { sqlite3_close(db); return -1; }
    while (sqlite3_step(st) == SQLITE_ROW) {
        int rid = sqlite3_column_int(st, 0);
        const char *typ = (const char*)sqlite3_column_text(st, 1);
        const char *uid = (const char*)sqlite3_column_text(st, 2);
        double val = sqlite3_column_double(st, 3);
        C4aApp *app = uid ? find_app_by_uid(ctx, uid) : NULL;
        if (typ && strcmp(typ, "upgrade_permanent") == 0) {
            if (app) {
                app->memory.burned = 1;
                app->memory.burned_forever = 1;
                reward_all_others(ctx, app, ctx->globals.permanent_burn_reward > 0 ? ctx->globals.permanent_burn_reward : 0.5);
            }
        } else if (typ && strcmp(typ, "extend_burn") == 0) {
            if (app) {
                if (val < 0) val = 0;
                app->memory.hours_remaining_until_not_burned += val;
                double rr = ctx->globals.extend_burn_reward_per_hour > 0 ? ctx->globals.extend_burn_reward_per_hour : 0.005;
                reward_all_others(ctx, app, rr * val);
            }
        } else if (typ && strcmp(typ, "burn") == 0) {
            if (app) {
                app->memory.burned = 1;
                if (val > 0) app->memory.hours_remaining_until_not_burned = val;
                // Reward small
                double rr = ctx->globals.temp_increase_reward_ratio > 0 ? ctx->globals.temp_increase_reward_ratio : 0.05;
                reward_all_others(ctx, app, rr);
            }
        } else if (typ && strcmp(typ, "increase_temp") == 0) {
            if (app) {
                if (val > 0) app->memory.current_temperature += val;
                double rr = ctx->globals.temp_increase_reward_ratio > 0 ? ctx->globals.temp_increase_reward_ratio : 0.05;
                reward_all_others(ctx, app, rr * val);
            }
        }
        // Delete processed row
        char delsql[128]; snprintf(delsql, sizeof(delsql), "DELETE FROM requests WHERE id=%d", rid);
        sqlite3_exec(db, delsql, NULL, NULL, NULL);
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
    return 0;
}
