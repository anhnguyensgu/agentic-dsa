// LeetCode 322. Coin Change -- bottom-up DP, accumulator form with four
// independent accumulators.
//
// Same as coin_change_acc.cpp except that the reduction over coins is unrolled
// by four, each lane keeping its own running minimum, combined once at the
// end. A single accumulator makes every min wait for the previous one; four
// accumulators let the CPU work on four candidates at the same time.
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

static inline uint32_t relax(const uint32_t *dp, size_t a, uint32_t coin, uint32_t best) {
    const size_t c = coin;
    if (c <= a) {
        const uint32_t v = dp[a - c] + 1;
        if (v < best) return v;
    }
    return best;
}

extern "C" __attribute__((noinline))
int32_t coin_change(const uint32_t *coins, size_t n, size_t amount) {
    const uint32_t inf = static_cast<uint32_t>(amount) + 1;
    const size_t len = amount + 1;
    std::vector<uint32_t> dp(len, inf);
    dp[0] = 0;
    for (size_t a = 1; a < len; a++) {
        uint32_t b0 = inf, b1 = inf, b2 = inf, b3 = inf;
        size_t i = 0;
        for (; i + 4 <= n; i += 4) {
            b0 = relax(dp.data(), a, coins[i], b0);
            b1 = relax(dp.data(), a, coins[i + 1], b1);
            b2 = relax(dp.data(), a, coins[i + 2], b2);
            b3 = relax(dp.data(), a, coins[i + 3], b3);
        }
        for (; i < n; i++) b0 = relax(dp.data(), a, coins[i], b0);
        dp[a] = std::min(std::min(b0, b1), std::min(b2, b3));
    }
    const uint32_t result = dp[amount];
    return result > amount ? -1 : static_cast<int32_t>(result);
}

// usage: coin_change <reps> <amount> <coin>...
int main(int argc, char **argv) {
    if (argc < 4) return 2;
    const size_t reps = strtoull(argv[1], nullptr, 10);
    const size_t amount = strtoull(argv[2], nullptr, 10);
    std::vector<uint32_t> coins;
    for (int i = 3; i < argc; i++)
        coins.push_back(static_cast<uint32_t>(strtoull(argv[i], nullptr, 10)));

    int64_t sum = 0;
    for (size_t r = 0; r < reps; r++) {
        const size_t d = r & 7;
        const size_t amt = d > amount ? amount : amount - d;
        sum += coin_change(coins.data(), coins.size(), amt);
    }
    printf("%lld\n", static_cast<long long>(sum));
    return 0;
}
