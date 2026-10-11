package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

USAGE :: `usage: leetcode <command> [arguments] [options]

  auth [protocol path]             browser login with local callback
  paste | status | logout          cookie login, verify, remove credentials
  capabilities                     machine-readable provider capabilities
  list [search]                    browse/search problems
  show <id|slug|url>               problem description and examples
  daily | random                   pick a problem
  languages <problem>              available starter languages
  open <problem>                   open problem in the browser
  pick <problem> [--lang odin]     create a solution workspace
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
  --dir <path>                     destination directory for pick
  --input <file>                   remote-run testcase input file
  --timeout <seconds>              judge/local timeout (default: 60)
  --difficulty Easy|Medium|Hard    list/random filter
  --tag <slug>                     repeatable topic filter
  --status ac|notac|todo           list/random progress filter
  --free                           exclude paid-only questions
  --limit <1..100> --skip <n>      list/history pagination

Environment: LEETCODE_ODIN_CONFIG, LEETCODE_ODIN_WORKSPACE,
             LEETCODE_ODIN_NO_BROWSER
Exit codes: 0 success, 1 operational error, 2 usage, 3 failed solution,
            4 local cases without expected results.
Odin runs locally; remote languages must be offered by the problem.`

Command :: enum {
	Help,
	Version,
	Capabilities,
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
	Pick,
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

Flag :: enum {
	Json,
	Offline,
	Refresh,
	Free,
	Workspace,
	Lang,
	Dir,
	Input,
	Difficulty,
	Status,
	Tag,
	Limit,
	Skip,
	Timeout,
}

Flags :: bit_set[Flag]

FLAG_NAMES := [Flag]string {
	.Json       = "--json",
	.Offline    = "--offline",
	.Refresh    = "--refresh",
	.Free       = "--free",
	.Workspace  = "--workspace",
	.Lang       = "--lang",
	.Dir        = "--dir",
	.Input      = "--input",
	.Difficulty = "--difficulty",
	.Status     = "--status",
	.Tag        = "--tag",
	.Limit      = "--limit",
	.Skip       = "--skip",
	.Timeout    = "--timeout",
}

// Flags that are followed by a value.
VALUE_FLAGS :: Flags{.Workspace, .Lang, .Dir, .Input, .Difficulty, .Status, .Tag, .Limit, .Skip, .Timeout}

Command_Spec :: struct {
	names:    []string, // the first name is canonical; the rest are aliases
	min_args: int,
	max_args: int,
	flags:    Flags,
}

@(private = "file")
PROBLEM_CACHE :: Flags{.Workspace, .Json, .Offline, .Refresh}
@(private = "file")
FILTERS :: Flags{.Difficulty, .Status, .Tag, .Free}

COMMANDS := [Command]Command_Spec {
	.Help         = {names = {"help", "--help", "-h"}},
	.Version      = {names = {"version", "--version"}},
	.Capabilities = {names = {"capabilities"}, flags = {.Json}},
	.Auth         = {names = {"auth"}, max_args = 2},
	.Paste        = {names = {"paste"}},
	.Status       = {names = {"status"}, flags = {.Json}},
	.Logout       = {names = {"logout"}},
	.List         = {names = {"list", "search"}, max_args = 1, flags = {.Workspace, .Json, .Offline, .Limit, .Skip} + FILTERS},
	.Show         = {names = {"show", "fetch"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE},
	.Daily        = {names = {"daily"}, flags = PROBLEM_CACHE},
	.Random       = {names = {"random"}, flags = PROBLEM_CACHE + FILTERS},
	.Languages    = {names = {"languages"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE},
	.Open         = {names = {"open"}, min_args = 1, max_args = 1, flags = {.Workspace, .Offline}},
	.Pick         = {names = {"pick"}, min_args = 1, max_args = 1, flags = PROBLEM_CACHE + {.Dir, .Lang}},
	.Test         = {names = {"test"}, min_args = 1, max_args = 1, flags = {.Timeout, .Json}},
	.Run          = {names = {"run"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Input, .Timeout, .Refresh}},
	.Run_Start    = {names = {"run-start"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Input, .Timeout, .Refresh}},
	.Submit       = {names = {"submit"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Timeout, .Refresh}},
	.Submit_Start = {names = {"submit-start"}, min_args = 2, max_args = 2, flags = {.Workspace, .Json, .Lang, .Timeout, .Refresh}},
	.Check        = {names = {"check"}, min_args = 1, max_args = 1, flags = {.Json, .Timeout}},
	.Submissions  = {names = {"submissions"}, min_args = 1, max_args = 1, flags = {.Workspace, .Json, .Limit, .Skip}},
	.Submission   = {names = {"submission"}, min_args = 1, max_args = 1, flags = {.Json}},
	.Stats        = {names = {"stats"}, max_args = 1, flags = {.Json}},
}

Options :: struct {
	command:     Command,
	positionals: [dynamic]string,
	json:        bool,
	offline:     bool,
	refresh:     bool,
	free:        bool,
	workspace:   string,
	lang:        string,
	dir:         string,
	input:       string,
	difficulty:  string,
	status:      string,
	tags:        [dynamic]string,
	limit:       int,
	skip:        int,
	timeout:     int,
}

parse_options :: proc(args: []string) -> (o: Options, err: Error) {
	o.workspace = os.get_env("LEETCODE_ODIN_WORKSPACE", context.allocator)
	if o.workspace == "" {
		o.workspace = "problems"
	}
	o.limit, o.timeout = 20, 60
	if len(args) == 0 {
		return o, .Usage
	}

	command, known := lookup_command(args[0])
	seen: Flags
	for i := 1; i < len(args); i += 1 {
		arg := args[i]
		switch {
		case arg == "--help" || arg == "-h":
			o.command = .Help
			return o, nil
		case arg == "--":
			append(&o.positionals, ..args[i + 1:])
			i = len(args)
			continue
		case !strings.has_prefix(arg, "-"):
			append(&o.positionals, arg)
			continue
		}

		flag, is_flag := lookup_flag(arg)
		if !is_flag {
			fmt.eprintln("unknown option:", arg)
			return o, .Usage
		}
		seen += {flag}
		value: string
		if flag in VALUE_FLAGS {
			i += 1
			if i >= len(args) || args[i] == "" {
				fmt.eprintln("missing value for", arg)
				return o, .Usage
			}
			value = args[i]
		}
		switch flag {
		case .Json:       o.json = true
		case .Offline:    o.offline = true
		case .Refresh:    o.refresh = true
		case .Free:       o.free = true
		case .Workspace:  o.workspace = value
		case .Lang:       o.lang = value
		case .Dir:        o.dir = value
		case .Input:      o.input = value
		case .Difficulty: o.difficulty = value
		case .Status:     o.status = value
		case .Tag:        append(&o.tags, value)
		case .Limit:      o.limit = parse_count(arg, value) or_return
		case .Skip:       o.skip = parse_count(arg, value) or_return
		case .Timeout:    o.timeout = parse_count(arg, value) or_return
		}
	}
	if !known {
		fmt.eprintln("unknown command:", args[0])
		return o, .Usage
	}
	o.command = command

	switch {
	case o.limit < 1 || o.limit > 100:
		fmt.eprintln("--limit must be between 1 and 100")
		return o, .Usage
	case o.timeout < 1 || o.timeout > 3600:
		fmt.eprintln("--timeout must be between 1 and 3600 seconds")
		return o, .Usage
	case o.offline && o.refresh:
		fmt.eprintln("--offline and --refresh conflict")
		return o, .Usage
	case !one_of(o.difficulty, "", "Easy", "Medium", "Hard"):
		fmt.eprintln("--difficulty must be Easy, Medium, or Hard")
		return o, .Usage
	case !one_of(o.status, "", "ac", "notac", "todo"):
		fmt.eprintln("--status must be ac, notac, or todo")
		return o, .Usage
	}

	spec := COMMANDS[o.command]
	if n := len(o.positionals); n < spec.min_args || n > spec.max_args {
		fmt.eprintf("wrong number of arguments for %s\n", spec.names[0])
		return o, .Usage
	}
	for flag in seen - spec.flags {
		fmt.eprintf("%s does not support %s\n", spec.names[0], FLAG_NAMES[flag])
		return o, .Usage
	}
	return o, nil
}

lookup_command :: proc(name: string) -> (Command, bool) {
	for spec, command in COMMANDS {
		for alias in spec.names {
			if alias == name {
				return command, true
			}
		}
	}
	return {}, false
}

lookup_flag :: proc(name: string) -> (Flag, bool) {
	for flag_name, flag in FLAG_NAMES {
		if flag_name == name {
			return flag, true
		}
	}
	return {}, false
}

parse_count :: proc(flag, value: string) -> (n: int, err: Error) {
	parsed, ok := strconv.parse_int(value)
	if !ok || parsed < 0 {
		fmt.eprintln("invalid number for", flag)
		return 0, .Usage
	}
	return parsed, nil
}

one_of :: proc(value: string, accepted: ..string) -> bool {
	for a in accepted {
		if value == a {
			return true
		}
	}
	return false
}
