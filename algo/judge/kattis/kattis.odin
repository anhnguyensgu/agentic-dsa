// Package kattis is the Kattis provider for `algo judge kattis`: find,
// scaffold, test, and submit Kattis problems from the terminal.
//
// The commands, flags, and exit codes are the shared judge surface (see USAGE
// in cli.odin). The session cookie jar lives at ~/.config/kattis-poc/session.
// Kattis markup is machine-generated and stable, so pages are read with the
// judge package's substring anchors (html.odin).
package kattis

import "core:slice"
import judge ".."

VERSION :: "kattis-odin 0.3.0"

// Override only at build time for the integration fixture service.
BASE_URL :: #config(KATTIS_BASE_URL, "https://open.kattis.com")

CAPABILITIES :: `{"schema_version":1,"provider":"kattis","version":"` + VERSION + `","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"explicit_problem_id":true}}`

Error :: judge.Error
Options :: judge.Options

// provider registers this package with `algo judge`.
provider :: proc() -> judge.Provider {
	return {
		name          = "kattis",
		version       = VERSION,
		capabilities  = CAPABILITIES,
		usage         = USAGE,
		commands      = slice.enumerated_array(&COMMANDS),
		workspace_env = "KATTIS_ODIN_WORKSPACE",
		validate      = validate,
		messages      = #partial [Error]string {
			.Invalid_Problem_Id = "invalid problem id (expected lowercase letters, digits, '-' or '_')",
			.Not_Signed_In      = "not signed in or session expired; run `algo judge kattis auth <user>` (password on stdin)",
			.Network            = "request to Kattis failed; check the network and the curl installation",
			.Markup_Changed     = "could not parse the Kattis page; its markup may have changed",
			.Submit_Rejected    = "Kattis rejected the submission",
			.Unchecked          = "some samples have no expected output; add the matching .out file",
		},
	}
}
