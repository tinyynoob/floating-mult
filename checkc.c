#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include "double.h"
#include "mult.h"

#define TESTNUM 100

int main()
{
    srand(time(NULL));
    for (int i = 0; i < TESTNUM; i++) {
        DOUBLE x = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 | (uint64_t) rand() << 16 | (uint64_t) rand()};
        DOUBLE y = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 | (uint64_t) rand() << 16 | (uint64_t) rand()};
        printf("x = %lf, y = %lf\n", x.represent, y.represent);
        uint64_t ref = (&(DOUBLE) {.represent = x.represent * y.represent})->bits;
        uint64_t my = mult(x, y).bits;
        if (ref == my) {
            puts("passed");
        } else {
            show_bits(x);
            show_bits(y);
            show_bits((DOUBLE) {.bits = ref});
            show_bits((DOUBLE) {.bits = my});
        }
    }
    return 0;
}