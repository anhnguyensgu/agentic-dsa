// conversions3.odin
package main

import "core:strconv"
import "core:strings"
import "core:testing"

Person :: struct {
	name: string,
	age:  int,
}

parse_person :: proc(s: string) -> (p: Person, ok: bool) {
	comma := strings.index_byte(s, ',')
	if comma <= 0 {
		// -1: no comma at all. 0: the name before it is empty.
		return {}, false
	}
	p.name = s[:comma]
	p.age = strconv.parse_int(s[comma + 1:]) or_return
	return p, true
}

format_person :: proc(p: Person, buf: []u8) -> string {
	// A builder over a fixed buffer stops writing when the buffer is full,
	// instead of allocating more.
	b := strings.builder_from_bytes(buf)
	strings.write_string(&b, p.name)
	strings.write_string(&b, " (")
	strings.write_int(&b, p.age)
	strings.write_string(&b, ")")
	return strings.to_string(b)
}

main :: proc() {
	// You can optionally experiment here.
}

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
