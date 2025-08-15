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


static void* guard_fork(void *ptr);
static void* guard_refork(void* fchar);

void signal_handler(int signal);
volatile sig_atomic_t gSignalStatus;

extern int main(int iargc,char* argv[]) {
    // Validate that we were launched from the authorized path.
    char resolved_path[PATH_MAX];
    memset(resolved_path, 0, sizeof(resolved_path));
    const char *argv0 = (iargc > 0 && argv && argv[0]) ? argv[0] : "";
    if (realpath(argv0, resolved_path) == NULL) {
        // Fall back to argv[0] if realpath fails
        strncpy(resolved_path, argv0, sizeof(resolved_path) - 1);
    }
    if (strcmp(AUTHORIZED_SELF_PATH, resolved_path) != 0) {
        fprintf(stderr,
                "Not launched from expected location.\nExpected: %s\nActual:   %s\n",
                AUTHORIZED_SELF_PATH, resolved_path);
        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_ == 1) {
            exit(EXIT_FAILURE);
        }
    }

    // Install a signal handler.
    signal(SIGTERM, signal_handler);

    // Launch the daemon once in a detached thread which performs the double-fork.
    pthread_t thread_guard_launcher;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    if (pthread_create(&thread_guard_launcher, &attr, guard_fork, NULL) != 0) {
        perror("pthread_create guard_fork");
        exit(EXIT_FAILURE);
    }
    pthread_attr_destroy(&attr);

    // Monitor for authorized exit file and terminate cleanly when present.
    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        sleep(1);
    }
    syslog(LOG_NOTICE, "Shutting down guard.");
    return EXIT_SUCCESS;
}



void signal_handler(int signal){
    gSignalStatus = signal;
}

static void* guard_fork(void *ptr){
    (void)ptr; // unused
    pid_t pid = fork();
    if (pid == 0) {
        // Child: proceed to daemonize
        guard_refork(NULL);
        _exit(EXIT_SUCCESS);
    }
    // Parent returns; thread will exit.
    pthread_exit((void*)NULL);
}

static void* guard_refork(void* fchar) {
    (void)fchar; // unused
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
    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        guard_main(NULL);
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            break;
        }
        sleep(15);
    }
    exit(EXIT_SUCCESS);
}
// removed unused guard_main_impl prototype and legacy commented block
