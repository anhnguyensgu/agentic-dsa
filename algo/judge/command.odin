package judge

import "core:fmt"

// run runs `algo judge` with the arguments after it.
run :: proc(args: []string, providers: []Provider) -> int {
	if len(args) == 0 {
		for p in providers {
			fmt.printf("%-10s %s\n", p.name, p.version)
		}
		return 0
	}
	if one_of(args[0], ..BUILTINS[.Help].names) {
		fmt.println(USAGE)
		return 0
	}
	for p in providers {
		if p.name == args[0] {
			return run_provider(p, args[1:])
		}
	}
	fmt.eprintln("unknown provider:", args[0])
	fmt.eprintln(USAGE)
	return exit_code(.Usage)
}
