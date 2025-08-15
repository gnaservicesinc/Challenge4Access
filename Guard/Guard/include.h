//
//  include.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef include_h
#define include_h

#ifdef __STDC_ALLOC_LIB__
#define __STDC_WANT_LIB_EXT2__ 1
#else
#define _POSIX_C_SOURCE 200809L
#endif

#define __STDC_WANT_LIB_EXT1__ 1

#include <math.h>
#include <stdarg.h>
#include <iso646.h>
#include <ctype.h>
#include <limits.h>
#include <sys/ipc.h>
#include <locale.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stddef.h>
#include <assert.h>
#include <fcntl.h>
#include <stddef.h>
#include <uuid/uuid.h>
#include <stdbool.h>
#include <assert.h>
#include <fenv.h>
#include <float.h>
#include <limits.h>
#include <stdio.h> // needed for printf
#include <stdio.h>
#include <unistd.h> // For syscall()
#include <sys/syscall.h>
#include <pthread.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <assert.h>
#include <stdbool.h>
#include <stdalign.h>
#include <limits.h>
#include <inttypes.h>
#include <sys/stat.h>
#include <sys/random.h>
#include <assert.h>
#include <unistd.h>
#include <signal.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>
#include <stddef.h>
#include <locale.h>
#include <limits.h>
#include <stdint.h>
#include <stdbool.h>
#include <wchar.h>
#include <stdio.h>
#include <ctype.h>
#include <stddef.h>
#include <sys/stat.h>
#include <dirent.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/types.h>
#include <pwd.h>
#include <dlfcn.h>
#include <grp.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/syslog.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/dir.h>
#include <memory.h>
#include <sys/syscall.h>

#include "define.h"
#include "guard_main.h"
#include "change_to_user.h"
#include "error.h"
#include "main.h"
#endif // !include_h
