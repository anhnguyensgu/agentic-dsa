// primitives4.odin
package main

import "core:slice"
import "core:testing"

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_slice_out_of_array :: proc(t: ^testing.T) {
	a := [5]int{1, 2, 3, 4, 5}

	// Index 1 up to, but not including, index 4. `a[:]` slices all of it.
	nice_slice := a[1:4]

	testing.expect(t, slice.equal(nice_slice, []int{2, 3, 4}))
}
