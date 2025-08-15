//
//  change_to_user.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//
#include "include.h"
/* The <grp.h> header included via include.h already declares
 * `int initgroups(const char *name, gid_t gid)`.
 * The previous explicit declaration caused a conflicting‑types
 * error when compiling on systems that expose the prototype
 * from <grp.h>. It is unnecessary and removed here for
 * compatibility.
 */

int change_to_user(const char *szUserName)
{
    if (szUserName == NULL || szUserName[0] == '\0') {
        errno = EINVAL;
        perror("change_to_user: invalid username");
        return 0;
    }

    struct passwd *pw = getpwnam(szUserName);
    if (pw == NULL) {
        perror("getpwnam");
        return 0;
    }

    uid_t uid = pw->pw_uid;
    gid_t gid = pw->pw_gid;

    // Drop privileges to target user's primary group and all supplementary groups first.
    if (initgroups(szUserName, gid) != 0) {
        perror("initgroups");
        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_) {
            exit(EXIT_FAILURE);
        }
        return 0;
    }
    if (setgid(gid) != 0) {
        perror("setgid");
        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_) {
            exit(EXIT_FAILURE);
        }
        return 0;
    }
    if (setuid(uid) != 0) {
        print_install_setups_unfinished();
        perror("setuid");
        if (_FAIL_ON_UNAUTHOERIZED_ANY_ISSUE_) {
            exit(EXIT_FAILURE);
        }
        return 0;
    }
    return (int)uid;
}
