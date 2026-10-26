// quiz1.odin
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
	for event, i in events {
		switch e in event {
		case Restock:
			stock[e.item] += e.qty
		case Sell:
			// A missing item reads as 0, which is never enough to sell.
			if stock[e.item] < e.qty {
				append(&failed, i)
			} else {
				stock[e.item] -= e.qty
			}
		}
	}
	return
}

low_stock :: proc(stock: map[string]int, threshold: int) -> []string {
	low: [dynamic]string
	for item, qty in stock {
		if qty <= threshold {
			append(&low, item)
		}
	}
	// A dynamic array's memory can be handed over as a plain slice; the
	// caller frees it with `delete` either way.
	return low[:]
}

main :: proc() {
	// You can optionally experiment here.
}

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
