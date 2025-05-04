#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  struct {
    char filename[64];
    char path[64];
  } locals;

  if (argc < 2) {
    printf("Usage: %s <file-to-read>", argv[0]);
    exit(1);
  }

  // Usage of the unsafe strcpy function to simulate a buffer overflow
  strcpy(locals.path, "/bin/cat");

  strcpy(locals.filename, argv[1]);

  printf("locals.path = [%s]\n", locals.path);
  printf("locals.filename = [%s]\n", locals.filename);

  char *args[] = {locals.path, NULL, NULL};

  // to make the exploit reliable, check if locals.path was not overriden, so
  // the functionality without overflowing still works.
  if (strcmp(locals.path, "/bin/cat") == 0)
    args[1] = locals.filename;

  execv(locals.path, args);
}
