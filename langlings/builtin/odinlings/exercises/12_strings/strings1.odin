// strings1.odin
//
// None of these need to allocate: each answer is a view into the input.
package main

import "core:strings"
import "core:testing"

clean :: proc(s: string) -> string {
	// TODO: Remove whitespace from both ends.
	return s
}

is_greeting :: proc(s: string) -> bool {
	// TODO: True when `s` starts with "Hellope".
	return false
}

file_extension :: proc(path: string) -> string {
	// TODO: Everything after the last '.', or "" if there's no '.'.
	// `strings.last_index_byte` returns -1 when it finds nothing.
	return ""
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_clean :: proc(t: ^testing.T) {
	testing.expect_value(t, clean("  odin \n"), "odin")
	testing.expect_value(t, clean("odin"), "odin")
}

@(test)
test_is_greeting :: proc(t: ^testing.T) {
	testing.expect(t, is_greeting("Hellope, world!"))
	testing.expect(t, !is_greeting("Hello, world!"))
}

@(test)
test_file_extension :: proc(t: ^testing.T) {
	testing.expect_value(t, file_extension("notes.txt"), "txt")
	testing.expect_value(t, file_extension("archive.tar.gz"), "gz")
	testing.expect_value(t, file_extension("Makefile"), "")
}
