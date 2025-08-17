#include "include.h"
#include "c4a_time.h"

static double g_offset_seconds = 0.0; // network_epoch - system_epoch at sync time
static int g_has_offset = 0;

#if defined(CLOCK_MONOTONIC)
#define HAVE_MONO 1
#else
#define HAVE_MONO 0
#endif

double c4a_mono_now(void) {
#if HAVE_MONO
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#else
    // Fallback if CLOCK_MONOTONIC is unavailable
    struct timeval tv; gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1e6;
#endif
}

static int parse_http_date(const char *datestr, long *out_epoch) {
    if (!datestr || !out_epoch) return -1;
    // Typical: Fri, 16 Aug 2025 18:01:43 GMT
    struct tm tmv; memset(&tmv, 0, sizeof(tmv));
    char *res = strptime(datestr, "%a, %d %b %Y %H:%M:%S GMT", &tmv);
    if (!res) return -1;
    // Use timegm if available; otherwise, convert as UTC via TZ workaround
    time_t t;
    #if defined(_BSD_SOURCE) || defined(__USE_BSD) || defined(__APPLE__)
    extern time_t timegm(struct tm*);
    t = timegm(&tmv);
    #else
    char *old = getenv("TZ");
    setenv("TZ", "UTC", 1); tzset();
    t = mktime(&tmv);
    if (old) setenv("TZ", old, 1); else unsetenv("TZ"); tzset();
    #endif
    if (t <= 0) return -1;
    *out_epoch = (long)t;
    return 0;
}

static int fetch_http_date_from(const char *url, long *out_epoch) {
    // Use curl to fetch headers and grep Date: line
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "/usr/bin/curl -sI --max-time 3 '%s' | /usr/bin/awk -F': ' 'tolower($1)==\"date\" {print substr($0, index($0,$2))}'", url);
    FILE *fp = popen(cmd, "r");
    if (!fp) return -1;
    char line[256] = {0};
    if (!fgets(line, sizeof(line), fp)) { pclose(fp); return -1; }
    pclose(fp);
    // Trim newline
    size_t len = strlen(line); if (len && (line[len-1]=='\n' || line[len-1]=='\r')) line[len-1]='\0';
    long epoch = 0;
    if (parse_http_date(line, &epoch) != 0) return -1;
    *out_epoch = epoch;
    return 0;
}

int c4a_time_sync(void) {
    const char *urls[] = {
        "https://www.google.com",
        "https://www.apple.com",
        "https://www.cloudflare.com",
        NULL
    };
    for (int i = 0; urls[i]; ++i) {
        long net_epoch = 0;
        if (fetch_http_date_from(urls[i], &net_epoch) == 0) {
            time_t sys_epoch = time(NULL);
            g_offset_seconds = (double)net_epoch - (double)sys_epoch;
            g_has_offset = 1;
            syslog(LOG_NOTICE, "Time sync success: offset=%.0f sec from %s", g_offset_seconds, urls[i]);
            return 0;
        }
    }
    syslog(LOG_WARNING, "Time sync failed (no sources)");
    return -1;
}

double c4a_trusted_epoch_now(void) {
    time_t sys_epoch = time(NULL);
    if (g_has_offset) return (double)sys_epoch + g_offset_seconds;
    return (double)sys_epoch;
}
