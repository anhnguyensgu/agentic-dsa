package judge

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Every flag any provider accepts. A command lists the ones it supports in
// its Command_Spec; the rest are rejected by name.
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
	Page,
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
	.Page       = "--page",
	.Timeout    = "--timeout",
}

// Flags that are followed by a value.
VALUE_FLAGS :: Flags{.Workspace, .Lang, .Dir, .Input, .Difficulty, .Status, .Tag, .Limit, .Skip, .Page, .Timeout}

// Commands every provider has, answered from Provider data.
Builtin :: enum {
	None, // a provider command; see Options.command
	Help,
	Version,
	Capabilities,
}

BUILTINS := [Builtin]Command_Spec {
	.None         = {},
	.Help         = {names = {"help", "--help", "-h"}},
	.Version      = {names = {"version", "--version"}},
	.Capabilities = {names = {"capabilities"}, flags = {.Json}},
}

Options :: struct {
	builtin:     Builtin,
	command:     int, // index into Provider.commands when builtin is .None
	seen:        Flags, // the flags given on the command line
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
	page:        int,
	timeout:     int, // seconds; a provider may treat 0 as each command's default
}

parse_options :: proc(p: Provider, args: []string) -> (o: Options, err: Error) {
	o = p.defaults
	if p.workspace_env != "" {
		o.workspace = os.get_env(p.workspace_env, context.allocator)
	}
	if o.workspace == "" {
		o.workspace = "problems"
	}
	if len(args) == 0 {
		return o, .Usage
	}

	builtin, command, known := lookup_command(p, args[0])
	for i := 1; i < len(args); i += 1 {
		arg := args[i]
		switch {
		case arg == "--help" || arg == "-h":
			o.builtin = .Help
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
		o.seen += {flag}
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
		case .Page:       o.page = parse_count(arg, value) or_return
		case .Timeout:    o.timeout = parse_count(arg, value) or_return
		}
	}
	if !known {
		fmt.eprintln("unknown command:", args[0])
		return o, .Usage
	}
	o.builtin, o.command = builtin, command

	switch {
	case .Limit in o.seen && (o.limit < 1 || o.limit > 100):
		fmt.eprintln("--limit must be between 1 and 100")
		return o, .Usage
	case .Timeout in o.seen && (o.timeout < 1 || o.timeout > 3600):
		fmt.eprintln("--timeout must be between 1 and 3600 seconds")
		return o, .Usage
	}

	spec := command_spec(p, o)
	if n := len(o.positionals); n < spec.min_args || n > spec.max_args {
		fmt.eprintf("wrong number of arguments for %s\n", spec.names[0])
		return o, .Usage
	}
	for flag in o.seen - spec.flags {
		fmt.eprintf("%s does not support %s\n", spec.names[0], FLAG_NAMES[flag])
		return o, .Usage
	}
	if o.builtin == .None && p.validate != nil {
		p.validate(o) or_return
	}
	return o, nil
}

command_spec :: proc(p: Provider, o: Options) -> Command_Spec {
	return BUILTINS[o.builtin] if o.builtin != .None else p.commands[o.command]
}

lookup_command :: proc(p: Provider, name: string) -> (builtin: Builtin, command: int, ok: bool) {
	for spec, b in BUILTINS {
		for alias in spec.names {
			if alias == name {
				return b, 0, true
			}
		}
	}
	for spec, i in p.commands {
		for alias in spec.names {
			if alias == name {
				return .None, i, true
			}
		}
	}
	return .None, 0, false
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

// positional returns the i-th positional argument, or "" when absent.
positional :: proc(o: Options, i: int) -> string {
	return o.positionals[i] if i < len(o.positionals) else ""
}

one_of :: proc(value: string, accepted: ..string) -> bool {
	for a in accepted {
		if value == a {
			return true
		}
	}
	return false
}
