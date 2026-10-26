// memory1.odin
//
// Returning allocated memory hands ownership to the caller. Exactly one side
// should free it, and only after the last use.
package main

import "core:strings"
import "core:testing"

make_greeting :: proc(name: string) -> string {
	s := strings.concatenate({"Hellope, ", name, "!"})
	// TODO: This frees the string before the caller gets to use it, and then
	// the caller frees it a second time.
	defer delete(s)
	return s
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_make_greeting :: proc(t: ^testing.T) {
	greeting := make_greeting("Ada")
	defer delete(greeting)
	testing.expect_value(t, greeting, "Hellope, Ada!")
}
