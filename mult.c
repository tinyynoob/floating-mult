#include <stdio.h>
#include <stdint.h>
#include "double.h"

// TODO: subnormal numbers, underflow

DOUBLE mult(DOUBLE x, DOUBLE y)
{
    /* NaN check */
    if ((get_expn(y) == 0x7FFu && get_mtsa(y))) {
        return y;
    } else if ((get_expn(x) == 0x7FFu && get_mtsa(x))) {
        return x;
    }

    uint64_t sign = 0, expn = 0, mtsa = 0;
    sign = get_sign(x) ^ get_sign(y);
    if (!x.bits && get_expn(y) == 0x7FFu && !get_mtsa(y)) {
        expn = 0x7FFu;
        mtsa = 1;
        goto ret;
    } else if (!y.bits && get_expn(x) == 0x7FFu && !get_mtsa(x)) {
        expn = 0x7FFu;
        mtsa = 1;
        goto ret;
    } else if (!x.bits || !y.bits) {
        expn = 0;
        mtsa = 0;
        goto ret;
    }

    expn = (get_expn(x) + get_expn(y) - 1023);
    __uint128_t mprod = ((__uint128_t) 1 << 52 | get_mtsa(x)) * ((__uint128_t) 1 << 52 | get_mtsa(y));
    int carry = mprod >> (52 + 52 + 1); // \in \{0, 1\}
    expn += carry;
    // show_bits((DOUBLE) {.bits = expn});
    if ((int64_t) expn >= 0x7FFu) { // magnitude too big
        expn = 0x7FFu;
        mtsa = 0;
        goto ret;
    } else if ((int64_t) expn <= 0) {   // magnitude too small
        expn = 0;
        mtsa = 0;
        goto ret;
    }
    expn &= (uint64_t) 0x7FFu;
    mtsa = (mprod >> (52 - 1 + carry));
    mtsa = (mtsa >> 1) + (mtsa & 1);    //rounding to nearest
    mtsa &= ((uint64_t) 1 << 52) - 1;
ret:;
    return (DOUBLE) {.bits = sign << 63 | expn << 52 | mtsa};
}

