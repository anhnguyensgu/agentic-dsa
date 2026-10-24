package judge

import "core:fmt"

// Command is a parsed `algo judge` command line: parse builds it, run executes it.
Command :: union {
	Run,
	List,
	Help,
}

// Run runs one provider command. provider is the name as typed; run looks it
// up. args are what follows it.
Run :: struct {
	provider: string,
	args:     []string,
}

// List and Help are `algo judge` and `algo judge help`.
List :: struct {}
Help :: struct {}

// parse reads the arguments after `algo judge`.
parse :: proc(args: []string) -> Command {
	if len(args) == 0 {
		return List{}
	}
	if one_of(args[0], ..BUILTINS[.Help].names) {
		return Help{}
	}
	return Run{provider = args[0], args = args[1:]}
}

// run runs `algo judge` with the arguments after it.
run :: proc(args: []string, providers: []Provider) -> int {
	switch c in parse(args) {
	case Run:
		for p in providers {
			if p.name == c.provider {
				return run_provider(p, c.args)
			}
		}
		fmt.eprintln("unknown provider:", c.provider)
		fmt.eprintln(USAGE)
		return exit_code(.Usage)
	case List:
		for p in providers {
			fmt.printf("%-10s %s\n", p.name, p.version)
		}
		return 0
	case Help:
		fmt.println(USAGE)
		return 0
	}
	return exit_code(.Usage)
}
