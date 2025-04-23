#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void callback(void) { puts("callback()"); }

void shell(void) {
  execl("/bin/sh", "sh", NULL);
  exit(1);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    printf(stderr, "Usage: %s <text>\n", argv[0]);
    return 1;
  }

  struct {
    char buf[64];
    void (*callback)(void);
  } locals;

  locals.callback = callback;

  strcpy(locals.buf, argv[1]);

  puts("calling locals.callback()");
  locals.callback();

  puts("Returned here.");
  return 0;
}
