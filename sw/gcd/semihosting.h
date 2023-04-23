// Source: https://github.com/tomverbeure/vexriscv_ocd_blog

#ifndef SEMIHOSTING_H
#define SEMIHOSTING_H

void sh_write0(const char* buf);
void sh_writec(char c);
char sh_readc(void);
int printf_(const char* format, ...);

int getchar(void);

extern int sh_missing_host;

#endif
