#ifndef C4A_DETECTION_H
#define C4A_DETECTION_H

#include "c4a_types.h"

int c4a_detect_pids_for_app(const C4aApp *app, pid_t *out, int max, int *count_out);
int c4a_kill_pids(pid_t *pids, int n);
int c4a_block_url(const char *pattern);

#endif
