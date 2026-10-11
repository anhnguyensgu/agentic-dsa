// kattis-odin: find, scaffold, test, and submit Kattis problems from the terminal.
//
//     kattis list [page]          scrape the open problems table
//     kattis search <query>       search the catalogue
//     kattis show <id>            statement, difficulty, samples
//     kattis get <id>             scaffold problems/<id>/ with samples
//     kattis test <dir>           build solution.odin and run the samples
//     kattis auth <user>          log in (password on stdin) and save the session
//     kattis submit <dir>         submit dir/solution.odin and poll the verdict
//     kattis submit-start ...     submit once and print a durable job id
//     kattis check <subid>        observe a submission once
//     kattis watch <subid>        poll a submission's verdict
//
// HTTP goes through curl (see http.odin). Kattis markup is machine-generated
// and stable, so the HTML is read with plain substring anchors (html.odin).
//
// All command allocations live in run's arena; nothing is freed individually.
package main

import "core:fmt"
import "core:mem/virtual"
import "core:os"

VERSION :: "kattis-odin 0.2.0"

// Override only at build time for the integration fixture service.
BASE_URL :: #config(KATTIS_BASE_URL, "https://open.kattis.com")

CAPABILITIES :: `{"schema_version":1,"provider":"kattis","version":"` + VERSION + `","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"explicit_problem_id":true}}`

// Failure sites print the specific cause; run prints the summary line.
Error :: enum {
	None,
	Usage,
	Invalid_Problem_Id,
	Invalid_Submission_Id,
	Network,
	Markup_Changed,
	File,
	Destination_Exists,
	Not_Signed_In,
	Login_Failed,
	Build_Failed,
	Samples_Failed,
	Submit_Rejected,
	Not_Accepted,
}

ERROR_MESSAGES := [Error]string {
	.None                  = "",
	.Usage                 = "invalid arguments; run `kattis help`",
	.Invalid_Problem_Id    = "invalid problem id (expected lowercase letters, digits, '-' or '_')",
	.Invalid_Submission_Id = "invalid submission id (expected digits)",
	.Network               = "request to Kattis failed; check the network and the curl installation",
	.Markup_Changed        = "could not parse the Kattis page; its markup may have changed",
	.File                  = "could not read or write the requested files",
	.Destination_Exists    = "destination exists; choose a fresh directory",
	.Not_Signed_In         = "not signed in or session expired; run `kattis auth <user>` (password on stdin)",
	.Login_Failed          = "login failed",
	.Build_Failed          = "solution did not compile",
	.Samples_Failed        = "not every sample passed",
	.Submit_Rejected       = "Kattis rejected the submission",
	.Not_Accepted          = "submission was not accepted",
}

main :: proc() {
	// run returns before exit so its deferred cleanup always happens.
	if code := run(os.args[1:]); code != 0 {
		os.exit(code)
	}
}

run :: proc(args: []string) -> int {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("kattis: out of memory")
		return 1
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	opts, parse_err := parse_options(args)
	if parse_err != nil {
		fmt.eprintln(ERROR_MESSAGES[parse_err])
		return 1
	}
	if err := execute(opts); err != nil {
		fmt.eprintln(ERROR_MESSAGES[err])
		return 1
	}
	return 0
}

execute :: proc(o: Options) -> Error {
	arg :: proc(o: Options, i: int) -> string {
		return o.positionals[i] if i < len(o.positionals) else ""
	}

	switch o.command {
	case .Help:
		fmt.println(USAGE)
	case .Version:
		fmt.println(VERSION)
	case .Capabilities:
		fmt.println(CAPABILITIES)
	case .List:
		return cmd_list(o.page, o.json)
	case .Search:
		return cmd_search(arg(o, 0), o.json)
	case .Show:
		return cmd_show(arg(o, 0), o.json)
	case .Get:
		return cmd_get(arg(o, 0), o.dir, o.json)
	case .Test:
		return cmd_test(arg(o, 0), o.json)
	case .Auth:
		return cmd_auth(arg(o, 0))
	case .Submit:
		return cmd_submit(solution = arg(o, 0), lang = arg(o, 1))
	case .Submit_Start:
		return cmd_submit(solution = arg(o, 1), lang = arg(o, 2), problem_id = arg(o, 0), start_only = true, as_json = o.json)
	case .Check:
		return cmd_check(arg(o, 0), o.json)
	case .Watch:
		return watch_submission(arg(o, 0))
	}
	return nil
}
