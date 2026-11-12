// LeetCode 322. Coin Change -- bottom-up DP, accumulator form with four
// independent accumulators.
//
// Same as coin_change_acc.odin except that the reduction over coins is unrolled
// by four, each lane keeping its own running minimum, combined once at the
// end. A single accumulator makes every min wait for the previous one; four
// accumulators let the CPU work on four candidates at the same time.
//
// Idiomatic Odin throughout: the table comes from `make` on context.allocator
// (Odin's default heap allocator), arguments from core:os and core:strconv,
// output through core:fmt. Nothing calls libc directly.
package main

import "core:fmt"
import "core:os"
import "core:strconv"

relax :: #force_inline proc(dp: []u32, a: uint, coin: u32, best: u32) -> u32 {
	c := uint(coin)
	if c <= a {
		v := dp[a - c] + 1
		if v < best {
			return v
		}
	}
	return best
}

@(link_name = "coin_change")
coin_change :: proc(coins: []u32, amount: uint) -> i32 {
	inf := u32(amount) + 1
	size := amount + 1
	dp := make([]u32, size)
	defer delete(dp)
	for i in 0 ..< size {
		dp[i] = inf
	}
	dp[0] = 0
	n := uint(len(coins))
	for a := uint(1); a < size; a += 1 {
		b0, b1, b2, b3 := inf, inf, inf, inf
		i: uint = 0
		for ; i + 4 <= n; i += 4 {
			b0 = relax(dp, a, coins[i], b0)
			b1 = relax(dp, a, coins[i + 1], b1)
			b2 = relax(dp, a, coins[i + 2], b2)
			b3 = relax(dp, a, coins[i + 3], b3)
		}
		for ; i < n; i += 1 {
			b0 = relax(dp, a, coins[i], b0)
		}
		dp[a] = min(min(b0, b1), min(b2, b3))
	}
	result := dp[amount]
	return -1 if uint(result) > amount else i32(result)
}

// usage: coin_change <reps> <amount> <coin>...
main :: proc() {
	args := os.args
	if len(args) < 4 {
		os.exit(2)
	}
	reps, _ := strconv.parse_uint(args[1], 10)
	amount, _ := strconv.parse_uint(args[2], 10)
	coins := make([]u32, len(args) - 3)
	defer delete(coins)
	for arg, i in args[3:] {
		value, _ := strconv.parse_uint(arg, 10)
		coins[i] = u32(value)
	}

	sum: i64 = 0
	for r in 0 ..< reps {
		d := r & 7
		amt := amount if d > amount else amount - d
		sum += i64(#force_no_inline coin_change(coins, amt))
	}
	fmt.println(sum)
}
