// leetcode-odin: terminal problem solving and local Odin practice.
//
// See USAGE and README.md for the complete command surface. Credentials live
// at ~/.config/leetcode-odin/config.json (mode 0600).
//
// Errors propagate with `or_return`; details are printed at the failure site
// and run prints the summary. All command allocations live in run's arena:
// returned strings and Config fields are views into it and must not outlive
// the command.
package main

import "core:fmt"
import "core:mem/virtual"
import "core:net"
import "core:os"

VERSION :: "leetcode-odin 0.2.0"

CAPABILITIES :: `{"schema_version":1,"provider":"leetcode","version":"` + VERSION + `","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"remote_odin":false,"reason":"LeetCode does not judge Odin"}}`

// A single error enum needs no wrapper union: its zero value is nil.
Error :: enum {
	None,
	No_Input,        // nothing usable on stdin or in a file
	Callback_Failed, // loopback server / browser callback failed
	Verify_Failed,   // could not reach or parse leetcode.com
	Not_Signed_In,   // leetcode.com rejected the session
	Config_Path,     // cannot resolve the credentials location
	Config_Read,     // missing, corrupt, or empty credentials
	Config_Write,    // could not persist credentials
	Config_Delete,   // could not remove credentials
	Usage,
	Network,
	API,
	Not_Found,
	File,
	Unsupported,
	Judge_Failed,
	Timeout,
	Output_Limit,
	Offline,
	Unchecked,
}

ERROR_MESSAGES := [Error]string {
	.None            = "",
	.No_Input        = "no input",
	.Callback_Failed = "login failed; you can try `leetcode paste` instead",
	.Verify_Failed   = "could not verify session (see details above)",
	.Not_Signed_In   = "leetcode.com reports you are NOT signed in; the session is likely expired",
	.Config_Path     = "could not resolve credentials location; check your home directory",
	.Config_Read     = "no usable credentials; run `leetcode auth` or `leetcode paste` first",
	.Config_Write    = "failed to save credentials (see details above)",
	.Config_Delete   = "failed to remove credentials (see details above)",
	.Usage           = "invalid arguments; use `leetcode help`",
	.Network         = "request failed; check the network and curl installation",
	.API             = "unexpected LeetCode response (the service may have changed)",
	.Not_Found       = "problem or requested data was not found",
	.File            = "could not read or write the requested file",
	.Unsupported     = "unsupported operation (see details above)",
	.Judge_Failed    = "solution did not pass",
	.Timeout         = "time limit reached",
	.Output_Limit    = "process output exceeded the 256 KiB limit",
	.Offline         = "data is not cached; fetch it once while online",
	.Unchecked       = "some local cases have no expected result; edit cases.json and set check=true",
}

// Documented exit codes: 0 success, 1 operational error, 2 usage, 3 failed
// solution, 4 local cases without expected results.
exit_code :: proc(err: Error) -> int {
	#partial switch err {
	case .None:         return 0
	case .Usage:        return 2
	case .Judge_Failed: return 3
	case .Unchecked:    return 4
	}
	return 1
}

main :: proc() {
	// run returns before exit so its deferred cleanup runs on failure too.
	if code := run(os.args[1:]); code != 0 {
		os.exit(code)
	}
}

run :: proc(args: []string) -> int {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("leetcode: out of memory")
		return 1
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)
	context.temp_allocator = context.allocator

	if len(args) == 0 {
		fmt.println(USAGE)
		return exit_code(.Usage)
	}
	opts, err := parse_options(args)
	if err == nil {
		err = execute(opts)
	}
	if err != nil {
		fmt.eprintln(ERROR_MESSAGES[err])
	}
	return exit_code(err)
}

execute :: proc(o: Options) -> Error {
	switch o.command {
	case .Help:
		fmt.println(USAGE)
	case .Version:
		fmt.println(VERSION)
	case .Capabilities:
		fmt.println(CAPABILITIES)
	case .Auth:
		return cmd_auth(o.positionals[:])
	case .Paste:
		return cmd_paste()
	case .Status:
		return cmd_status(o.json)
	case .Logout:
		return cmd_logout()
	case .List:
		return cmd_list(o)
	case .Show, .Daily, .Random, .Languages, .Open, .Pick:
		return cmd_problem(o)
	case .Test:
		return cmd_local_test(o)
	case .Run, .Submit, .Run_Start, .Submit_Start, .Check:
		return cmd_judge(o)
	case .Submissions, .Submission, .Stats:
		return cmd_account(o)
	}
	return nil
}

cmd_auth :: proc(overrides: []string) -> Error {
	// Optional overrides let authorize-url variants be tried without
	// recompiling: leetcode auth <protocol> <path>
	protocol := overrides[0] if len(overrides) >= 1 else "http"
	callback := overrides[1] if len(overrides) >= 2 else fmt.tprintf("%s:%d", CALLBACK_HOST, CALLBACK_PORT)

	fmt.println("== LeetCode browser login ==")
	fmt.printf("Starting local callback server on %s:%d ...\n", CALLBACK_HOST, CALLBACK_PORT)
	url := fmt.tprintf("https://leetcode.com/authorize-login/%s/?path=%s", protocol, net.percent_encode(callback))
	cfg := capture_callback(url) or_return
	return verify_and_save(cfg)
}

cmd_paste :: proc() -> Error {
	fmt.println("== LeetCode cookie paste login ==")
	fmt.println("Paste the cookie line copied from browser DevTools (then press Enter).")
	fmt.println("Accepted forms:")
	fmt.println("  LEETCODE_SESSION=<value>; csrftoken=<value>")
	fmt.println("  <LEETCODE_SESSION value only>")
	fmt.print("> ")

	line := read_input_line(os.to_stream(os.stdin)) or_return
	cfg := parse_pasted_config(line) or_return
	return verify_and_save(cfg)
}

cmd_status :: proc(as_json: bool) -> Error {
	path := config_path() or_return
	cfg := load_config(path) or_return
	if !as_json {
		return finish_sign_in(cfg)
	}
	status := verify_credentials(cfg) or_return
	print_json(status)
	return nil if status.signed_in else .Not_Signed_In
}

cmd_logout :: proc() -> Error {
	path := config_path() or_return
	return remove_config(path)
}

// Credentials that do not verify are never written to disk.
verify_and_save :: proc(cfg: Config) -> Error {
	path := config_path() or_return
	finish_sign_in(cfg) or_return
	save_config(cfg, path) or_return
	fmt.println("credentials saved to", path)
	return nil
}

finish_sign_in :: proc(cfg: Config) -> Error {
	fmt.println("verifying session with leetcode.com ...")
	status := verify_credentials(cfg) or_return
	if !status.signed_in {
		return .Not_Signed_In
	}
	fmt.printf("Signed in as %s (premium: %v)\n", status.username, status.premium)
	return nil
}
