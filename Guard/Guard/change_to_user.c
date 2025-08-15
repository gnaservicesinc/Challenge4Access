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

void change_to_user (const char *szUserName)
{
  struct passwd *pw;

  pw = getpwnam(szUserName);
  if (pw != NULL)
  {
    uid_t uid = pw->pw_uid; // we now have the UID of the username
    
    printf ("UID of user %s is %d\n", szUserName, (int)uid);
    if (setuid (uid) != 0)
    {
        print_install_setups_unfinished();
      perror ("setuid");
    }
    else
    {
      // this will fail if you try to change to root without the SUID
      // bit set.  This executive needs to be owned by root (probably
      // group owned by root as well), and set the SUID bit with:
      //   suid a+s {executable}
    //  printf ("UID is now %d\n", (int)uid);
    }
  }
  else
  {
      print_install_setups_unfinished();
    perror ("getpwnam");
  }
}
