// bitsets2.odin
//
// A bit set over a range of runes: one bit per lowercase letter.
package main

import "core:testing"

Letters :: bit_set['a' ..= 'z']

letters_in :: proc(s: string) -> Letters {
	set: Letters
	for r in s {
		lower := r + ('a' - 'A') if 'A' <= r && r <= 'Z' else r
		if 'a' <= lower && lower <= 'z' {
			// TODO: Add `lower` to the set.
		}
	}
	return set
}

is_pangram :: proc(s: string) -> bool {
	// TODO: Does `s` use every letter? (`card` counts the members of a set.)
	return false
}

can_type_with :: proc(word, keys: string) -> bool {
	// TODO: Can `word` be typed using only the letters in `keys`? One
	// operator does it.
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_letters_in :: proc(t: ^testing.T) {
	testing.expect_value(t, letters_in("Abba!"), Letters{'a', 'b'})
}

@(test)
test_is_pangram :: proc(t: ^testing.T) {
	testing.expect(t, is_pangram("The quick brown fox jumps over the lazy dog"))
	testing.expect(t, !is_pangram("The quick brown fox"))
}

@(test)
test_can_type_with :: proc(t: ^testing.T) {
	testing.expect(t, can_type_with("deed", "abcdef"))
	testing.expect(t, !can_type_with("odin", "abcdef"))
}
