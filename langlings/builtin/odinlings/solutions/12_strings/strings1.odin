// strings1.odin
package main

import "core:strings"
import "core:testing"

clean :: proc(s: string) -> string {
	return strings.trim_space(s)
}

is_greeting :: proc(s: string) -> bool {
	return strings.has_prefix(s, "Hellope")
}

file_extension :: proc(path: string) -> string {
	dot := strings.last_index_byte(path, '.')
	if dot < 0 {
		return ""
	}
	return path[dot + 1:]
}

main :: proc() {
	// You can optionally experiment here.
}

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
