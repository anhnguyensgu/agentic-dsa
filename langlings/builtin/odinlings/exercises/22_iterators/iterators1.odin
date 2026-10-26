// iterators1.odin
package main

import "core:slice"
import "core:testing"

Countdown :: struct {
	n: int,
}

// Gives n, n-1, ..., 1, and then reports there's nothing left.
countdown_next :: proc(it: ^Countdown) -> (value: int, ok: bool) {
	// TODO
	return
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_countdown :: proc(t: ^testing.T) {
	got: [dynamic; 8]int
	it := Countdown{3}
	for v in countdown_next(&it) {
		append(&got, v)
	}
	testing.expect(t, slice.equal(got[:], []int{3, 2, 1}))
}

@(test)
test_empty_countdown :: proc(t: ^testing.T) {
	it := Countdown{0}
	for _ in countdown_next(&it) {
		testing.fail_now(t, "a countdown from 0 has nothing to give")
	}
}
