package leetcode

import "core:mem"
import "core:strings"
import "core:testing"

@(test)
cookie_jar_borrows_values :: proc(t: ^testing.T) {
	input := "other=ignored; LEETCODE_SESSION = first==; csrftoken=csrf; LEETCODE_SESSION=last+=="
	cfg := parse_cookie_jar(input)
	testing.expect_value(t, cfg.leetcode_session, "last+==")
	testing.expect_value(t, cfg.csrf_token, "csrf")
	start := uintptr(raw_data(input))
	value := uintptr(raw_data(cfg.leetcode_session))
	testing.expect(t, value >= start && value < start + uintptr(len(input)))
	testing.expect_value(t, parse_cookie_jar("unknown=value"), Config{})
}

@(test)
pasted_credentials :: proc(t: ^testing.T) {
	cases := []struct {
		input, session, csrf: string,
	} {
		{"  raw+token==  ", "raw+token==", ""},
		{"LEETCODE_SESSION=s; csrftoken=c", "s", "c"},
		{"LEETCODE_SESSION = s ; csrftoken = c", "s", "c"},
		{"LEETCODE_SESSION=s", "s", ""},
	}
	for c in cases {
		cfg, err := parse_pasted_config(c.input)
		testing.expect_value(t, err, Error.None)
		testing.expect_value(t, cfg.leetcode_session, c.session)
		testing.expect_value(t, cfg.csrf_token, c.csrf)
	}
	invalid := []string {
		"",
		" \t\r\n",
		"LEETCODE_SESSION=",
		"csrftoken=c",
		"other=x; csrftoken=c",
		"bad\r\nHeader:value",
	}
	for input in invalid {
		_, err := parse_pasted_config(input)
		testing.expectf(t, err == .No_Input, "expected No_Input for %q, got %v", input, err)
	}
}

@(test)
callback_cookie_decoding :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	cases := []struct {
		query, session, csrf: string,
	} {
		{"cookie=LEETCODE_SESSION%3Ds%3B%20csrftoken%3Dc", "s", "c"},
		{"LEETCODE_SESSION=s%2B%3D%3D&csrftoken=c", "s+==", "c"},
		{"session=literal+plus", "literal+plus", ""},
		{"leetcode_session=s&csrfToken=c", "s", "c"},
		{"session=old&session=new&csrf=old&csrf_token=new", "new", "new"},
		{"cookie=LEETCODE_SESSION%3Dold%3Bcsrftoken%3Dc&session=new", "new", "c"},
		{"session=old&csrf=c&cookie=LEETCODE_SESSION%3Dnew", "new", ""},
		{"unused=%ZZ&session=s", "s", ""},
	}
	for c in cases {
		cfg, err := extract_cookies(c.query)
		testing.expect_value(t, err, Error.None)
		testing.expect_value(t, cfg.leetcode_session, c.session)
		testing.expect_value(t, cfg.csrf_token, c.csrf)
	}
	invalid := []string {
		"",
		"csrf=c",
		"session=",
		"session=%",
		"session=%ZZ",
		"session=%0d%0aX:y",
		"session=%00",
		"session=s&csrf=%0A",
	}
	for query in invalid {
		cfg, err := extract_cookies(query)
		testing.expect_value(t, err, Error.Callback_Failed)
		testing.expect_value(t, cfg, Config{})
	}
}

@(test)
input_line_handles_whitespace_and_eof :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	cases := []struct {
		input, expected: string,
		err:             Error,
	} {
		{"", "", .No_Input},
		{" \t\r\n", "", .No_Input},
		{" token \r\n", "token", .None},
		{"token-without-newline", "token-without-newline", .None},
		{"first\nsecond\n", "first", .None},
	}
	for c in cases {
		reader: strings.Reader
		strings.reader_init(&reader, c.input)
		line, err := read_input_line(strings.reader_to_stream(&reader))
		testing.expect_value(t, err, c.err)
		testing.expect_value(t, line, c.expected)
	}
}
