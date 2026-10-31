package learn

// Attempt preparation. Provider identity comes from the problem key and is
// never inferred from a directory name. The attempt lives only in the files it
// creates and in the attempt_started event the caller keeps.

import "../safeio"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

PROVIDER_DOWNLOAD_TIMEOUT :: 60 * time.Second

KATTIS_TEMPLATE :: `package main

import "core:fmt"

main :: proc() {
	// Read stdin, solve the selected Kattis problem, and print the answer.
	fmt.eprintln("Learner solution not implemented yet")
}
`

LOCAL_TEMPLATE :: `package main

import "core:fmt"

main :: proc() {
	// This portable local harness uses stdin/stdout. Replace this body with
	// the learner's work.
	fmt.eprintln("Learner solution not implemented yet")
}
`

// safe_relative_path accepts only plain relative paths inside a workspace.
safe_relative_path :: proc(path: string) -> bool {
	if path == "" || os.is_absolute_path(path) {
		return false
	}
	normalized, _ := strings.replace_all(path, "\\", "/")
	for part in strings.split(normalized, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}

// path_is_within_workspace resolves symlinks before comparing.
path_is_within_workspace :: proc(workspace, path: string) -> bool {
	workspace_abs, workspace_err := os.get_absolute_path(workspace, context.allocator)
	path_abs, path_err := os.get_absolute_path(path, context.allocator)
	if workspace_err != nil || path_err != nil {
		return false
	}
	prefix := strings.concatenate({workspace_abs, os.Path_Separator_String})
	return path_abs == workspace_abs || strings.has_prefix(path_abs, prefix)
}

read_source_hash :: proc(path: string) -> (string, Engine_Error) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return "", .Not_Found
	}
	return hash_hex(string(data)), nil
}

// -- attempt_start -------------------------------------------------------------

Attempt_Start_Params :: struct {
	problem_key:         string,
	language:            string,
	action:              string, // fresh (default) | register_existing
	source_path:         string,
	runner_kind:         string, // stdin_stdout (default) | odin_test_package | provider_workspace
	previous_attempt_id: string,
	session_id:          string, // the caller's own session id, copied into the event
}

op_attempt_start :: proc(
	ctx: ^Context,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Attempt_Start_Params) or_return
	if p.problem_key == "" || p.language == "" {
		return {}, invalid("problem_key and language must be non-empty strings")
	}
	action := first_nonempty(p.action, "fresh")
	if action != "fresh" && action != "register_existing" {
		return {}, invalid("action must be fresh or register_existing")
	}
	problem := parse_problem_key(p.problem_key) or_return
	traits, _ := provider_traits(problem.provider)
	// A downloaded exercise ships with its own Odin test package.
	runner_kind := first_nonempty(
		p.runner_kind,
		"odin_test_package" if traits.downloads else "stdin_stdout",
	)
	switch runner_kind {
	case "stdin_stdout", "odin_test_package", "provider_workspace":
	case:
		return {}, invalid("runner_kind must be stdin_stdout, odin_test_package, or provider_workspace")
	}
	if p.language != "odin" && runner_kind != "provider_workspace" {
		return {}, fail(.Unsupported_Capability, "the guaranteed local runner is Odin; use provider_workspace for another language")
	}
	if traits.downloads && !valid_track(p.language) {
		return {}, invalid("language must be the provider's track name: lowercase letters, digits, and '-'")
	}

	attempt_id := new_id("att")
	fresh := action == "fresh"
	source_path := p.source_path
	created_dir := ""
	// A fresh directory is removed again if the attempt fails after creating it.
	defer if err != nil && created_dir != "" {
		os.remove_all(created_dir)
	}
	if fresh && traits.downloads {
		source_path, created_dir = download_exercise(ctx, problem, p.language) or_return
	} else if fresh {
		source_path = create_fresh_attempt(ctx.workspace, problem, attempt_id) or_return
		created_dir = join(ctx.workspace, os.dir(source_path))
	} else {
		if !safe_relative_path(source_path) {
			return {}, invalid("source_path must be a safe workspace-relative path")
		}
		source_abs := join(ctx.workspace, source_path)
		if !os.is_file(source_abs) {
			return {}, fail(.Not_Found, "the source_path does not name a file in the workspace")
		}
		if !path_is_within_workspace(ctx.workspace, source_abs) {
			return {}, invalid("source_path resolves outside the workspace through a symlink")
		}
	}
	source_hash, hash_err := read_source_hash(join(ctx.workspace, source_path))
	if hash_err != nil {
		return {}, fail(hash_err, "could not hash the attempt source")
	}
	// Test runs count as evidence only while the tests stay as they were.
	tests_hash := ""
	if runner_kind == "odin_test_package" {
		tests_hash = package_tests_hash(os.dir(join(ctx.workspace, source_path)))
	}

	payload := Attempt_Started {
		p.problem_key,
		p.language,
		source_path,
		source_hash,
		runner_kind,
		p.previous_attempt_id,
		fresh,
		tests_hash,
	}
	emit(ctx, &res, .Attempt_Started, payload, p.session_id, attempt_id)

	Data :: struct {
		attempt_id:  string,
		source_path: string,
		source_hash: string,
		runner_kind: string,
		tests_hash:  string,
		fresh:       bool,
	}
	res.data = to_json(Data{attempt_id, source_path, source_hash, runner_kind, tests_hash, fresh})
	append(
		&res.next_actions,
		"keep the attempt_started event and pass source_path (and tests_hash for odin_test_package) to test_run",
	)
	return
}

