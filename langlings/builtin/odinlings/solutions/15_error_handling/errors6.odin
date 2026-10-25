// errors6.odin
package main

import "core:strconv"
import "core:testing"

sum_numbers :: proc(words: []string) -> int {
	total := 0
	for w in words {
		n := strconv.parse_int(w) or_continue
		total += n
	}
	return total
}

sum_leading_numbers :: proc(words: []string) -> int {
	total := 0
	for w in words {
		n := strconv.parse_int(w) or_break
		total += n
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

WORDS :: []string{"10", "20", "3rd", "30", "-5"}

@(test)
test_sum_numbers :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_numbers(WORDS), 55)
}

@(test)
test_sum_leading_numbers :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_leading_numbers(WORDS), 30)
}
