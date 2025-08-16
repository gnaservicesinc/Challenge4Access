//
//  guard_main.c
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//
#include "include.h"
int guard_daemon_loop(void);



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
int guard_daemon_loop(void){
    if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        return(1);
    }
    sleep(5);
    if (file_exists(AUTHORIZED_TO_EXIT_FILE)) {
        return(1);
    }
    //Pre Loop Checks
    
    //Loops Checks
    
    //Actions
    
    // Challanges
    
    //End loop actions
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
        sleep(1);
        // [TODO] set up preprocessor directives to remove this line when --enable-debugging is not set
        guard_notice("DCYCLE over. Sleeping for C4A_GUARD_DCYCLE_TIME.");
        sleep(C4A_GUARD_DCYCLE_TIME); // Sleep for C4A_GUARD_DCYCLE_TIME seconds
        guard_notice("Waking for DCYCLE.");
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


