// primitives2.odin
package main

import "core:testing"

initial :: proc(name: string) -> rune {
	// For non-ASCII text you'd decode the first rune instead, e.g. with
	// `for r in name { return r }` or `utf8.decode_rune_in_string`.
	return rune(name[0])
}

to_upper_ascii :: proc(c: rune) -> rune {
	if 'a' <= c && c <= 'z' {
		return c - 'a' + 'A'
	}
	return c
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_initial :: proc(t: ^testing.T) {
	testing.expect_value(t, initial("Ada"), 'A')
	testing.expect_value(t, initial("ginger"), 'g')
}

@(test)
test_to_upper_ascii :: proc(t: ^testing.T) {
	testing.expect_value(t, to_upper_ascii('a'), 'A')
	testing.expect_value(t, to_upper_ascii('q'), 'Q')
	testing.expect_value(t, to_upper_ascii('Q'), 'Q')
	testing.expect_value(t, to_upper_ascii('7'), '7')
}
