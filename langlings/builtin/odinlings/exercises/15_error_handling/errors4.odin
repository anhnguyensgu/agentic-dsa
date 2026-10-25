// errors4.odin
//
// `value := f() or_else fallback` gives you the value on success and the
// fallback on failure, in one expression.
package main

import "core:strconv"
import "core:testing"

port_or_default :: proc(s: string) -> int {
	// TODO: Parse `s`, falling back to 8080 when it isn't a number.
	return ???
}

nickname :: proc(nicknames: map[string]string, name: string) -> string {
	// TODO: The nickname for `name`, or "buddy" if there isn't one.
	return ???
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_port_or_default :: proc(t: ^testing.T) {
	testing.expect_value(t, port_or_default("3000"), 3000)
	testing.expect_value(t, port_or_default("http"), 8080)
}

@(test)
test_nickname :: proc(t: ^testing.T) {
	nicknames := make(map[string]string)
	defer delete(nicknames)
	nicknames["Robert"] = "Bob"

	testing.expect_value(t, nickname(nicknames, "Robert"), "Bob")
	testing.expect_value(t, nickname(nicknames, "Alice"), "buddy")
}
