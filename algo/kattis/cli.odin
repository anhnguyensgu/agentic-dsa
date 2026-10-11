package main

import "core:fmt"
import "core:strconv"
import "core:strings"

USAGE :: `usage: kattis <command> [arguments]

  help | version                        this text, or the version string
  capabilities [--json]                 JSON provider capability contract
  list [page] [--json]                  list open problems (default page 0)
  search <query> [page] [--json]        search the catalogue
  show <id> [--json]                    statement, difficulty, and samples
  get <id> [--dir path] [--json]        scaffold problems/<id>/ with samples
  test <dir> [--json]                   build solution.odin and check samples
  auth <user>                           log in; the password arrives on stdin
  submit <dir|file> [language]          submit and poll the verdict
  submit-start <id> <file> [language] [--json]
                                        submit once and return a durable job id
  check <subid> [--json]                observe an existing submission once
  watch <subid>                         poll an existing submission's verdict`

Command :: enum {
	Help,
	Version,
	Capabilities,
	List,
	Search,
	Show,
	Get,
	Test,
	Auth,
	Submit,
	Submit_Start,
	Check,
	Watch,
}

Flag :: enum {
	Json,
	Dir,
}

FLAG_NAMES := [Flag]string {
	.Json = "--json",
	.Dir  = "--dir",
}

Command_Spec :: struct {
	names:          []string,
	min_args:       int,
	max_args:       int,
	flags:          bit_set[Flag],
	page_arg_index: int, // positional holding an optional page number; -1 if none
}

COMMANDS := [Command]Command_Spec {
	.Help         = {names = {"help", "--help", "-h"}, page_arg_index = -1},
	.Version      = {names = {"version", "--version"}, page_arg_index = -1},
	.Capabilities = {names = {"capabilities"}, flags = {.Json}, page_arg_index = -1},
	.List         = {names = {"list"}, max_args = 1, flags = {.Json}, page_arg_index = 0},
	.Search       = {names = {"search"}, min_args = 1, max_args = 2, flags = {.Json}, page_arg_index = 1},
	.Show         = {names = {"show"}, min_args = 1, max_args = 1, flags = {.Json}, page_arg_index = -1},
	.Get          = {names = {"get"}, min_args = 1, max_args = 1, flags = {.Json, .Dir}, page_arg_index = -1},
	.Test         = {names = {"test"}, min_args = 1, max_args = 1, flags = {.Json}, page_arg_index = -1},
	.Auth         = {names = {"auth"}, min_args = 1, max_args = 1, page_arg_index = -1},
	.Submit       = {names = {"submit"}, min_args = 1, max_args = 2, page_arg_index = -1},
	.Submit_Start = {names = {"submit-start"}, min_args = 2, max_args = 3, flags = {.Json}, page_arg_index = -1},
	.Check        = {names = {"check"}, min_args = 1, max_args = 1, flags = {.Json}, page_arg_index = -1},
	.Watch        = {names = {"watch"}, min_args = 1, max_args = 1, page_arg_index = -1},
}

Options :: struct {
	command:     Command,
	positionals: [dynamic]string,
	json:        bool,
	dir:         string,
	page:        int,
}

parse_options :: proc(args: []string) -> (o: Options, err: Error) {
	if len(args) == 0 {
		fmt.eprintln(USAGE)
		return o, .Usage
	}
	found := false
	command_loop: for spec, command in COMMANDS {
		for name in spec.names {
			if name == args[0] {
				o.command = command
				found = true
				break command_loop
			}
		}
	}
	if !found {
		fmt.eprintf("unknown command %q\n", args[0])
		return o, .Usage
	}

	spec := COMMANDS[o.command]
	seen: bit_set[Flag]
	for i := 1; i < len(args); i += 1 {
		switch args[i] {
		case "--json":
			seen += {.Json}
			o.json = true
		case "--dir":
			seen += {.Dir}
			i += 1
			if i >= len(args) || args[i] == "" {
				fmt.eprintln("--dir needs a path")
				return o, .Usage
			}
			o.dir = args[i]
		case:
			if strings.has_prefix(args[i], "--") {
				fmt.eprintf("unknown option %q\n", args[i])
				return o, .Usage
			}
			append(&o.positionals, args[i])
		}
	}

	for flag in seen - spec.flags {
		fmt.eprintf("%s does not accept %s\n", args[0], FLAG_NAMES[flag])
		return o, .Usage
	}
	n := len(o.positionals)
	if n < spec.min_args || n > spec.max_args {
		fmt.eprintf("wrong number of arguments for %s\n", args[0])
		return o, .Usage
	}
	if spec.page_arg_index >= 0 && spec.page_arg_index < n {
		page, ok := strconv.parse_int(o.positionals[spec.page_arg_index])
		if !ok || page < 0 {
			fmt.eprintln("page must be a non-negative integer")
			return o, .Usage
		}
		o.page = page
	}
	return o, nil
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
