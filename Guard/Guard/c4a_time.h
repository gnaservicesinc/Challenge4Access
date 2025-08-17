#ifndef C4A_TIME_H
#define C4A_TIME_H

#include <stddef.h>

// Returns a monotonic timestamp in seconds (not affected by system time changes)
double c4a_mono_now(void);

// Attempts to sync with network time sources and caches an offset.
// Returns 0 on success, non-zero otherwise.
int c4a_time_sync(void);

// Returns a best-effort trusted epoch time in seconds, using network time if
// available (system time + cached offset), else falls back to system time.
double c4a_trusted_epoch_now(void);

#endif

