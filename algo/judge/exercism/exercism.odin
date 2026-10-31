// Package exercism is the Exercism provider for `algo judge exercism`. It
// mirrors the official exercism CLI instead of reimplementing it: apart from
// setup, list, and capabilities, every command runs `exercism` with the same
// arguments in the current directory, on this process's terminal, and its
// output is never parsed. The exercism CLI owns the API token.
//
// The exercism CLI cannot list a track's exercises, so `list` reads the
// track's public config.json from GitHub and caches it in
// <root>/problems/exercism/.cache/<track>.json for `list --offline`.
//
// Exercises belong in the global algo workspace, at <root>/problems/exercism.
// `setup` points the exercism CLI there once; the commands that work on
// exercises refuse to run while it points elsewhere.
package exercism

import judge ".."
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

VERSION :: "exercism-odin 0.2.0"

// Override only at build time for the integration fixture service.
TRACKS_URL :: #config(EXERCISM_TRACKS_URL, "https://raw.githubusercontent.com/exercism")

CAPABILITIES ::
	`{"schema_version":1,"provider":"exercism","version":"` +
	VERSION +
	`","structured":false,"wraps":"exercism","problem_search":{"implemented":true,"cache":"problems/exercism/.cache/<track>.json"},"submission":{"verdict":false,"reason":"exercism submit uploads an iteration; its test results appear only on exercism.org"}}`

USAGE :: `usage: algo judge exercism <command> [arguments]

  setup                            point the exercism CLI at the algo workspace
                                   (<root>/problems/exercism); run once, after
                                   exercism configure --token=<token>
  list [--track odin] [--json]     a track's exercises by difficulty, marking the
       [--offline]                 downloaded ones; caches the track's catalogue
  capabilities                     machine-readable provider capabilities
  <exercism command> ...           run exercism with the same arguments, e.g.
                                   download --track=odin --exercise=hello-world

download, submit, test, and open run only once setup has pointed the exercism
CLI at the algo workspace. The root is $ALGO_WORKSPACE, else ~/algo.
Requires the exercism CLI on PATH; its output is shown unchanged.
Exit codes: 0 success, 1 exercism or operational error, 2 usage,
            3 exercism test failed.`

Error :: judge.Error

// The exercism commands that work on exercises, with their aliases.
EXERCISE_COMMANDS := []string{"download", "d", "submit", "s", "test", "t", "open", "o"}

// provider registers this package with `algo judge`.
provider :: proc() -> judge.Provider {
	return {
		name = "exercism",
		version = VERSION,
		capabilities = CAPABILITIES,
		usage = USAGE,
		passthrough = run,
	}
}

// run answers setup and capabilities itself and passes every other command
// to exercism.
run :: proc(args: []string) -> int {
	switch args[0] {
	case "setup":
		if len(args) > 1 {
			fmt.eprintln("setup takes no arguments")
			return judge.exit_code(.Usage)
		}
		exit, err := setup()
		return exit_code("configure", exit, err)
	case "list":
		if err := list(args[1:]); err != nil {
			return judge.exit_code(err)
		}
		return 0
	case "capabilities":
		if len(args) > 2 || (len(args) == 2 && args[1] != "--json") {
			fmt.eprintln("capabilities takes no arguments other than --json")
			return judge.exit_code(.Usage)
		}
		fmt.println(CAPABILITIES)
		return 0
	}

	command := command_name(args)
	// Help never needs the workspace.
	asks_help := judge.one_of("--help", ..args) || judge.one_of("-h", ..args)
	if judge.one_of(command, ..EXERCISE_COMMANDS) && !asks_help {
		if err := check_workspace(); err != nil {
			return judge.exit_code(err)
		}
	}
	exit, err := exercism(..args)
	return exit_code(command, exit, err)
}

// exit_code maps an exercism run to algo's exit codes: success stays 0, a
// failed test is 3, and any other failure is 1.
exit_code :: proc(command: string, exit: int, err: Error) -> int {
	switch {
	case err != nil:
		return judge.exit_code(err)
	case exit == 0:
		return 0
	case judge.one_of(command, "test", "t"):
		return judge.exit_code(.Judge_Failed)
	}
	return 1
}

// command_name is the exercism command in args: the first argument that is
// not a global flag. --timeout is the only global flag that takes a value.
command_name :: proc(args: []string) -> string {
	for i := 0; i < len(args); i += 1 {
		switch {
		case args[i] == "--timeout":
			i += 1
		case !strings.has_prefix(args[i], "-"):
			return args[i]
		}
	}
	return ""
}

