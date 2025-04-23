#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  struct {
    char buffer[64];
    char path[64];
  } locals;

  if (argc < 2) {
    printf("Usage: %s <file-to-read>", argv[0]);
    exit(1);
  }

  // Usage of the unsafe strcpy function to simulate a buffer overflow
  strcpy(locals.path, "/usr/bin/cat");

  strcpy(locals.buffer, argv[1]);

  printf("locals.path = [%s]\n", locals.path);

  char *args[] = {locals.path, NULL};
  execv(locals.path, args);
}
