#include <stdio.h>
#include <stdint.h>
#include "double.h"

DOUBLE mult(DOUBLE x, DOUBLE y)
{
    DOUBLE ans = {.bits = 0};
    uint64_t sign = 0, expn = 0, mtsa = 0;
    sign = get_sign(x) ^ get_sign(y);
    expn = (get_expn(x) + get_expn(y) - 1023) & (uint64_t) 0x7FF;
    __uint128_t mprod = ((__uint128_t) 1 << 52 | get_mtsa(x)) * ((__uint128_t) 1 << 52 | get_mtsa(y));
    int carry = mprod >> (52 + 52 + 1); // \in \{0, 1\}
    expn += carry;
    mtsa = (mprod >> (52 - 1 + carry));
    mtsa = (mtsa >> 1) + (mtsa & 1);    //rounding to nearest
    mtsa &= ((uint64_t) 1 << 52) - 1;
    ans.bits |= sign << 63 | expn << 52 | mtsa;
    return ans;
}

