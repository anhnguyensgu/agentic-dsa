// switch1.odin
package main

import "core:testing"

char_kind :: proc(c: rune) -> string {
	switch c {
	case 'a' ..= 'z', 'A' ..= 'Z':
		return "letter"
	case '0' ..= '9':
		return "digit"
	case ' ', '\t', '\n':
		return "space"
	case:
		return "other"
	}
}

main :: proc() {
	// You can optionally experiment here.
}

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
