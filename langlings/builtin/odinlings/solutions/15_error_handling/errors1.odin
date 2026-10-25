// errors1.odin
package main

import "core:fmt"
import "core:testing"

Nametag_Error :: enum {
	None,
	Empty_Name,
	Too_Long,
}

generate_nametag :: proc(name: string) -> (string, Nametag_Error) {
	if name == "" {
		return "", .Empty_Name
	}
	if len(name) > 20 {
		return "", .Too_Long
	}
	return fmt.tprintf("Hi! My name is %s", name), .None
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_valid_name :: proc(t: ^testing.T) {
	tag, err := generate_nametag("Ada")
	testing.expect_value(t, err, Nametag_Error.None)
	testing.expect_value(t, tag, "Hi! My name is Ada")
}

@(test)
test_empty_name :: proc(t: ^testing.T) {
	_, err := generate_nametag("")
	testing.expect_value(t, err, Nametag_Error.Empty_Name)
}

@(test)
test_long_name :: proc(t: ^testing.T) {
	_, err := generate_nametag("Wolfeschlegelsteinhausenbergerdorff")
	testing.expect_value(t, err, Nametag_Error.Too_Long)
}
