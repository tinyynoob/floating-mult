#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "mult.h"
#include "double.h"

#define CASENUM 1000000

int main()
{
    srand(time(NULL));
    FILE *xf = fopen("x_pattern.dat", "w");
    FILE *yf = fopen("y_pattern.dat", "w");
    FILE *rf = fopen("reference.dat", "w");
    for (int i = 0; i < CASENUM; i++) {
        DOUBLE x = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 |
                            (uint64_t) rand() << 16 | (uint64_t) rand()};
        DOUBLE y = {.bits = (uint64_t) rand() << 48 | (uint64_t) rand() << 32 |
                            (uint64_t) rand() << 16 | (uint64_t) rand()};
        fprintf(rf, "%lX\n", mult(y, x).bits);
        fprintf(xf, "%lX\n", x.bits);
        fprintf(yf, "%lX\n", y.bits);
    }
    fclose(rf);
    fclose(yf);
    fclose(xf);
    return 0;
}
