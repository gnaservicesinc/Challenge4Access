//
//  error.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef error_h
#define error_h
#include "include.h"
void print_install_setups_unfinished(void);

//Will Abort
void guard_error(const char Msg[], ...);
//Will not Abort
void guard_warn(const char Msg[], ...);
void guard_notice(const char Msg[], ...);
void guard_log(const char *Msg,int level,bool abort);
#endif // !error_h
