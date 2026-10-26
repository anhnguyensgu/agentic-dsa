// switch1.odin
//
// A case can list several values and ranges: `case 'a'..='z', 'A'..='Z':`.
// `..=` includes the end, `..<` stops before it. Only the matching case runs.
package main

import "core:testing"

char_kind :: proc(c: rune) -> string {
	switch c {
	case 'a' ..= 'z', 'A' ..= 'Z':
		return "letter"
	// TODO: Add a case for "digit" (0 to 9) and one for "space"
	// (' ', '\t' or '\n').
	case:
		return "other"
	}
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_letters :: proc(t: ^testing.T) {
	testing.expect_value(t, char_kind('q'), "letter")
	testing.expect_value(t, char_kind('Q'), "letter")
}

@(test)
test_digits :: proc(t: ^testing.T) {
	testing.expect_value(t, char_kind('0'), "digit")
	testing.expect_value(t, char_kind('9'), "digit")
}

@(test)
test_spaces :: proc(t: ^testing.T) {
	testing.expect_value(t, char_kind(' '), "space")
	testing.expect_value(t, char_kind('\t'), "space")
	testing.expect_value(t, char_kind('\n'), "space")
}

@(test)
test_other :: proc(t: ^testing.T) {
	testing.expect_value(t, char_kind('?'), "other")
	testing.expect_value(t, char_kind('é'), "other")
}
