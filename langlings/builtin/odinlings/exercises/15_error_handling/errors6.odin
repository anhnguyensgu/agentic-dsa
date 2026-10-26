// errors6.odin
//
// `or_continue` and `or_break` work like `or_return`, but inside a loop: on
// failure they skip to the next iteration or leave the loop.
package main

import "core:strconv"
import "core:testing"

sum_numbers :: proc(words: []string) -> int {
	total := 0
	for w in words {
		// TODO: Skip words that aren't numbers, using `or_continue`.
		n, _ := strconv.parse_int(w)
		total += n
	}
	return total
}

sum_leading_numbers :: proc(words: []string) -> int {
	total := 0
	for w in words {
		// TODO: Stop at the first word that isn't a number, using `or_break`.
		n, _ := strconv.parse_int(w)
		total += n
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

WORDS :: []string{"10", "20", "3rd", "30", "-5"}

@(test)
test_sum_numbers :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_numbers(WORDS), 55)
}

@(test)
test_sum_leading_numbers :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_leading_numbers(WORDS), 30)
}
