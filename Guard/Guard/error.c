//
//  error.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#include "include.h"
static void guard_log(const char Msg[],int level,bool abort);
extern bool _b_had_error_b_;
bool _b_had_error_b_=FALSE;

void print_install_setups_unfinished(void){
    printf("Privilege setup appears incomplete.\n");
    printf("Ask a system administrator to run:\n");
    printf("  sudo chown %s %s && sudo chmod u+s %s\n",
           OPREATE_AS_USER,
           AUTHORIZED_SELF_PATH,
           AUTHORIZED_SELF_PATH);
}

void guard_error(const char Msg[], ...){
    char* strm = (char*) strdup((char*) Msg);
    char* str=strm;
    va_list args;
    va_start(args, Msg);
    do {
        if(str) {
            //We will not abourt on the first error but abort on any aftert
            // by setting the abourt flag to _b_had_error_b_ (defaults to false) then
            // setting _b_had_error_b_ true
            guard_log(strdup(str),3,_b_had_error_b_);
            _b_had_error_b_=TRUE;
        }
    }while (str!=NULL);
    va_end(args);
    free(strm);
}
void guard_warn(const char Msg[], ...){
    char* strm = (char*) strdup((char*) Msg);
    char* str=strm;
    va_list args;
    va_start(args, Msg);
    do {
        if(str) {
            guard_log(strdup(str),4,0);
        }
    }while (str!=NULL);
    va_end(args);
    free(strm);
}
void guard_notice(const char Msg[], ...){
    char* strm = (char*) strdup((char*) Msg);
    char* str=strm;
    va_list args;
    va_start(args, Msg);
    do {
        if(str) {
            guard_log(strdup(str),5,0);
        }
    }while (str!=NULL);
    va_end(args);
    free(strm);
}
static void guard_log(const char Msg[],int level,bool abort){
    char* strm = (char*) strdup((char*) Msg);
    char* str=strm;
    setlogmask(LOG_UPTO(LOG_EMERG));
    openlog("c4a:Guard", LOG_NDELAY| LOG_CONS | LOG_PERROR |LOG_PID, LOG_SECURITY);
    syslog(level, Msg);
    closelog();
               
    if(abort){
        free(strm);
        exit(EXIT_FAILURE);
    }
    free(strm);
}
