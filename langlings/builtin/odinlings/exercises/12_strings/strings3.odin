// strings3.odin
//
// The answers here are right, but the tests still fail: these procedures
// leak memory. Read the test output, it says where the leaked memory was
// allocated.
package main

import "core:strings"
import "core:testing"

word_count :: proc(text: string) -> int {
	// `fields` allocates the slice it returns.
	words := strings.fields(text)
	// TODO: Free `words` once you're done with it.
	return len(words)
}

longest_word :: proc(text: string) -> string {
	words := strings.fields(text)
	// TODO: Same here. Is it safe to return one of the words after freeing
	// the slice? (Hint: what memory does each word point into?)
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

// Don't change the tests!

@(test)
test_word_count :: proc(t: ^testing.T) {
	testing.expect_value(t, word_count("the quick  brown fox"), 4)
}

@(test)
test_longest_word :: proc(t: ^testing.T) {
	testing.expect_value(t, longest_word("a quick brown fox"), "quick")
}
