// errors2.odin
//
// Items cost 5 each, plus a processing fee of 1, and the quantity arrives as
// text typed by a customer.
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

	// TODO: `parse_int` also says whether it worked, and that is being thrown
	// away. Report `.Not_A_Number` when parsing fails.
	qty, _ := strconv.parse_int(item_quantity)

	return qty * COST_PER_ITEM + PROCESSING_FEE, .None
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
