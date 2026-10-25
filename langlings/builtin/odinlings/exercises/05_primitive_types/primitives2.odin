// primitives2.odin
//
// A `rune` is a Unicode code point. Indexing a string gives a single byte, a
// `u8`, which is a different type.
package main

import "core:testing"

initial :: proc(name: string) -> rune {
	// TODO: `name[0]` is a `u8`. Convert it. (Fine for ASCII names.)
	return name[0]
}

// Runes are numbers, so you can do arithmetic on them.
to_upper_ascii :: proc(c: rune) -> rune {
	if 'a' <= c && c <= 'z' {
		// TODO: Turn 'a'..'z' into 'A'..'Z'.
		return c
	}
	return c
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
