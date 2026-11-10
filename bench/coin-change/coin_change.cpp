// LeetCode 322. Coin Change -- bottom-up DP, O(coins * amount) time, O(amount) space.
// Kept line-for-line equivalent to coin_change.rs and coin_change.zig.
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

extern "C" __attribute__((noinline))
int32_t coin_change(const uint32_t *coins, size_t n, size_t amount) {
    const uint32_t inf = static_cast<uint32_t>(amount) + 1;
    const size_t len = amount + 1;
    std::vector<uint32_t> dp(len, inf);
    dp[0] = 0;
    for (size_t i = 0; i < n; i++) {
        const size_t c = coins[i];
        for (size_t a = c; a < len; a++) {
            const uint32_t v = dp[a - c] + 1;
            if (v < dp[a]) dp[a] = v;
        }
    }
    const uint32_t best = dp[amount];
    return best > amount ? -1 : static_cast<int32_t>(best);
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
