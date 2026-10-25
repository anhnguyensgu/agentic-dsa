// strings3.odin
package main

import "core:strings"
import "core:testing"

word_count :: proc(text: string) -> int {
	words := strings.fields(text)
	defer delete(words)
	return len(words)
}

longest_word :: proc(text: string) -> string {
	// Only the slice of words was allocated. Each word is a view into `text`,
	// so returning one after freeing the slice is fine.
	words := strings.fields(text)
	defer delete(words)
	best := ""
	for w in words {
		if len(w) > len(best) {
			best = w
		}
	}
	return best
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_word_count :: proc(t: ^testing.T) {
	testing.expect_value(t, word_count("the quick  brown fox"), 4)
}

@(test)
test_longest_word :: proc(t: ^testing.T) {
	testing.expect_value(t, longest_word("a quick brown fox"), "quick")
}
