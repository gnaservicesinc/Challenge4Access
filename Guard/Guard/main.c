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

static void* guard_fork(void *ptr);
static void* guard_refork(void* fchar);

extern int main(int iargc,char* argv[]) {
    srand( (unsigned int) time(NULL));
    change_to_user(OPREATE_AS_USER);
    
    // Validate that we were launched from the authorized path.

    if (strcmp(AUTHORIZED_SELF_PATH, argv[0]) != 0) {
        fprintf(stderr,
                "Not launched from expected location.\nExpected: %s\nActual:   %s\n",
                AUTHORIZED_SELF_PATH, argv[0]);
        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_ == 1) {
            exit(EXIT_FAILURE);
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
    exit(EXIT_SUCCESS);
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
    return(0);

}




void guard_main_impl(void *ptr){
    pthread_t thread_guard_refork;
    pthread_create(&thread_guard_refork,
                                NULL,
                                guard_refork,
                                (void*) "" );
     sleep(1);
     pthread_detach(thread_guard_refork);
     exit(EXIT_SUCCESS);
    
}
static void* guard_fork(void *ptr){
    pthread_mutex_lock( &ntpad_mutex );
    pid_t pid = fork();
    if (pid == 0) {
        // Child: proceed to daemonize
        guard_main_impl(NULL);
        (NULL);
        _exit(EXIT_SUCCESS);
    }
    pthread_mutex_unlock( &ntpad_mutex );
    // Parent returns; thread will exit.
    pthread_exit((void*)NULL);
}

static void* guard_refork(void* fchar) {
    pthread_mutex_lock( &refork_mutex);

    // srand
    if (setsid() < 0) {
        perror("setsid in guard_refork");
        exit(EXIT_FAILURE);
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork in guard_refork");
        exit(EXIT_FAILURE);
    } else if (pid > 0) {
        // First child exits; grandchild continues.
        exit(EXIT_SUCCESS);
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
    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        guard_main(NULL);
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            break;
        }
        sleep(15);
    }
    pthread_mutex_unlock( &refork_mutex );
    pthread_exit((void*)NULL);
}
// removed unused guard_main_impl prototype and legacy commented block
