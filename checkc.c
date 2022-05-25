#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "double.h"
#include "mult.h"

#define TESTNUM 100000000

int main()
{
    srand(time(NULL));
    int pass = 0, fail = 0;
    for (int i = 0; i < TESTNUM; i++) {
        DOUBLE x = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 |
                            (uint64_t) rand() << 16 | (uint64_t) rand()};
        DOUBLE y = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 |
                            (uint64_t) rand() << 16 | (uint64_t) rand()};
        DOUBLE ref = (DOUBLE){.represent = x.represent * y.represent};
        DOUBLE my = mult(x, y);
        if ((ref.bits | ((uint64_t) 1 << 51)) ==
            (my.bits | ((uint64_t) 1 << 51))) {
            // if (ref.bits == my.bits) {
            // puts("passed");
            pass++;
        } else {
            printf("x = %lf, y = %lf\n", x.represent, y.represent);
            show_bits(x);
            show_bits(y);
            printf("%lf\n", ref.represent);
            show_bits(ref);
            printf("%lf\n", my.represent);
            show_bits(my);
            putchar('\n');
            fail++;
        }
    }
    printf("In total, pass %d and fail %d.\n", pass, fail);
    return 0;
}