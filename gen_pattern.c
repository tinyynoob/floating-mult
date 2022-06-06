#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "mult.h"
#include "double.h"

#define CASENUM 100000

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
        /* generate some subnormal cases since they hardly appear */
        if (i < 200) { 
            x.bits &= 0x800FFFFFFFFFFFFFu;
            y.bits &= 0x800FFFFFFFFFFFFFu;
        } else if (i >= 200 && i < 600) {
            x.bits &= 0x800FFFFFFFFFFFFFu;
        } else if (i >= 600 && i < 1000) {
            y.bits &= 0x800FFFFFFFFFFFFFu;
        }
        fprintf(rf, "%lX\n", mult(y, x).bits);
        fprintf(xf, "%lX\n", x.bits);
        fprintf(yf, "%lX\n", y.bits);
    }
    fclose(rf);
    fclose(yf);
    fclose(xf);
    return 0;
}
