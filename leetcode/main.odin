// leetcode-odin: terminal problem solving and local Odin practice.
//
// See print_usage and README.md for the complete command surface.
//
// Config lives at ~/.config/leetcode-odin/config.json (mode 0600).
//
// Errors propagate with `or_return`; diagnostics stay at the failure site.
// All command allocations live in run's arena. Returned strings and Config
// fields are views into that storage and must not outlive the command.
package main

import "core:fmt"
import "core:mem"
import "core:net"
import "core:os"

VERSION :: "leetcode-odin 0.2.0"

Error :: enum {
	None, // nil / success; real errors must have nonzero values
	No_Input, // paste: nothing (usable) on stdin
	Callback_Failed, // loopback server / browser callback failed
	Verify_Failed, // could not reach or parse leetcode.com
	Not_Signed_In, // leetcode.com rejected the session
	Config_Path, // cannot resolve the credentials location
	Config_Read, // missing, corrupt, or empty credentials
	Config_Write, // could not persist credentials
	Config_Delete, // could not remove credentials
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

// A single error enum needs no wrapper union. Odin treats its zero as nil.
error_message :: proc(err: Error) -> string {
	switch err {
	case .None:
		return ""
	case .No_Input:
		return "no input"
	case .Callback_Failed:
		return "login failed; you can try `leetcode paste` instead"
	case .Verify_Failed:
		return "could not verify session (see details above)"
	case .Not_Signed_In:
		return "leetcode.com reports you are NOT signed in; the session is likely expired"
	case .Config_Path:
		return "could not resolve credentials location; check your home directory"
	case .Config_Read:
		return "no usable credentials; run `leetcode auth` or `leetcode paste` first"
	case .Config_Write:
		return "failed to save credentials (see details above)"
	case .Config_Delete:
		return "failed to remove credentials (see details above)"
	case .Usage: return "invalid arguments; use `leetcode help`"
	case .Network: return "request failed; check the network and curl installation"
	case .API: return "unexpected LeetCode response (the service may have changed)"
	case .Not_Found: return "problem or requested data was not found"
	case .File: return "could not read or write the requested file"
	case .Unsupported: return "unsupported operation (see details above)"
	case .Judge_Failed: return "solution did not pass"
	case .Timeout: return "time limit reached"
	case .Output_Limit: return "process output exceeded the 256 KiB limit"
	case .Offline: return "data is not cached; fetch it once while online"
	case .Unchecked: return "some local cases have no expected result; edit cases.json and set check=true"
	}
	return "unknown error"
}

main :: proc() {
	// run returns before exit so its deferred cleanup runs on failure too.
	if code := run(os.args[1:]); code != 0 {
		os.exit(code)
	}
}

run :: proc(args: []string) -> int {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	context.temp_allocator = context.allocator

	if len(args) == 0 {
		print_usage()
		return 2
	}

	opts, parse_err := parse_options(args)
	if parse_err != nil { fmt.eprintln(error_message(parse_err)); return 2 }
	err: Error
	switch opts.command {
	case "help", "--help", "-h":
		print_usage()
	case "version", "--version":
		fmt.println(VERSION)
	case "capabilities":
		fmt.println(`{"schema_version":1,"provider":"leetcode","version":"leetcode-odin 0.2.0","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"remote_odin":false,"reason":"LeetCode does not judge Odin"}}`)
	case "auth":
		err = cmd_auth(opts.positionals[:])
	case "paste":
		err = cmd_paste()
	case "status":
		err = cmd_status(opts.json)
	case "logout":
		err = cmd_logout()
	case:
		err = dispatch(opts)
	}

	if err != nil {
		fmt.eprintln(error_message(err))
		if err == .Usage { return 2 }
		if err == .Judge_Failed { return 3 }
		if err == .Unchecked { return 4 }
		return 1
	}
	return 0
}

print_usage :: proc() {
	fmt.println(
		`usage: leetcode <command> [arguments] [options]

  auth [protocol path]             browser login with local callback
  paste | status | logout          cookie login, verify, remove credentials
  capabilities                     machine-readable provider capabilities
  list [search]                    browse/search problems
  show <id|slug|url>               problem description and examples
  daily | random                  pick a problem
  languages <problem>             available starter languages
  open <problem>                  open problem in the browser
  pick <problem> [--lang odin]     create a solution workspace
  test <directory>                compile and run local Odin cases
  run <problem> <file>            run code on LeetCode examples
  submit <problem> <file>         submit code to LeetCode's judge
  run-start/submit-start <problem> <file>
                                  create a job and return without polling
  check <submission-id>           wait for an existing judge result
  submissions <problem>          your submission history
  submission <submission-id>      submission details and code
  stats [username]                solved counts and ranking

  --json                         machine-readable output (data commands)
  --offline                      use cached public data only
  --refresh                      refresh cached problem data
  --workspace <path>             workspace/cache root (default: ./problems)
  --lang <slug>                  starter/submission language
  --dir <path>                   destination directory for pick
  --input <file>                 remote-run testcase input file
  --timeout <seconds>            judge/local timeout (default: 60)
  --difficulty Easy|Medium|Hard   list/random filter
  --tag <slug>                   repeatable topic filter
  --status ac|notac|todo          list/random progress filter
  --free                         exclude paid-only questions
  --limit <1..100> --skip <n>     list/history pagination

Environment: LEETCODE_ODIN_CONFIG, LEETCODE_ODIN_WORKSPACE,
             LEETCODE_ODIN_NO_BROWSER
Exit codes: 0 success, 1 operational error, 2 usage, 3 failed solution,
            4 local cases without expected results.
Odin runs locally; remote languages must be offered by the problem.`,
	)
}

cmd_auth :: proc(overrides: []string) -> Error {
	// Optional overrides so authorize-url variants can be tested without
	// recompiling: leetcode auth <protocol> <path>
	protocol := "http"
	callback_path := fmt.aprintf(
		"%s:%d",
		CALLBACK_HOST,
		CALLBACK_PORT,
		allocator = context.temp_allocator,
	)
	if len(overrides) >= 1 {
		protocol = overrides[0]
	}
	if len(overrides) >= 2 {
		callback_path = overrides[1]
	}

	fmt.println("== LeetCode browser login ==")
	fmt.printf("Starting local callback server on %s:%d ...\n", CALLBACK_HOST, CALLBACK_PORT)
	url := fmt.aprintf(
		"https://leetcode.com/authorize-login/%s/?path=%s",
		protocol,
		net.percent_encode(callback_path, context.temp_allocator),
		allocator = context.temp_allocator,
	)

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

cmd_status :: proc(as_json := false) -> Error {
	path := config_path() or_return
	cfg := load_config(path) or_return
	if as_json {
		status := verify_credentials(cfg) or_return
		print_json(status)
		if !status.signed_in { return .Not_Signed_In }
		return nil
	}
	return finish_sign_in(cfg)
}

cmd_logout :: proc() -> Error {
	path := config_path() or_return
	return remove_config(path)
}

// Verifies the credentials, then persists them. Credentials that don't
// verify are never written to disk.
verify_and_save :: proc(cfg: Config) -> Error {
	path := config_path() or_return
	finish_sign_in(cfg) or_return
	save_config(cfg, path) or_return
	fmt.println("credentials saved to", path)
	return nil
}

// Verifies the credentials and prints the result.
finish_sign_in :: proc(cfg: Config) -> Error {
	fmt.println("verifying session with leetcode.com ...")
	status := verify_credentials(cfg) or_return
	if !status.signed_in {
		return .Not_Signed_In
	}
	fmt.printf("Signed in as %s (premium: %v)\n", status.username, status.premium)
	return nil
}
