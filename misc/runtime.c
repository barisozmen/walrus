#include <stdio.h>

int _print_int(int x) {
  printf("Out: %i\n", x);
  return 0;
}

int _print_float(double x) {
  printf("Out: %g\n", x);
  return 0;
}

int _print_char(int x) {
  printf("%c", x);
  return 0;
}

int _print_str(char* s) {
  printf("Out: %s\n", s);
  return 0;
}

int _gets_int() {
  int x;
  if (scanf("%d", &x) == 1) {
    return x;
  }
  return 0;
}
