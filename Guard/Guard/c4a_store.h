#ifndef C4A_STORE_H
#define C4A_STORE_H

#include "c4a_types.h"

int c4a_bootstrap(C4aContext *ctx);
int c4a_reload_globals(C4aContext *ctx);
int c4a_load_apps(C4aContext *ctx);
int c4a_save_app_memory(C4aContext *ctx, C4aApp *app);

#endif

