// Package leetcode is the LeetCode provider for `algo judge leetcode`:
// terminal problem solving and local Odin practice.
//
// See USAGE in cli.odin and README.md for the command surface. Credentials
// live at ~/.config/leetcode-odin/config.json (mode 0600).
//
// Errors propagate with `or_return`; details are printed at the failure site
// and judge.run_provider prints the summary. All command allocations live in
// its arena: returned strings and Config fields are views into it and must
// not outlive the command.
package leetcode

import "core:fmt"
import "core:net"
import "core:os"
import "core:slice"
import judge ".."

VERSION :: "leetcode-odin 0.2.0"

CAPABILITIES :: `{"schema_version":1,"provider":"leetcode","version":"` + VERSION + `","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"remote_odin":false,"reason":"LeetCode does not judge Odin"}}`

Error :: judge.Error
Options :: judge.Options

// provider registers this package with `algo judge`.
provider :: proc() -> judge.Provider {
	return {
		name          = "leetcode",
		version       = VERSION,
		capabilities  = CAPABILITIES,
		usage         = USAGE,
		commands      = slice.enumerated_array(&COMMANDS),
		workspace_env = "LEETCODE_ODIN_WORKSPACE",
		defaults      = {limit = 20, timeout = 60},
		validate      = validate,
		messages      = #partial [Error]string {
			.Callback_Failed = "login failed; you can try `algo judge leetcode paste` instead",
			.Not_Signed_In   = "leetcode.com reports you are NOT signed in; the session is likely expired",
			.Config_Read     = "no usable credentials; run `algo judge leetcode auth` or `algo judge leetcode paste` first",
			.API             = "unexpected LeetCode response (the service may have changed)",
			.Unchecked       = "some local cases have no expected result; edit cases.json and set check=true",
		},
	}
}

cmd_auth :: proc(o: Options) -> Error {
	// Optional overrides let authorize-url variants be tried without
	// recompiling: algo judge leetcode auth <protocol> <path>
	overrides := o.positionals[:]
	protocol := overrides[0] if len(overrides) >= 1 else "http"
	callback := overrides[1] if len(overrides) >= 2 else fmt.tprintf("%s:%d", CALLBACK_HOST, CALLBACK_PORT)

	fmt.println("== LeetCode browser login ==")
	fmt.printf("Starting local callback server on %s:%d ...\n", CALLBACK_HOST, CALLBACK_PORT)
	url := fmt.tprintf("https://leetcode.com/authorize-login/%s/?path=%s", protocol, net.percent_encode(callback))
	cfg := capture_callback(url) or_return
	return verify_and_save(cfg)
}

cmd_paste :: proc(_: Options) -> Error {
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

cmd_status :: proc(o: Options) -> Error {
	path := config_path() or_return
	cfg := load_config(path) or_return
	if !o.json {
		return finish_sign_in(cfg)
	}
	status := verify_credentials(cfg) or_return
	judge.print_json(status)
	return nil if status.signed_in else .Not_Signed_In
}

cmd_logout :: proc(_: Options) -> Error {
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