// Catalogue is the cached form of a track's exercises; the learning engine
// reads the same shape.
Catalogue :: struct {
	schema_version: int,
	track:          string,
	exercises:      []Catalogue_Entry,
}

Catalogue_Entry :: struct {
	slug:       string,
	name:       string,
	difficulty: int,
}

List_Entry :: struct {
	slug:       string,
	name:       string,
	difficulty: int,
	downloaded: bool,
}

List_Report :: struct {
	schema_version: int,
	track:          string,
	exercises:      []List_Entry,
}

// list prints a track's practice exercises, easiest first. It fetches the
// catalogue and refreshes the cache, or with --offline reads only the cache.
list :: proc(args: []string) -> Error {
	track, as_json, offline := "odin", false, false
	for i := 0; i < len(args); i += 1 {
		switch args[i] {
		case "--json":
			as_json = true
		case "--offline":
			offline = true
		case "--track":
			if i += 1; i < len(args) {
				track = args[i]
				continue
			}
			fmt.eprintln("missing value for --track")
			return .Usage
		case:
			fmt.eprintln("unknown argument for list:", args[i])
			return .Usage
		}
	}
	if !valid_track(track) {
		fmt.eprintln("a track name has lowercase letters, digits, and '-' only")
		return .Usage
	}
	exercises := judge.join(root() or_return, "problems", "exercism")
	cache := judge.join(exercises, ".cache", strings.concatenate({track, ".json"}))

	catalogue: Catalogue
	if offline {
		data, read_err := os.read_entire_file(cache, context.allocator)
		if read_err != nil ||
		   !json.is_valid(data, .JSON) ||
		   json.unmarshal(data, &catalogue, .JSON) != nil {
			fmt.eprintf(
				"no cached catalogue for %s; run `algo judge exercism list --track %s` online once\n",
				track,
				track,
			)
			return .Offline
		}
	} else {
		catalogue = fetch_catalogue(track) or_return
		if mkdir_err := os.make_directory_all(os.dir(cache), os.perm(0o755));
		   mkdir_err != nil && mkdir_err != .Exist {
			fmt.eprintln("cannot create", os.dir(cache), os.error_string(mkdir_err))
			return .File
		}
		judge.write_file(cache, judge.encode_json(catalogue), judge.PUBLIC_FILE) or_return
	}

	report := List_Report{1, track, make([]List_Entry, len(catalogue.exercises))}
	for e, i in catalogue.exercises {
		report.exercises[i] = {
			e.slug,
			e.name,
			e.difficulty,
			os.exists(judge.join(exercises, track, e.slug)),
		}
	}
	if as_json {
		judge.print_json(report)
		return nil
	}
	fmt.printf("%-5s %-28s %-32s %s\n", "DIFF", "SLUG", "NAME", "")
	for e in report.exercises {
		fmt.printf(
			"%-5d %-28s %-32s %s\n",
			e.difficulty,
			e.slug,
			e.name,
			"downloaded" if e.downloaded else "",
		)
	}
	fmt.eprintf("%d %s exercises\n", len(report.exercises), track)
	return nil
}

// fetch_catalogue reads a track's config.json from its GitHub repository and
// keeps the practice exercises students can start, sorted by difficulty.
fetch_catalogue :: proc(track: string) -> (catalogue: Catalogue, err: Error) {
	url := fmt.tprintf("%s/%s/main/config.json", TRACKS_URL, track)
	output := judge.curl(
		"-L",
		"--max-time",
		"30",
		"--url",
		url,
		"--write-out",
		`\n%{http_code}`,
	) or_return
	body, trailer, _ := judge.split_trailer(output)
	switch status := strconv.parse_int(strings.trim_space(trailer)) or_else 0; status {
	case 200:
	case 404:
		fmt.eprintf("Exercism has no track named %q\n", track)
		return {}, .Not_Found
	case:
		fmt.eprintf("could not fetch the %s catalogue (HTTP %d)\n", track, status)
		return {}, .Network
	}
	config: struct {
		exercises: struct {
			practice: []struct {
				slug:       string,
				name:       string,
				difficulty: int,
				status:     string,
			},
		},
	}
	if !json.is_valid(transmute([]byte)body, .JSON) ||
	   json.unmarshal_string(body, &config, .JSON) != nil {
		fmt.eprintln("could not parse the track's config.json")
		return {}, .API
	}
	entries := make([dynamic]Catalogue_Entry)
	for e in config.exercises.practice {
		// wip and deprecated exercises cannot be started.
		if e.status == "" || e.status == "active" || e.status == "beta" {
			append(&entries, Catalogue_Entry{e.slug, e.name, e.difficulty})
		}
	}
	slice.stable_sort_by(entries[:], proc(a, b: Catalogue_Entry) -> bool {
		return a.difficulty < b.difficulty
	})
	return {1, track, entries[:]}, nil
}

