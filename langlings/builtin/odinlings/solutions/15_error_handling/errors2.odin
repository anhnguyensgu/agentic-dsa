// errors2.odin
package main

import "core:strconv"
import "core:testing"

Cost_Error :: enum {
	None,
	Not_A_Number,
}

total_cost :: proc(item_quantity: string) -> (int, Cost_Error) {
	PROCESSING_FEE :: 1
	COST_PER_ITEM :: 5

	qty, ok := strconv.parse_int(item_quantity)
	if !ok {
		return 0, .Not_A_Number
	}

	return qty * COST_PER_ITEM + PROCESSING_FEE, .None
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_item_quantity_is_a_number :: proc(t: ^testing.T) {
	cost, err := total_cost("34")
	testing.expect_value(t, err, Cost_Error.None)
	testing.expect_value(t, cost, 171)
}

@(test)
test_item_quantity_is_not_a_number :: proc(t: ^testing.T) {
	_, err := total_cost("beep boop")
	testing.expect_value(t, err, Cost_Error.Not_A_Number)
}
