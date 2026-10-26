// primitives4.odin
//
// `a[low:high]` makes a slice: a pointer and a length that look into `a`
// without copying it. `low` is included, `high` isn't, and either can be left
// out.
package main

import "core:slice"
import "core:testing"

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_slice_out_of_array :: proc(t: ^testing.T) {
	a := [5]int{1, 2, 3, 4, 5}

	// TODO: Get a slice of `a` that holds [2, 3, 4].
	nice_slice := ???

	testing.expect(t, slice.equal(nice_slice, []int{2, 3, 4}))
}