// valid_track accepts a track name, which becomes a URL and path component.
valid_track :: proc(track: string) -> bool {
	if track == "" || len(track) > 64 {
		return false
	}
	for c in track {
		switch c {
		case 'a' ..= 'z', '0' ..= '9', '-':
		case:
			return false
		}
	}
	return true
}

// setup creates the exercise directory and points the exercism CLI at it.
// exercism configure keeps the saved token and verifies it online.
setup :: proc() -> (exit: int, err: Error) {
	dir := judge.join(root() or_return, "problems", "exercism")
	if mkdir_err := os.make_directory_all(dir, os.perm(0o755));
	   mkdir_err != nil && mkdir_err != .Exist {
		fmt.eprintln("cannot create", dir, os.error_string(mkdir_err))
		return 0, .File
	}
	// The exercism CLI resolves its workspace from any directory, so it gets
	// an absolute path.
	absolute, abs_err := os.get_absolute_path(dir, context.allocator)
	if abs_err != nil {
		fmt.eprintln("cannot resolve", dir, os.error_string(abs_err))
		return 0, .File
	}
	return exercism("configure", "--workspace", absolute)
}

// check_workspace confirms that the exercism CLI's workspace is the algo
// one, comparing resolved paths. Only the workspace field of the CLI's
// config is decoded.
check_workspace :: proc() -> Error {
	want, want_err := os.get_absolute_path(
		judge.join(root() or_return, "problems", "exercism"),
		context.allocator,
	)
	path := config_path() or_return
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintf(
			"the exercism CLI is not configured (%s); run `exercism configure --token=<token>`, then `algo judge exercism setup`\n",
			path,
		)
		return .Config_Read
	}
	config: struct {
		workspace: string,
	}
	if !json.is_valid(data, .JSON) || json.unmarshal(data, &config, .JSON) != nil {
		fmt.eprintln("cannot parse the exercism CLI's config", path)
		return .Config_Read
	}
	have, have_err := os.get_absolute_path(config.workspace, context.allocator)
	if config.workspace == "" || want_err != nil || have_err != nil || have != want {
		fmt.eprintf(
			"the exercism workspace is %q, not the algo workspace; run `algo judge exercism setup`\n",
			config.workspace,
		)
		return .Config_Read
	}
	return nil
}

root :: proc() -> (dir: string, err: Error) {
	if dir = judge.workspace_root(); dir == "" {
		fmt.eprintln("cannot resolve the algo workspace; set ALGO_WORKSPACE")
		return "", .Config_Path
	}
	return dir, nil
}

// config_path is the exercism CLI's user.json, found the way the CLI finds
// it: EXERCISM_CONFIG_HOME, else $XDG_CONFIG_HOME/exercism, else
// ~/.config/exercism.
config_path :: proc() -> (path: string, err: Error) {
	if dir := os.get_env("EXERCISM_CONFIG_HOME", context.allocator); dir != "" {
		return judge.join(dir, "user.json"), nil
	}
	if dir := os.get_env("XDG_CONFIG_HOME", context.allocator); dir != "" {
		return judge.join(dir, "exercism", "user.json"), nil
	}
	home, home_err := os.user_home_dir(context.allocator)
	if home_err != nil {
		fmt.eprintln("cannot resolve the home directory")
		return "", .Config_Path
	}
	return judge.join(home, ".config", "exercism", "user.json"), nil
}

// exercism runs the exercism CLI with args in the current directory, on this
// process's stdin, stdout, and stderr, and returns its exit code. err is set
// only when it could not be run.
exercism :: proc(args: ..string) -> (exit: int, err: Error) {
	command := make([dynamic]string)
	append(&command, "exercism")
	append(&command, ..args)
	process, start_err := os.process_start(
		{command = command[:], stdin = os.stdin, stdout = os.stdout, stderr = os.stderr},
	)
	if start_err == .Not_Exist {
		fmt.eprintln(
			"the exercism CLI is not on PATH; install it: https://exercism.org/docs/using/solving-exercises/working-locally",
		)
		return 0, .Unsupported
	}
	if start_err != nil {
		fmt.eprintln("cannot run exercism:", os.error_string(start_err))
		return 0, .Unsupported
	}
	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintln("cannot wait for exercism:", os.error_string(wait_err))
		return 0, .Unsupported
	}
	return state.exit_code, nil
}
