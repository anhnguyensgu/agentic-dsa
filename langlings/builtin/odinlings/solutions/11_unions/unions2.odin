// unions2.odin
package main

import "core:testing"

Value :: union {
	int,
	string,
	bool,
}

as_int :: proc(v: Value) -> (n: int, ok: bool) {
	// On failure, `n` is the zero value and `ok` is false.
	n, ok = v.(int)
	return
}

main :: proc() {
	// You can optionally experiment here.
}

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
