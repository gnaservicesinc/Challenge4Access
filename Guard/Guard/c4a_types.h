#ifndef C4A_TYPES_H
#define C4A_TYPES_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    int cycle_frequency_in_seconds;
    double final_multiplier;
    double globaltemp;
    int can_fail_tasks;
    int grade_tasks;
    double min_grade_to_pass;
    double ambient_temp;
    int early_exit_enforment;
    double early_exit_multiplyer;
    double failed_multiplyer;
} C4aGlobalSettings;

typedef struct {
    char *unique_id;
    char *display_name;
    char *trigger_id_type;   // name|command|external|url
    char *trigger_id_data;
    int always_blocked;
    int always_discouraged;
    double sensitivity;
    double starting_temperature;
    double heat_rate;
    double cool_rate;
    int seconds_of_usage_before_new_task;
    double temperature_refresh_interval_in_seconds;
    double heat;
    int task_maths_available;
    int task_lines_available;
    int task_clicks_available;
    int task_count_available;
    int conbustion_possible;
    int can_recover_from_conbustion_possible;
    double conbustion_temp;
    int recovery_length_in_hours_from_conbustion;
    char *group_key; // filename of sqlv
} C4aAppSettings;

typedef struct {
    int cooled;
    char *last_seen_running_timestamp;
    int64_t lifetime_opens;
    int64_t opens_since_last_cooled;
    char *date_time_of_last_free_open;
    double current_heat;
    double last_heat;
    double current_temperature;
    char *last_open_time;
    int burned;
    int burned_forever;
    int64_t lifetime_numbr_of_times_burned;
    double hours_remaining_until_not_burned;
    char *last_burned_date_time;
} C4aAppMemory;

typedef struct {
    C4aAppSettings settings;
    C4aAppMemory memory;
    int allowed;
    int pids_len;
    pid_t pids[64];
    int is_running;
} C4aApp;

typedef struct {
    C4aGlobalSettings globals;
    C4aApp **apps;
    size_t app_count;
} C4aContext;

void c4a_free_app(C4aApp *app);
void c4a_free_context(C4aContext *ctx);
C4aContext *c4a_context_new(void);

#endif

