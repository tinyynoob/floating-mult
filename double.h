#include <stdint.h>

typedef union ieee_double_precision DOUBLE;
union ieee_double_precision {
    uint64_t bits;
    double represent;
};

void show_bits(DOUBLE x)
{
    for (int i = 63; i >= 0; i--) {
        printf("%u", (unsigned) (x.bits >> i & 1));
        if (!(i & 7))
            putchar('_');
    }
    putchar('\n');
}

uint64_t get_sign(DOUBLE x)
{
    return x.bits >> 63;
}

uint64_t get_expn(DOUBLE x)
{
    return (x.bits >> 52) & (uint64_t) 0x7FF;
}

uint64_t get_mtsa(DOUBLE x)
{
    return x.bits & (((uint64_t) 1 << 52) - 1);
}