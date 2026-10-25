// unions2.odin
package main

import "core:testing"

Value :: union {
	int,
	string,
	bool,
}

as_int :: proc(v: Value) -> (n: int, ok: bool) {
	// TODO: This assertion panics when `v` holds anything but an int. Use the
	// form that reports success instead of panicking.
	return v.(int), true
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_holds_int :: proc(t: ^testing.T) {
	n, ok := as_int(42)
	testing.expect(t, ok)
	testing.expect_value(t, n, 42)
}

@(test)
test_holds_something_else :: proc(t: ^testing.T) {
	_, ok := as_int("forty-two")
	testing.expect(t, !ok)

	_, ok = as_int(nil)
	testing.expect(t, !ok)
}
