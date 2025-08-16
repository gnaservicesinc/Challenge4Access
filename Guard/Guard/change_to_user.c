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

volatile sig_atomic_t gSignalStatus;
void signal_handler(int signal);


// void change_to_user (const char *szUserName)
// Why pass when we know at compile time? Let's hardcode like this
void change_to_user (void)
{
  struct passwd *pw;
    
  pw = getpwnam(C4A_USER);
  if (pw != NULL)
  {
    uid_t uid = pw->pw_uid; // we now have the UID of the username
    
    printf ("UID of user %s is %d\n", C4A_USER, (int)uid);
    if (setuid (uid) != 0)
    {
        print_install_setups_unfinished();
        guard_notice("setiod failed");
    }
    else
    {
      // this will fail if you try to change to root without the SUID
      // bit set.  This executive needs to be owned by root (probably
      // group owned by root as well), and set the SUID bit with:
      //   suid a+s {executable}
    //  printf ("UID is now %d\n", (int)uid);
     //   guard_notice("Changed user");
        
    }
  }
  else
  {
      guard_notice("getpwnam failed");
      print_install_setups_unfinished();
  }
}
void signal_handler(int signal)
{
  gSignalStatus = signal;
}
