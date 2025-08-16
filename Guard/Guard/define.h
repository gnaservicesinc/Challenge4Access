//
//  define.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef DEF_H
#define DEF_H

#ifndef C4A_VERSION_MAJOR
#define C4A_VERSION_MAJOR 1
#endif
#ifndef C4A_VERSION_MINOR
#define C4A_VERSION_MINOR 3
#endif
#ifndef C4A_VERSION_REVISION
#define C4A_VERSION_REVISION 13
#endif
#ifndef C4A_USER
#define C4A_USER "guard"
#endif
#ifndef C4A_GUARD_USER
#define C4A_GUARD_USER "c4a"
#endif
#ifndef C4A_PATH
#define C4A_PATH "/opt/c4a"
#endif
#ifndef C4A_GUARD_DCYCLE_TIME
#define C4A_GUARD_DCYCLE_TIME 15
#endif
#ifndef C4A_TASKS_APPLICATIONS_DIR
#define C4A_TASKS_APPLICATIONS_DIR  "/opt/c4a/Applications"
#endif
#ifndef C4A_PER_TASK_SETTINGS_DIR
#define C4A_PER_TASK_SETTINGS_DIR "/opt/c4a/protected/ro/task_settings"
#endif
#ifndef AUTHORIZED_SELF_PATH
#define AUTHORIZED_SELF_PATH "/opt/c4a/bin/Guard"
#endif
#ifndef AUTHORIZED_TO_EXIT_FILE
#define AUTHORIZED_TO_EXIT_FILE "/opt/c4a/protected/com/.g4exit"
#endif
#ifndef APP_SETTINGS_DIR
#define APP_SETTINGS_DIR "/opt/c4a/protected/ro/app_settings"
#endif
#ifndef APP_MEMORIES_DIR
#define APP_MEMORIES_DIR "/opt/c4a/protected/memory/app_mem"
#endif
#ifndef GLOBAL_MEMORIES_DIR
#define GLOBAL_MEMORIES_DIR "/opt/c4a/protected/memory/global_memories"
#endif
#ifndef GLOBAL_SETTINGS_DIR
#define GLOBAL_SETTINGS_DIR "/opt/c4a/protected/ro/global_settings"
#endif
#ifndef RAS_USER_MAX_LEN
#define RAS_USER_MAX_LEN 1024
#endif
#ifndef _DD_PATH_1_
#define _DD_PATH_1_ "/opt/c4a/private/ryan/data.dat"
#endif
#ifndef _DD_BUFF_MAX_
#define _DD_BUFF_MAX_ 8098
#endif
#ifndef _FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_
#define _FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_ 1
#endif
#ifndef _FAIL_ON_WARNINGS_
#define _FAIL_ON_WARNINGS_ 1
#endif
#ifndef TRUE
#define TRUE 1
#endif
#ifndef true
#define true 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef false
#define false 0
#endif
#ifndef LOG_SECURITY
#define LOG_SECURITY    (13<<3)
#endif

#endif // !DEF_H
