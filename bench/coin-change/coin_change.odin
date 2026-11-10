// LeetCode 322. Coin Change -- bottom-up DP, O(coins * amount) time, O(amount) space.
// Kept line-for-line equivalent to coin_change.cpp, coin_change.rs and coin_change.zig.
//
// Uses libc directly (malloc/free/strtoull/printf), like the Zig version, so
// the allocator is the same glibc malloc the other binaries use. Odin's own
// heap allocator would also zero the table first.
package main

import "base:intrinsics"
import "base:runtime"
import "core:c/libc"

@(export, link_name = "coin_change")
coin_change :: proc "c" (coins: [^]u32, n: uint, amount: uint) -> i32 {
	inf := u32(amount) + 1
	size := amount + 1
	raw := libc.malloc(libc.size_t(size * size_of(u32)))
	if raw == nil {
		intrinsics.trap()
	}
	defer libc.free(raw)
	dp := ([^]u32)(raw)[:size]
	for i in 0 ..< size {
		dp[i] = inf
	}
	dp[0] = 0
	for coin in coins[:n] {
		c := uint(coin)
		for a := c; a < size; a += 1 {
			v := dp[a - c] + 1
			if v < dp[a] {
				dp[a] = v
			}
		}
	}
	best := dp[amount]
	return -1 if uint(best) > amount else i32(best)
}

// usage: coin_change <reps> <amount> <coin>...
main :: proc() {
	args := runtime.args__.([]cstring)
	if len(args) < 4 {
		libc.exit(2)
	}
	reps := uint(libc.strtoull(args[1], nil, 10))
	amount := uint(libc.strtoull(args[2], nil, 10))
	n := uint(len(args) - 3)
	coins := ([^]u32)(libc.malloc(libc.size_t(n * size_of(u32))))
	if coins == nil {
		intrinsics.trap()
	}
	for i in 0 ..< n {
		coins[i] = u32(libc.strtoull(args[3 + i], nil, 10))
	}

	sum: i64 = 0
	for r in 0 ..< reps {
		d := r & 7
		amt := amount if d > amount else amount - d
		sum += i64(#force_no_inline coin_change(coins, n, amt))
	}
	libc.printf("%lld\n", sum)
}
