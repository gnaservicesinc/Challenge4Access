//
//  main.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef h_main_h
#define h_main_h
#include "include.h"

//volatile sig_atomic_t gSignalStatus;
//void signal_handler(int signal);
extern int main(int argc,char* argv[]);
void guard_main_impl(void *ptr);

#endif // !h_main_h
