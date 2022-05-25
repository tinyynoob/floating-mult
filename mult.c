#include <stdio.h>
#include <stdint.h>
#include "double.h"
#include "fls.h"

DOUBLE mult(DOUBLE x, DOUBLE y)
{
    /* if NaN involved */
    if ((get_expn(y) == 0x7FFu && get_mtsa(y)))
        return y;
    else if ((get_expn(x) == 0x7FFu && get_mtsa(x)))
        return x;

    uint64_t sign = get_sign(x) ^ get_sign(y);
    uint64_t expn = 0, mtsa = 0;
    /* if \pm 0 involved */
    if (!(x.bits << 1) && get_expn(y) == 0x7FFu && !get_mtsa(y)) {
        expn = 0x7FFu;
        mtsa = 1;
        goto ret;
    } else if (!(y.bits << 1) && get_expn(x) == 0x7FFu && !get_mtsa(x)) {
        expn = 0x7FFu;
        mtsa = 1;
        goto ret;
    } else if (!(x.bits << 1) || !(y.bits << 1)) {
        expn = 0;
        mtsa = 0;
        goto ret;
    }

    /* else */
    if (!get_expn(x) && !get_expn(y)) { // subnormal * subnormal = 0
        expn = 0;
        mtsa = 0;
        goto ret;
    } else if (!get_expn(y)) {  // try to fix the subnormal number at x
        uint64_t temp = x.bits;
        x.bits = y.bits;
        y.bits = temp;
    }
    __uint128_t mprod;  // product of mantissas
    if (!get_expn(x)) { // x is subnormal and y is normal
        mprod = (__uint128_t) ((uint64_t) get_mtsa(x)) * ((uint64_t) 1 << 52 | get_mtsa(y));
        expn = fls64(mprod >> 52) - 12; // 64 = 12 + 52
        mprod <<= expn; // reposition
        expn = get_expn(y) - 1022 - expn; // may be negative
    } else {    // if both normal
        mprod = (__uint128_t) ((uint64_t) 1 << 52 | get_mtsa(x)) * ((uint64_t) 1 << 52 | get_mtsa(y));
        int carry = mprod >> (52 + 52 + 1); // \in {0, 1}
        mprod >>= carry;
        expn = get_expn(x) + get_expn(y) - 1023 + carry;    // may be negative
    }
    // Denoting mprod[127:0], mprod[104] is guaranteed to be 1.

    /* choose and generate valid format for output */
    if ((int64_t) expn >= 0x7FF) { // magnitude too big, rounding up to \infty
        expn = 0x7FFu;
        mtsa = 0;
        goto ret;
    } else if ((int64_t) expn > 0) {    // results in normal or \infty
        mprod >>= (52 - 1);
        mprod = (mprod >> 1) + (mprod & 1); // rounding to nearest
        int carry = mprod >> 53;    // \in {0, 1}
        mprod >>= carry;
        expn += carry;
        if (expn == 0x7FF)
            mtsa = 0;
        mtsa = mprod & (((uint64_t) 1 << 52) - 1);
        goto ret;
    } else if (0 >= (int64_t) expn && (int64_t) expn >= -52) { // results in subnormal or normal or 0
        mprod >>= 1 - expn;
        expn = 0;
        mprod >>= (52 - 1);
        mprod = (mprod >> 1) + (mprod & 1); // rounding to nearest
        int carry = mprod >> 52;    // \in {0, 1}
        expn += carry;
        // expn == 1 would not be a special case
        mtsa = mprod & (((uint64_t) 1 << 52) - 1);
        goto ret;
    } else if ((int64_t) expn < -52) {  // results in 0 (rounding)
        expn = 0;
        mtsa = 0;
        goto ret;
    }

ret:;
    return (DOUBLE) {.bits = sign << 63 | expn << 52 | mtsa};
}

