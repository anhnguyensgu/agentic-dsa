// procedures7.odin
package main

import "core:fmt"

sum :: proc(nums: ..int) -> int {
	total := 0
	for n in nums {
		total += n
	}
	return total
}

main :: proc() {
	fmt.println(sum())
	fmt.println(sum(1, 2, 3))

	odds := []int{1, 3, 5}
	// `..` in a call spreads a slice into the variadic parameter.
	fmt.println(sum(..odds))
}
