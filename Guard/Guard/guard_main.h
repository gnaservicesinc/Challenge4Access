//
//  guard_main.h
//  Guard
//
//  Created by Andrew Smith on 8/14/25.
//

#ifndef guard_main_h
#define guard_main_h
#include "include.h"
extern int guard_main(char* fchar);
uint32_t crc32(const char* s);
uint32_t adler32(const char* s);
bool file_exists(const char *filename);
char *read_dat (void);
void write_dat (const char *myString);


#endif // !guard_main_h
