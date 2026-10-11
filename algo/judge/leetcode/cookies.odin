package leetcode

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:net"
import "core:strings"
import judge ".."

// Decoded strings live in the command arena. Duplicate fields are processed
// in order, so the last value wins, including a later complete cookie jar.
extract_cookies :: proc(query: string) -> (cfg: Config, err: Error) {
	remaining := query
	for pair in strings.split_by_byte_iterator(&remaining, '&') {
		key, encoded := judge.split_once(pair, "=")
		switch key {
		case "cookie", "LEETCODE_SESSION", "leetcode_session", "session",
		     "csrftoken", "csrf", "csrf_token", "csrfToken":
		case:
			continue
		}

		value, ok := net.percent_decode(encoded)
		if !ok {
			fmt.eprintln("invalid percent encoding in callback")
			return {}, .Callback_Failed
		}
		switch key {
		case "cookie":
			cfg = parse_cookie_jar(value)
		case "LEETCODE_SESSION", "leetcode_session", "session":
			cfg.leetcode_session = value
		case "csrftoken", "csrf", "csrf_token", "csrfToken":
			cfg.csrf_token = value
		}
	}
	if !valid_credentials(cfg) {
		fmt.eprintln("missing or invalid session cookie in callback")
		return {}, .Callback_Failed
	}
	return cfg, nil
}

// No allocations: the fields borrow s. Values may contain '=' (e.g. padding).
parse_cookie_jar :: proc(s: string) -> (cfg: Config) {
	remaining := s
	for part in strings.split_by_byte_iterator(&remaining, ';') {
		name, value := judge.split_once(strings.trim_space(part), "=")
		switch strings.trim_space(name) {
		case "LEETCODE_SESSION": cfg.leetcode_session = strings.trim_space(value)
		case "csrftoken":        cfg.csrf_token = strings.trim_space(value)
		}
	}
	return
}

// Accept a cookie jar or a raw session token, but never turn a known empty
// cookie or a csrf-only jar into a purported session token.
parse_pasted_config :: proc(input: string) -> (cfg: Config, err: Error) {
	line := strings.trim_space(input)
	cfg = parse_cookie_jar(line)
	if cfg.leetcode_session == "" {
		name, _ := judge.split_once(line, "=")
		if strings.contains(line, ";") || strings.trim_space(name) == "LEETCODE_SESSION" ||
		   strings.trim_space(name) == "csrftoken" {
			return {}, .No_Input
		}
		cfg.leetcode_session = line
	}
	if !valid_credentials(cfg) {
		return {}, .No_Input
	}
	return cfg, nil
}

valid_credentials :: proc(cfg: Config) -> bool {
	return cfg.leetcode_session != "" && valid_cookie_value(cfg.leetcode_session) && valid_cookie_value(cfg.csrf_token)
}

// RFC 6265 cookie-octet characters; also excludes CR/LF header injection.
valid_cookie_value :: proc(value: string) -> bool {
	for ch in value {
		if ch <= ' ' || ch >= 0x7f || ch == '"' || ch == ',' || ch == ';' || ch == '\\' {
			return false
		}
	}
	return true
}

// The trimmed result borrows command-arena storage, not the Reader's buffer.
read_input_line :: proc(input: io.Stream) -> (line: string, err: Error) {
	r: bufio.Reader
	bufio.reader_init(&r, input)
	defer bufio.reader_destroy(&r)

	text, read_err := bufio.reader_read_string(&r, '\n')
	if read_err != nil && read_err != .EOF {
		return "", .No_Input
	}
	line = strings.trim_space(text)
	if line == "" {
		return "", .No_Input
	}
	return line, nil
}
