// errors3.odin
//
// `x := f() or_return` stops the current procedure as soon as `f` reports an
// error, and passes that error up as this procedure's own last result. With
// named results, the other results are returned as they are at that moment.
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
	// TODO: Both errors are thrown away. Pass them on with `or_return`.
	cfg.name, _ = parse_name(name)
	cfg.port, _ = parse_port(port)
	return
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
