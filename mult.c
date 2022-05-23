#include <stdio.h>
#include <stdint.h>
#include <limits.h>
#include "double.h"

DOUBLE mult(DOUBLE x, DOUBLE y)
{
    DOUBLE ans = {.bits = 0};
    /* sign */
    ans.bits |= ((get_sign(x) ^ get_sign(y)) << 63);
    /* exponents */
    ans.bits |= ((get_expn(x) + get_expn(y) - 1023) & (uint64_t) 0x7FF) << 52;
    /* mantissa */

    return ans;
}

int main()
{
    DOUBLE x, y;
    // show_bits((DOUBLE) {.bits = 65537});
    // show_bits((DOUBLE) {.bits = UINT64_MAX});

    x.represent = 3.5;
    show_bits(x);
    y.represent = 7.1;
    show_bits(y);
    show_bits((DOUBLE) {.represent = x.represent * y.represent});
    show_bits(mult(x, y));

    return 0;
}


