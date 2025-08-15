//
//  guard_main.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//
#include "include.h"
void guard_daemon_loop(void);



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
void guard_daemon_loop(void){
    sleep(5);
    //Pre Loop Checks
    
    //Loops Checks
    
    //Actions
    
    // Challanges
    
    //End loop actions
}

extern int guard_main(char* fchar){

    srand( (unsigned int) time(NULL));
    change_to_user(OPREATE_AS_USER);

    while (!file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        syslog(LOG_NOTICE, "New Guard Loop.");
        guard_daemon_loop();
        if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
            syslog(LOG_NOTICE, "Shutting down guard.");
            return 0;
        }
        syslog(LOG_NOTICE, "Sleeping.");
        sleep(60); // Sleep for 60 seconds
        syslog(LOG_NOTICE, "Waking up.");
    }
    
    syslog(LOG_NOTICE, "Shutting down guard.");
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
        perror("Error opening file");
        exit(EXIT_FAILURE);
    }
    fprintf(fp, "%s", myString);

      fclose(fp);
}
char *read_dat (void){
    FILE *fp;
    fp = fopen(_DD_PATH_1_, "rb+");  // open for reading/writing, do not truncate
   if (fp == NULL) {
        perror("Error opening file");
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


