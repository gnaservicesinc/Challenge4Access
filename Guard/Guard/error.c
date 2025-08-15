//
//  error.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#include "include.h"

void print_install_setups_unfinished(void){
    printf("Privilege setup appears incomplete.\n");
    printf("Ask a system administrator to run:\n");
    printf("  sudo chown %s %s && sudo chmod u+s %s\n",
           OPREATE_AS_USER,
           AUTHORIZED_SELF_PATH,
           AUTHORIZED_SELF_PATH);
}
