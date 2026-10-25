// procedures7.odin
//
// `..int` makes a variadic parameter: callers pass any number of ints, and the
// procedure sees them as a slice, `[]int`.
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
	// TODO: Pass the elements of `odds` as the variadic arguments.
	fmt.println(sum(odds))
}
