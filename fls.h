#include <stdbool.h>
#include <stdint.h>

int fls32(uint32_t x)
{
    int ans = x > 0;
    bool m;
    m = x < ((uint32_t) 1 << 16);
    ans += (m && x) << 4;
    x >>= (!m) << 4;
    m = x < (1u << 8);
    ans += (m && x) << 3;
    x >>= (!m) << 3;
    m = x < (1u << 4);
    ans += (m && x) << 2;
    x >>= (!m) << 2;
    m = x < (1u << 2);
    ans += (m && x) << 1;
    x >>= (!m) << 1;
    m = x < (1u << 1);
    ans += (m && x);
    return ans;
}

int fls64(uint64_t x)
{
    int ans = x > 0;
    bool m;
    m = x < ((uint64_t) 1 << 32);
    ans += (m && x) << 5;
    x >>= (!m) << 5;
    m = x < ((uint64_t) 1 << 16);
    ans += (m && x) << 4;
    x >>= (!m) << 4;
    m = x < ((uint64_t) 1 << 8);
    ans += (m && x) << 3;
    x >>= (!m) << 3;
    m = x < ((uint64_t) 1 << 4);
    ans += (m && x) << 2;
    x >>= (!m) << 2;
    m = x < ((uint64_t) 1 << 2);
    ans += (m && x) << 1;
    x >>= (!m) << 1;
    m = x < ((uint64_t) 1 << 1);
    ans += (m && x);
    return ans;
}