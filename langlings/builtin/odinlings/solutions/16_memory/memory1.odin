// memory1.odin
package main

import "core:strings"
import "core:testing"

// The caller owns the result. A comment like this, or an `allocator`
// parameter, is how Odin code usually says so.
make_greeting :: proc(name: string) -> string {
	return strings.concatenate({"Hellope, ", name, "!"})
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_make_greeting :: proc(t: ^testing.T) {
	greeting := make_greeting("Ada")
	defer delete(greeting)
	testing.expect_value(t, greeting, "Hellope, Ada!")
}
