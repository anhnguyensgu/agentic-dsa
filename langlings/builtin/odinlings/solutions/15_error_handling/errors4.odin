// errors4.odin
package main

import "core:strconv"
import "core:testing"

port_or_default :: proc(s: string) -> int {
	return strconv.parse_int(s) or_else 8080
}

nickname :: proc(nicknames: map[string]string, name: string) -> string {
	// A map index has a two-value form, `value, ok := m[key]`, so `or_else`
	// works on it too.
	return nicknames[name] or_else "buddy"
}

main :: proc() {
	// You can optionally experiment here.
}

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
