// LeetCode 322. Coin Change -- bottom-up DP, accumulator form.
//
// Same as coin_change.odin with the loops swapped: for each amount, reduce over
// the coins into one accumulator (`best`) held in a register, then store once.
// The table is written once per amount instead of once per (coin, amount).
//
// Idiomatic Odin throughout: the table comes from `make` on context.allocator
// (Odin's default heap allocator), arguments from core:os and core:strconv,
// output through core:fmt. Nothing calls libc directly.
package main

import "core:fmt"
import "core:os"
import "core:strconv"

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
	for a := uint(1); a < size; a += 1 {
		best := inf
		for coin in coins {
			c := uint(coin)
			if c <= a {
				v := dp[a - c] + 1
				if v < best {
					best = v
				}
			}
		}
		dp[a] = best
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
