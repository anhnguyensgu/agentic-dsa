package kattis

import judge ".."
import "core:fmt"

USAGE :: `usage: algo judge kattis <command> [arguments] [options]

  auth <user>                      log in; the password arrives on stdin
  status | logout                  verify or remove the saved session
  capabilities                     machine-readable provider capabilities
  list [search]                    browse/search problems
  show <id>                        problem statement and samples
  get <id> [--lang odin]           create a solution workspace
  test <directory>                 compile and run local Odin samples
  submit [problem] <file|dir>      submit code to the Kattis judge
  submit-start <problem> <file>    create a job and return without polling
  check <submission-id>            wait for an existing judge result

  --json                           machine-readable output (data commands)
  --workspace <path>               workspace root (default: ./problems)
  --lang <name>                    starter/submission language
  --dir <path>                     destination directory for get
  --page <n>                       problem table page (default: 0)
  --timeout <seconds>              judge/local timeout (default: 120 for the
                                   judge; 30 to build, 10 per sample)

Aliases: search = list, fetch = show, pick = get, watch = check.
Environment: KATTIS_ODIN_SESSION, KATTIS_ODIN_WORKSPACE
Exit codes: 0 success, 1 operational error, 2 usage, 3 failed solution,
            4 samples without expected output.
submit <dir> takes the problem id from the directory name; the submission
language defaults to the file extension's Kattis language.`

Command :: enum {
	Auth,
	Status,
	Logout,
	List,
	Show,
	Get,
	Test,
	Submit,
	Submit_Start,
	Check,
}

COMMANDS := [Command]judge.Command_Spec {
	.Auth = {names = {"auth"}, min_args = 1, max_args = 1, handler = cmd_auth},
	.Status = {names = {"status"}, flags = {.Json}, handler = cmd_status},
	.Logout = {names = {"logout"}, handler = cmd_logout},
	.List = {names = {"list", "search"}, max_args = 1, flags = {.Json, .Page}, handler = cmd_list},
	.Show = {
		names = {"show", "fetch"},
		min_args = 1,
		max_args = 1,
		flags = {.Json},
		handler = cmd_show,
	},
	.Get = {
		names = {"get", "pick"},
		min_args = 1,
		max_args = 1,
		flags = {.Json, .Workspace, .Dir, .Lang},
		handler = cmd_get,
	},
	.Test = {
		names = {"test"},
		min_args = 1,
		max_args = 1,
		flags = {.Json, .Timeout},
		handler = cmd_test,
	},
	.Submit = {
		names = {"submit"},
		min_args = 1,
		max_args = 2,
		flags = {.Json, .Lang, .Timeout},
		handler = cmd_submit,
	},
	.Submit_Start = {
		names = {"submit-start"},
		min_args = 2,
		max_args = 2,
		flags = {.Json, .Lang, .Timeout},
		handler = cmd_submit_start,
	},
	.Check = {
		names = {"check", "watch"},
		min_args = 1,
		max_args = 1,
		flags = {.Json, .Timeout},
		handler = cmd_check,
	},
}

validate :: proc(o: Options) -> Error {
	// Kattis search results are a single unpaginated page.
	if Command(o.command) == .List && .Page in o.seen && len(o.positionals) > 0 {
		fmt.eprintln("--page applies to the problem table, not to a search")
		return .Usage
	}
	return nil
}

valid_problem_id :: proc(id: string) -> bool {
	if id == "" {
		return false
	}
	for c in id {
		switch c {
		case 'a' ..= 'z', '0' ..= '9', '-', '_':
		case:
			return false
		}
	}
	return true
}
