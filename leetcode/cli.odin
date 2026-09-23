package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Options :: struct {
	command:                                         string,
	positionals:                                     [dynamic]string,
	json, offline, refresh, free:                    bool,
	workspace, lang, dir, input, difficulty, status: string,
	tags:                                            [dynamic]string,
	limit, skip, timeout:                            int,
}

parse_options :: proc(args: []string) -> (o: Options, err: Error) {
	o.workspace = os.get_env("LEETCODE_ODIN_WORKSPACE", context.allocator)
	if o.workspace == "" {o.workspace = "problems"}
	o.limit, o.timeout = 20, 60
	if len(args) == 0 {return o, .Usage}
	o.command = args[0]
	seen := make(map[string]bool)
	if o.command == "search" {o.command = "list"}
	if o.command == "fetch" {o.command = "show"}
	for i := 1; i < len(args); i += 1 {
		a := args[i]
		if a == "--help" || a == "-h" {o.command = "help"; return o, nil}
		if a == "--" {append(&o.positionals, ..args[i + 1:]); break}
		if !strings.has_prefix(a, "-") {append(&o.positionals, a); continue}
		seen[a] = true
		switch a {
		case "--json":
			o.json = true
		case "--offline":
			o.offline = true
		case "--refresh":
			o.refresh = true
		case "--free":
			o.free = true
		case "--workspace",
		     "--lang",
		     "--dir",
		     "--input",
		     "--difficulty",
		     "--status",
		     "--tag",
		     "--limit",
		     "--skip",
		     "--timeout":
			i += 1
			if i >= len(args) ||
			   args[i] == "" {fmt.eprintln("missing value for", a); return o, .Usage}
			v := args[i]
			switch a {
			case "--workspace":
				o.workspace = v
			case "--lang":
				o.lang = v
			case "--dir":
				o.dir = v
			case "--input":
				o.input = v
			case "--difficulty":
				o.difficulty = v
			case "--status":
				o.status = v
			case "--tag":
				append(&o.tags, v)
			case:
				value, ok := strconv.parse_int(v)
				if !ok || value < 0 {fmt.eprintln("invalid number for", a); return o, .Usage}
				switch a {
				case "--limit":
					o.limit = value
				case "--skip":
					o.skip = value
				case "--timeout":
					o.timeout = value
				}
			}
		case:
			fmt.eprintln("unknown option:", a); return o, .Usage
		}
	}
	if o.limit < 1 || o.limit > 100 || o.timeout < 1 || o.timeout > 3600 {return o, .Usage}
	if o.offline && o.refresh {fmt.eprintln("--offline and --refresh conflict"); return o, .Usage}
	if o.difficulty != "" &&
	   o.difficulty != "Easy" &&
	   o.difficulty != "Medium" &&
	   o.difficulty != "Hard" {return o, .Usage}
	if o.status != "" &&
	   o.status != "ac" &&
	   o.status != "notac" &&
	   o.status != "todo" {return o, .Usage}
	n := len(o.positionals)
	switch o.command {
	case "help", "--help", "-h", "version", "--version", "capabilities":
	case "auth":
		if n > 2 {return o, .Usage}
	case "paste", "status", "logout", "daily", "random":
		if n != 0 {return o, .Usage}
	case "list", "stats":
		if n > 1 {return o, .Usage}
	case "show", "languages", "open", "pick", "test", "check", "submissions", "submission":
		if n != 1 {return o, .Usage}
	case "run", "submit", "run-start", "submit-start":
		if n != 2 {return o, .Usage}
	case:
		fmt.eprintln("unknown command:", o.command); return o, .Usage
	}
	allowed := strings.split(allowed_options(o.command), " ")
	for flag in seen {
		ok := false
		for accepted in allowed {if accepted == flag {ok = true; break}}
		if !ok {fmt.eprintf("%s does not support %s\n", o.command, flag); return o, .Usage}
	}
	return o, nil
}

allowed_options :: proc(command: string) -> string {
	switch command {
	case "list":
		return "--workspace --json --offline --difficulty --status --tag --free --limit --skip"
	case "random":
		return "--workspace --json --offline --refresh --difficulty --status --tag --free"
	case "show", "daily", "languages":
		return "--workspace --json --offline --refresh"
	case "pick":
		return "--workspace --json --offline --refresh --dir --lang"
	case "open":
		return "--workspace --offline"
	case "test":
		return "--timeout --json"
	case "run", "run-start":
		return "--workspace --json --lang --input --timeout --refresh"
	case "submit", "submit-start":
		return "--workspace --json --lang --timeout --refresh"
	case "check":
		return "--json --timeout"
	case "submissions":
		return "--workspace --json --limit --skip"
	case "submission", "stats", "status":
		return "--json"
	case "capabilities":
		return "--json"
	}
	return ""
}

dispatch :: proc(o: Options) -> Error {
	switch o.command {
	case "list":
		return cmd_list(o)
	case "show", "daily", "random", "languages", "open", "pick":
		return cmd_problem(o)
	case "run", "submit", "run-start", "submit-start", "check":
		return cmd_judge(o)
	case "submissions", "submission", "stats":
		return cmd_account(o)
	case "test":
		return cmd_local_test(o)
	}
	return .Usage
}
