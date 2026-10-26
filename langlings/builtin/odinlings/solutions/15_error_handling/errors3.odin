// errors3.odin
package main

import "core:strconv"
import "core:testing"

Config_Error :: enum {
	None,
	Missing_Name,
	Bad_Port,
	Port_Out_Of_Range,
}

Config :: struct {
	name: string,
	port: int,
}

parse_name :: proc(s: string) -> (string, Config_Error) {
	if s == "" {
		return "", .Missing_Name
	}
	return s, .None
}

parse_port :: proc(s: string) -> (int, Config_Error) {
	n, ok := strconv.parse_int(s)
	if !ok {
		return 0, .Bad_Port
	}
	if n < 1 || n > 65535 {
		return 0, .Port_Out_Of_Range
	}
	return n, .None
}

parse_config :: proc(name, port: string) -> (cfg: Config, err: Config_Error) {
	// Each line is short for:
	//     n, e := parse_name(name)
	//     if e != .None { err = e; return }
	//     cfg.name = n
	cfg.name = parse_name(name) or_return
	cfg.port = parse_port(port) or_return
	return
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_valid_config :: proc(t: ^testing.T) {
	cfg, err := parse_config("web", "8080")
	testing.expect_value(t, err, Config_Error.None)
	testing.expect_value(t, cfg, Config{"web", 8080})
}

@(test)
test_errors_are_passed_up :: proc(t: ^testing.T) {
	_, err := parse_config("", "8080")
	testing.expect_value(t, err, Config_Error.Missing_Name)

	_, err = parse_config("web", "eighty")
	testing.expect_value(t, err, Config_Error.Bad_Port)

	_, err = parse_config("web", "70000")
	testing.expect_value(t, err, Config_Error.Port_Out_Of_Range)
}
