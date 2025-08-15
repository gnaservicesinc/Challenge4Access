//
//  error.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef error_h
#define error_h
#include "include.h"
/*
 Alert   (level 1)
 Critical(level 2)
 Error   (level 3)
 Warning (level 4)
 Notice  (level 5)
 Info    (level 6)
 Debug   (level 7)
*/
void print_install_setups_unfinished(void);

//Will Abort
void guard_critical(const char Msg[], ...);

//May abort
void guard_error(const char Msg[], ...);

//Will not Abort
void guard_warn(const char Msg[], ...);
void guard_notice(const char Msg[], ...);


#endif // !error_h
