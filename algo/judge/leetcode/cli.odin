package leetcode

import "core:fmt"
import judge ".."

USAGE :: `usage: algo judge leetcode <command> [arguments] [options]

  auth [protocol path]             browser login with local callback
  paste | status | logout          cookie login, verify, remove credentials
  capabilities                     machine-readable provider capabilities
  list [search]                    browse/search problems
  show <id|slug|url>               problem description and examples
  daily | random                   pick a problem
  languages <problem>              available starter languages
  open <problem>                   open problem in the browser
  get <problem> [--lang odin]      create a solution workspace
  test <directory>                 compile and run local Odin cases
  run <problem> <file>             run code on LeetCode examples
  submit <problem> <file>          submit code to LeetCode's judge
  run-start/submit-start <problem> <file>
                                   create a job and return without polling
  check <submission-id>            wait for an existing judge result
  submissions <problem>            your submission history
  submission <submission-id>       submission details and code
  stats [username]                 solved counts and ranking

  --json                           machine-readable output (data commands)
  --offline                        use cached public data only
  --refresh                        refresh cached problem data
  --workspace <path>               workspace/cache root (default: ./problems)
  --lang <slug>                    starter/submission language
  --dir <path>                     destination directory for get
  --input <file>                   remote-run testcase input file
  --timeout <seconds>              judge/local timeout (default: 60)
  --difficulty Easy|Medium|Hard    list/random filter
  --tag <slug>                     repeatable topic filter
  --status ac|notac|todo           list/random progress filter
  --free                           exclude paid-only questions
  --limit <1..100> --skip <n>      list/history pagination

Aliases: search = list, fetch = show, pick = get, watch = check.
Environment: LEETCODE_ODIN_CONFIG, LEETCODE_ODIN_WORKSPACE,
             LEETCODE_ODIN_NO_BROWSER
Exit codes: 0 success, 1 operational error, 2 usage, 3 failed solution,
            4 local cases without expected results.
Odin runs locally; remote languages must be offered by the problem.`

Command :: enum {
	Auth,
	Paste,
	Status,
	Logout,
	List,
	Show,
	Daily,
	Random,
	Languages,
	Open,
	Get,
	Test,
	Run,
	Submit,
	Run_Start,
	Submit_Start,
	Check,
	Submissions,
	Submission,
	Stats,
}

@(private = "file")
PROBLEM_CACHE :: judge.Flags{.Workspace, .Json, .Offline, .Refresh}
@(private = "file")
FILTERS :: judge.Flags{.Difficulty, .Status, .Tag, .Free}

COMMANDS := [Command]judge.Command_Spec {
	.Auth         = {names = {"auth"}, max_args = 2, handler = cmd_auth},
	.Paste        = {names = {"paste"}, handler = cmd_paste},
	.Status       = {names = {"status"}, flags = {.Json}, handler = cmd_status},
	.Logout       = {names = {"logout"}, handler = cmd_logout},
	.List         = {names = {"list", "search"}, max_args = 1, flags = {.Workspace, .Json, .Offline, .Limit, .Skip} + FILTERS, handler = cmd_list},
	.Show         = {names = {"show", "fetch"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE, handler = cmd_problem},
	.Daily        = {names = {"daily"}, flags = PROBLEM_CACHE, handler = cmd_problem},
	.Random       = {names = {"random"}, flags = PROBLEM_CACHE + FILTERS, handler = cmd_problem},
	.Languages    = {names = {"languages"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE, handler = cmd_problem},
	.Open         = {names = {"open"}, min_args = 1, max_args = 1, flags = {.Workspace, .Offline}, handler = cmd_problem},
	.Get          = {names = {"get", "pick"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE + {.Dir, .Lang}, handler = cmd_problem},
	.Test         = {names = {"test"}, min_args = 1, max_args = 1, flags = {.Timeout, .Json}, handler = cmd_local_test},
	.Run          = {names = {"run"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Input, .Timeout, .Refresh}, handler = cmd_judge},
	.Run_Start    = {names = {"run-start"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Input, .Timeout, .Refresh}, handler = cmd_judge},
	.Submit       = {names = {"submit"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Timeout, .Refresh}, handler = cmd_judge},
	.Submit_Start = {names = {"submit-start"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Timeout, .Refresh}, handler = cmd_judge},
	.Check        = {names = {"check", "watch"}, min_args = 1, max_args = 1, flags = {.Json, .Timeout}, handler = cmd_judge},
	.Submissions  = {names = {"submissions"}, min_args = 1, max_args = 1, flags = {.Workspace, .Json, .Limit, .Skip}, handler = cmd_account},
	.Submission   = {names = {"submission"}, min_args = 1, max_args = 1, flags = {.Json}, handler = cmd_account},
	.Stats        = {names = {"stats"}, max_args = 1, flags = {.Json}, handler = cmd_account},
}

validate :: proc(o: Options) -> Error {
	switch {
	case o.offline && o.refresh:
		fmt.eprintln("--offline and --refresh conflict")
		return .Usage
	case !judge.one_of(o.difficulty, "", "Easy", "Medium", "Hard"):
		fmt.eprintln("--difficulty must be Easy, Medium, or Hard")
		return .Usage
	case !judge.one_of(o.status, "", "ac", "notac", "todo"):
		fmt.eprintln("--status must be ac, notac, or todo")
		return .Usage
	}
	return nil
}
