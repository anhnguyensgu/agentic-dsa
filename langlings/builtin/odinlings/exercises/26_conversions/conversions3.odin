// conversions3.odin
//
// Parse a person from text like "Mark,20", and format one back without
// allocating.
package main

import "core:strconv"
import "core:strings"
import "core:testing"

Person :: struct {
	name: string,
	age:  int,
}

// ok is false when there's no comma, the name is empty, or the age isn't a
// number. The name may point into `s`.
parse_person :: proc(s: string) -> (p: Person, ok: bool) {
	// TODO
	return
}

// Writes "Mark (20)" into `buf` and returns it as a string.
format_person :: proc(p: Person, buf: []u8) -> string {
	b := strings.builder_from_bytes(buf)
	// TODO: The name, " (", the age, and ")".
	return strings.to_string(b)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_parse_person :: proc(t: ^testing.T) {
	p, ok := parse_person("Mark,20")
	testing.expect(t, ok)
	testing.expect_value(t, p, Person{"Mark", 20})

	_, ok = parse_person("Mark")
	testing.expect(t, !ok)
	_, ok = parse_person(",20")
	testing.expect(t, !ok)
	_, ok = parse_person("Mark,twenty")
	testing.expect(t, !ok)
}

@(test)
test_format_person :: proc(t: ^testing.T) {
	buf: [64]u8
	testing.expect_value(t, format_person(Person{"Ada", 36}, buf[:]), "Ada (36)")
}
