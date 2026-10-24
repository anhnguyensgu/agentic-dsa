// Package judge is the shared core of `algo judge`: the provider contract,
// the `algo judge` Command (command.odin), the provider command-line parser
// (cli.odin), errors and exit codes (errors.odin), the curl transport
// (http.odin), HTML helpers (html.odin), and the local stdin/stdout runner
// (runner.odin).
//
// Each online judge is a provider package under this directory. A provider
// declares data (its commands, flags, defaults, and wording) and implements
// the command handlers; run_provider owns everything else. The executable's
// main package registers the providers, because a provider imports this
// package and not vice versa.
//
// Adding a provider (see kattis/ for a stdin/stdout judge):
//   1. judge/<name>/: `provider :: proc() -> judge.Provider` with a
//      `[Command]judge.Command_Spec` table whose handlers fetch, scaffold,
//      submit, and check through curl, html, runner, and json here.
//   2. Register it in main.odin's provider list.
//   3. Add a fixture-server integration test like tests/kattis_integration.py.
package judge

import "core:fmt"
import "core:mem/virtual"

Provider :: struct {
	name:          string,
	version:       string,
	capabilities:  string, // JSON contract printed by `capabilities`
	usage:         string,
	commands:      []Command_Spec, // Options.command indexes this table
	workspace_env: string, // environment variable overriding the ./problems workspace
	defaults:      Options, // initial option values, e.g. limit and timeout
	validate:      proc(o: Options) -> Error, // provider-specific value checks; may be nil
	messages:      [Error]string, // provider wording that replaces DEFAULT_MESSAGES
}

Handler :: proc(o: Options) -> Error

Command_Spec :: struct {
	names:    []string, // the first name is canonical; the rest are aliases
	min_args: int,
	max_args: int,
	flags:    Flags,
	handler:  Handler,
}

USAGE ::
	`usage: algo judge <provider> <command> [arguments] [options]

Without a provider, lists the registered providers and their versions.
Run ` +
	"`algo judge <provider> help`" +
	` for a provider's commands.`

// run_provider runs one provider command. All of its allocations live in
// this arena; nothing is freed individually, and returned strings must not
// outlive the command.
run_provider :: proc(p: Provider, args: []string) -> int {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintf("%s: out of memory\n", p.name)
		return 1
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)
	context.temp_allocator = context.allocator

	if len(args) == 0 {
		fmt.println(p.usage)
		return exit_code(.Usage)
	}
	o, err := parse_options(p, args)
	if err == nil {
		err = execute(p, o)
	}
	if err != nil {
		fmt.eprintln(error_message(p, err))
	}
	return exit_code(err)
}

execute :: proc(p: Provider, o: Options) -> Error {
	switch o.builtin {
	case .Help:
		fmt.println(p.usage)
	case .Version:
		fmt.println(p.version)
	case .Capabilities:
		fmt.println(p.capabilities)
	case .None:
		return p.commands[o.command].handler(o)
	}
	return nil
}
