// bitsets2.odin
package main

import "core:testing"

Letters :: bit_set['a' ..= 'z']

letters_in :: proc(s: string) -> Letters {
	set: Letters
	for r in s {
		lower := r + ('a' - 'A') if 'A' <= r && r <= 'Z' else r
		if 'a' <= lower && lower <= 'z' {
			set += {lower}
		}
	}
	return set
}

is_pangram :: proc(s: string) -> bool {
	// Comparing with the full set, `~Letters{}`, works too.
	return card(letters_in(s)) == 26
}

can_type_with :: proc(word, keys: string) -> bool {
	// `<=` on bit sets is "is a subset of".
	return letters_in(word) <= letters_in(keys)
}

main :: proc() {
	// You can optionally experiment here.
}

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
