// procedures5.odin
package main

import "core:testing"

min_max :: proc(numbers: []int) -> (smallest, largest: int) {
	smallest, largest = numbers[0], numbers[0]
	for n in numbers {
		if n < smallest {
			smallest = n
		}
		if n > largest {
			largest = n
		}
	}
	return
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_min_max :: proc(t: ^testing.T) {
	lo, hi := min_max([]int{3, 9, -2, 7})
	testing.expect_value(t, lo, -2)
	testing.expect_value(t, hi, 9)
}

@(test)
test_single_element :: proc(t: ^testing.T) {
	lo, hi := min_max([]int{4})
	testing.expect_value(t, lo, 4)
	testing.expect_value(t, hi, 4)
}
