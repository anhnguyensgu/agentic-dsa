// algo: one executable for algorithm practice.
//
//     algo judge [<provider> <command> ...]   online judges (judge/<provider>/)
//     algo learn <command> ...                the Algorithm Learning engine (learn/)
//
// Installed under the names `leetcode`, `kattis`, or `algolearn` (symlinks),
// it behaves as `algo judge leetcode`, `algo judge kattis`, or `algo learn`.
// Every package below owns its command's allocations; main only dispatches.
package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "judge"
import "judge/kattis"
import "judge/leetcode"
import "learn"

VERSION :: "algo 0.1.0"

USAGE :: `usage: algo <command> [arguments]

  judge                            list the online judge providers
  judge <provider> <command> ...   run a provider command (leetcode, kattis)
  learn <command> ...              Algorithm Learning engine (init, doctor,
                                   resume, serve, call, version)
  version                          this program's version
  help                             this text

Installed as leetcode, kattis, or algolearn, it acts as algo judge leetcode,
algo judge kattis, or algo learn.`

main :: proc() {
	// Commands return before exit so their deferred cleanup always runs.
	if code := run(os.args); code != 0 {
		os.exit(code)
	}
}

run :: proc(argv: []string) -> int {
	args := argv[1:] if len(argv) > 0 else nil
	if len(argv) > 0 {
		args = shim(filepath.base(argv[0]), args)
	}
	if len(args) == 0 {
		fmt.println(USAGE)
		return 2
	}
	switch args[0] {
	case "judge":
		providers := [?]judge.Provider{leetcode.provider(), kattis.provider()}
		return judge.run(args[1:], providers[:])
	case "learn":
		return learn.run(args[1:])
	case "version", "--version":
		fmt.println(VERSION)
		return 0
	case "help", "--help", "-h":
		fmt.println(USAGE)
		return 0
	}
	fmt.eprintln("unknown command:", args[0])
	fmt.eprintln(USAGE)
	return 2
}

// shim maps a legacy executable name onto its command group. A top-level
// command group named explicitly always wins, so `algolearn judge kattis ...`
// (how the engine re-executes itself) and `algolearn learn serve` both work.
shim :: proc(name: string, args: []string) -> []string {
	if len(args) > 0 && (args[0] == "judge" || args[0] == "learn") {
		return args
	}
	group: string
	switch name {
	case "leetcode", "kattis":
		group = "judge"
	case "algolearn":
		group = "learn"
	case:
		return args
	}
	shimmed := make([dynamic]string, 0, len(args) + 2)
	append(&shimmed, group)
	if group == "judge" {
		append(&shimmed, name)
	}
	append(&shimmed, ..args)
	return shimmed[:]
}
