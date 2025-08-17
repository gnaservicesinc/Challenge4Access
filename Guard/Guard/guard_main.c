//
//  guard_main.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//
#include "include.h"
#include "c4a_types.h"
#include "c4a_store.h"
#include "guard_tick.h"
static C4aContext *g_ctx = NULL;
static int guard_daemon_loop(void);



uint32_t adler32(const char* s)
{
    uint32_t a = 1;
    uint32_t b = 0;
    const uint32_t MODADLER = 65521;

    size_t i = 0;
    while (s[i] != '\0')
    {
        a = (a + s[i]) % MODADLER;
        b = (b + a) % MODADLER;
        i++;
    }
    return (b << 16) | a;
}
uint32_t crc32(const char* s) {
    uint32_t crc = 0xffffffff;
    size_t i = 0;
    while (s[i] != '\0')
    {
        uint8_t byte = s[i];
        crc = crc ^ byte;
        for (uint8_t j = 8; j > 0; --j)
        {
            crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
        }

        i++;
    }
    return crc ^ 0xffffffff;
}
static int guard_daemon_loop(void){
    if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        return(1);
    }
    if (!g_ctx) {
        g_ctx = c4a_context_new();
        if (g_ctx) {
            c4a_bootstrap(g_ctx);
        }
    }
    if (g_ctx) {
        guard_tick(g_ctx);
    }
    return(0);
}

extern int guard_main(char* fchar){

    srand( (unsigned int) time(NULL));
    change_to_user();
    sleep(1);
    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
       // guard_notice("New Guard Loop.");
        guard_daemon_loop();
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            guard_notice("Shutting down guard.");
            return 0;
        }
        int dsec = C4A_GUARD_DCYCLE_TIME;
        if (g_ctx && g_ctx->globals.cycle_frequency_in_seconds > 0) {
            dsec = g_ctx->globals.cycle_frequency_in_seconds;
        }
        sleep(dsec);
    }
    
    guard_notice("Shutting down guard.");
    return ((int) 3);
}
bool file_exists(const char *filename)
{
    return access(filename, F_OK) == 0;
}
void write_dat (const char *myString){
    FILE *fp;
    fp = fopen(_DD_PATH_1_, "wb+");  //    destroy any current contents
   if (fp == NULL) {
       guard_error("Error opening file for writing");
        exit(EXIT_FAILURE);
    }
    fprintf(fp, "%s", myString);

      fclose(fp);
}
char *read_dat (void){
    FILE *fp;
    fp = fopen(_DD_PATH_1_, "rb+");  // open for reading/writing, do not truncate
   if (fp == NULL) {
       guard_error("Error opening file for reading");
        exit(EXIT_FAILURE);
    }
   int n=0;
   char str1[_DD_BUFF_MAX_+1]={0};

    rewind(fp);
     
    int c; // note: int, not char, required to handle EOF
    while ((c = fgetc(fp)) != EOF) { // standard C I/O file reading loop
    str1[n]=(char) c;
    n++;
    if(n>=_DD_BUFF_MAX_) {
        break;
        }
    }
    fclose(fp);

    return(strdup(str1));

}

void cmp_time()
{
    struct timespec ts1;
    clock_gettime(CLOCK_MONOTONIC, &ts1);
    sleep(1);
    struct timespec ts2;
    clock_gettime(CLOCK_MONOTONIC, &ts2);
    
int posix_dur = floor (1000.0 * ts2.tv_sec + 1e-6 * ts2.tv_nsec
                           - (1000.0 * ts1.tv_sec + 1e-6 * ts1.tv_nsec));
    
    printf("\n%i s\n",posix_dur);
}
