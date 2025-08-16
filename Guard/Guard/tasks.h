#ifndef C4A_TASKS_H
#define C4A_TASKS_H

#include "c4a_types.h"

double c4a_compute_N(const C4aContext *ctx, const C4aApp *app);
// Launches a task for app. type_hint may be NULL to auto-pick by settings flags.
// Returns 0 on success; sets *passed=1 for pass, 0 for fail. Sets *early_exit=1 if abnormal termination.
int c4a_launch_task_for_app(const C4aContext *ctx, const C4aApp *app, const char *type_hint, double N, int *passed, int *early_exit);

#endif