// create_fresh_attempt makes problems/<provider>/<slug>/<attempt>/ with a
// starter solution and an empty case file, removing it again on failure.
@(private = "file")
create_fresh_attempt :: proc(
	workspace: string,
	problem: Problem,
	attempt_id: string,
) -> (
	source_path: string,
	err: Op_Error,
) {
	dir := join("problems", problem.provider, problem.slug, attempt_id)
	dir_abs := join(workspace, dir)
	if os.exists(dir_abs) {
		return "", fail(.Destination_Exists, "the fresh attempt destination already exists")
	}
	if mkdir_err := os.make_directory_all(dir_abs, os.perm(0o700));
	   mkdir_err != nil && mkdir_err != .Exist {
		return "", fail(.Storage_Error, "could not create the fresh attempt directory")
	}
	defer if err != nil {
		os.remove_all(dir_abs)
	}
	if !path_is_within_workspace(workspace, dir_abs) {
		return "", invalid(
			"the fresh destination resolves outside the workspace through a symlink",
		)
	}
	source_path = join(dir, "solution.odin")
	traits, _ := provider_traits(problem.provider)
	if write_private_file(join(workspace, source_path), traits.template) != nil {
		return "", fail(.Storage_Error, "could not write the fresh source file")
	}
	if write_private_file(join(dir_abs, "cases.json"), "[]\n") != nil {
		return "", fail(.Storage_Error, "could not initialize the local case file")
	}
	return source_path, nil
}

// download_exercise fetches a provider exercise into
// problems/<provider>/<track>/<slug>/ through the provider adapter and returns
// its solution file. An exercise that is already there is never downloaded
// again: a later attempt registers it with register_existing. downloaded is
// the new directory, which the caller removes if the attempt then fails.
@(private = "file")
download_exercise :: proc(
	ctx: ^Context,
	problem: Problem,
	track: string,
) -> (
	source_path, downloaded: string,
	err: Op_Error,
) {
	dir := join("problems", problem.provider, track, problem.slug)
	dir_abs := join(ctx.workspace, dir)
	if os.exists(dir_abs) {
		return "", "", Failure {
			code = .Destination_Exists,
			message = "this exercise is already downloaded; a later attempt registers its solution file",
			next_action = fmt.aprintf(
				"call attempt_start with action register_existing and the solution file in %s as source_path",
				dir,
			),
		}
	}
	command := provider_command(problem.provider) or_return
	append(
		&command,
		"download",
		strings.concatenate({"--track=", track}),
		strings.concatenate({"--exercise=", problem.slug}),
	)
	run := safeio.run(command[:], timeout = PROVIDER_DOWNLOAD_TIMEOUT, keep_credentials = true)
	switch {
	case run.start_failed:
		return "", "", fail(.Unsupported_Capability, "could not launch the provider adapter")
	case !safeio.ok(run):
		if os.exists(dir_abs) {
			os.remove_all(dir_abs)
		}
		reason := strings.trim_space(run.stderr)
		reason = reason[:min(len(reason), 400)]
		code :=
			Engine_Error.Auth_Required if strings.contains(reason, "token") else .Unsupported_Capability
		return "", "", fail(
			code,
			fmt.aprintf("the %s download failed: %s", problem.provider, reason),
		)
	case !os.exists(dir_abs):
		return "", "", fail(
			.Unsupported_Capability,
			fmt.aprintf(
				"the exercise was downloaded outside this workspace; use the global algo workspace, or set ALGO_WORKSPACE to %s and run `algo judge %s setup`",
				ctx.workspace,
				problem.provider,
			),
		)
	case !path_is_within_workspace(ctx.workspace, dir_abs):
		os.remove_all(dir_abs)
		return "", "", invalid(
			"the downloaded exercise resolves outside the workspace through a symlink",
		)
	}
	name, named := exercise_solution_file(dir_abs)
	if !named {
		os.remove_all(dir_abs)
		return "", "", fail(
			.Provider_Contract_Changed,
			"the downloaded exercise does not name a solution file in .exercism/config.json",
		)
	}
	return join(dir, name), dir_abs, nil
}

// exercise_solution_file is the first solution file an Exercism download
// names in .exercism/config.json, relative to its directory.
exercise_solution_file :: proc(dir: string) -> (name: string, ok: bool) {
	data, read_err := os.read_entire_file(join(dir, ".exercism", "config.json"), context.allocator)
	if read_err != nil {
		return "", false
	}
	config: struct {
		files: struct {
			solution: []string,
		},
	}
	if !decode(string(data), &config) || len(config.files.solution) == 0 {
		return "", false
	}
	name = config.files.solution[0]
	return name, safe_relative_path(name) && os.is_file(join(dir, name))
}

// valid_track accepts a provider track name, which becomes a path component.
valid_track :: proc(track: string) -> bool {
	if track == "" || len(track) > MAX_SLUG_LENGTH {
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
