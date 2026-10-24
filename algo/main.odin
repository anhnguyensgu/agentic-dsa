// algo: one executable for algorithm practice.
//
//     algo judge [<provider> <command> ...]   online judges (judge/<provider>/)
//     algo learn <command> ...                the Algorithm Learning engine (learn/)
//
// Every package below owns its command's allocations; main only dispatches.
package main

import "core:fmt"
import "core:os"
import "judge"
import "judge/kattis"
import "judge/leetcode"
import "learn"

ALGO_VERSION :: "algo 0.1.0"

USAGE :: `usage: algo <command> [arguments]

  judge                            list the online judge providers
  judge <provider> <command> ...   run a provider command (leetcode, kattis)
  learn <command> ...              Algorithm Learning engine (init, doctor,
                                   resume, serve, call, version)
  version                          this program's version
  help                             this text`

main :: proc() {
	// Commands return before exit so their deferred cleanup always runs.
	if code := run(os.args); code != 0 {
		os.exit(code)
	}
}

run :: proc(argv: []string) -> int {
	args := argv[1:] if len(argv) > 0 else nil
	if len(args) == 0 {
		fmt.println(USAGE)
		return 2
	}
	switch Command_Name(args[0]) {
	case JUDGE:
		// The provider list, in the order `algo judge` lists them.
		providers := [?]judge.Provider{leetcode.provider(), kattis.provider()}
		return judge.run(args[1:], providers[:])
	case LEARN:
		return learn.run(args[1:])
	case VERSION, VERSION_FLAG:
		fmt.println(ALGO_VERSION)
		return 0
	case HELP, HELP_FLAG, HELP_SHORT:
		fmt.println(USAGE)
		return 0
	}
	fmt.eprintln("unknown command:", args[0])
	fmt.eprintln(USAGE)
	return 2
}

Command_Name :: distinct string
JUDGE :: Command_Name("judge")
LEARN :: Command_Name("learn")
VERSION :: Command_Name("version")
VERSION_FLAG :: Command_Name("--version")
HELP :: Command_Name("help")
HELP_FLAG :: Command_Name("--help")
HELP_SHORT :: Command_Name("-h")
