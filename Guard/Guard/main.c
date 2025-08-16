//
//  main.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

// After installing to
//  chown OPREATE_AS_USER AUTHORIZED_SELF_PATH && chmod u+s AUTHORIZED_SELF_PATH
// or run as root and allow setuid to target user as needed.
#include  "include.h"
pthread_mutex_t ntpad_mutex     = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t refork_mutex     = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t impl_mutex     = PTHREAD_MUTEX_INITIALIZER;

static void* guard_fork(void *ptr);
static void* guard_refork(void* fchar);

extern int main(int iargc,char* argv[]) {
    srand( (unsigned int) time(NULL));
    change_to_user();
    
    // Validate that we were launched from the authorized path.

    if (strcmp(AUTHORIZED_SELF_PATH, argv[0]) != 0) {

        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_ == 1) {
            guard_critical("Attempt to launch guard from an unauthorized location.");
        }
        else{
            guard_warn("Invalid launch location.\nO4A is not inteded to be moved after an install and may have issue. Please have a system admin repair this install.");
        }
    }



    pthread_t thread_guard_launcher;
    // Launch the daemon once in a detached thread which performs the double-fork.
   // lab1:;
   pthread_create(&thread_guard_launcher,
                               NULL,
                                guard_fork,
                               (void*) "" );
    sleep(1);
    pthread_detach(thread_guard_launcher);
   // Invalid.  pthread_attr_t attr;
    // Invalid. pthread_attr_init(&attr);
    // Invalid.  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    // Invalid.   if (pthread_create(&thread_guard_launcher, &attr, guard_fork, NULL) != 0) {
        // Invalid.       perror("pthread_create guard_fork");
        // Invalid.       exit(EXIT_FAILURE);
        // Invalid.   }
    // Invalid..  pthread_attr_destroy(&attr);

    // Invalid. // Monitor for authorized exit file and terminate cleanly when present.
    // Invalid.    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
    // Invalid.        sleep(1);
    // Invalid.   }
    guard_notice("Goodbye.");
    return(0);

}




void guard_main_impl(void *ptr){
    pthread_t thread_guard_refork;
    if (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        pthread_create(&thread_guard_refork,
                       NULL,
                       guard_refork,
                       (void*) "" );
        sleep(1);
        
        if (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            pthread_detach(thread_guard_refork);
        }
    }
    pthread_exit((void*)NULL);
    
}
static void* guard_fork(void *ptr){
    pthread_mutex_lock( &ntpad_mutex );
    pid_t pid = fork();
    if (pid == 0) {
        if (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            // Child: proceed to daemonize
            guard_main_impl(NULL);
            guard_notice("guard_fork - Child: proceed to daemonize");
        }
    }
    pthread_mutex_unlock( &ntpad_mutex );
    // Parent returns; thread will exit.
    pthread_exit((void*)NULL);
}

static void* guard_refork(void* fchar) {
    pthread_mutex_lock( &refork_mutex);

    // srand
    if (setsid() < 0) {
        guard_critical("setsid in guard_refork failed. setsid() returned less than 0.");
    }

    pid_t pid = fork();
    if (pid < 0) {
        guard_critical("setsid in guard_refork failed after fork with pid < 0.");
    } else if (pid > 0) {
       // guard_notice("First child exits; my grandchild continues.");
        // First child exits; grandchild continues.
        pthread_exit((void*)NULL);
       // exit(EXIT_SUCCESS);
    }

    // Grandchild (the actual daemon) continues here
    // Install a signal handler.
    umask(0);
    chdir("/");
    // Example: Close standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
    open("/dev/null", O_RDWR); // stdin
    dup(0); // stdout
    dup(0); // stderr
    pthread_mutex_unlock( &refork_mutex );
   
    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            goto endloop;
        }
        pthread_mutex_lock( &impl_mutex);
        guard_main(NULL);
        pthread_mutex_unlock( &impl_mutex );
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            goto endloop;
        }
        sleep(15);
    }
    endloop:;
    
    pthread_exit((void*)NULL);
}
// removed unused guard_main_impl prototype and legacy commented block
