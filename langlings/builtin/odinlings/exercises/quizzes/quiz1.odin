// quiz1.odin
//
// A small shop keeps its stock in a map from item name to quantity. Write
// `apply_events`, which runs restocks and sales against the stock, and
// `low_stock`, which lists the items that are running out.
//
// Rules:
// - A `Restock` adds `qty` of `item`, creating the item if it's new.
// - A `Sell` takes `qty` away, but only if there's enough. A sale that can't
//   be filled changes nothing (it doesn't even create the item) and its index
//   in `events` goes into the returned list of failures.
// - `low_stock` returns the items with `qty <= threshold`, in any order.
//
// The caller owns both returned arrays.
package main

import "core:slice"
import "core:testing"

Restock :: struct {
	item: string,
	qty:  int,
}

Sell :: struct {
	item: string,
	qty:  int,
}

Event :: union {
	Restock,
	Sell,
}

apply_events :: proc(stock: ^map[string]int, events: []Event) -> (failed: [dynamic]int) {
	// TODO
	return
}

low_stock :: proc(stock: map[string]int, threshold: int) -> []string {
	// TODO
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

EVENTS :: []Event {
	Restock{"pear", 2},
	Sell{"apple", 3},
	Sell{"apple", 3},
	Sell{"kiwi", 1},
	Restock{"apple", 1},
}

@(test)
test_apply_events :: proc(t: ^testing.T) {
	stock := make(map[string]int)
	defer delete(stock)
	stock["apple"] = 5

	failed := apply_events(&stock, EVENTS)
	defer delete(failed)

	testing.expect_value(t, stock["apple"], 3)
	testing.expect_value(t, stock["pear"], 2)
	testing.expect(t, "kiwi" not_in stock)
	testing.expect(t, slice.equal(failed[:], []int{2, 3}))
}

@(test)
test_low_stock :: proc(t: ^testing.T) {
	stock := make(map[string]int)
	defer delete(stock)
	stock["apple"] = 3
	stock["pear"] = 2
	stock["fig"] = 0

	low := low_stock(stock, 2)
	defer delete(low)
	slice.sort(low)

	testing.expect(t, slice.equal(low, []string{"fig", "pear"}))
}
