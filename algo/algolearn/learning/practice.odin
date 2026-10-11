package learning

// Attempt preparation and versioned local cases. Provider identity is stored
// explicitly and never inferred from a directory name (sections 10-12).

import "core:os"
import "core:strings"

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
	// This portable local harness uses stdin/stdout. Keep provider-specific
	// identity in attempt.json and replace this body with the learner's work.
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
	session_id:          string,
	problem_key:         string,
	language:            string,
	action:              string, // fresh (default) | register_existing
	source_path:         string,
	runner_kind:         string, // stdin_stdout (default) | odin_test_package | provider_workspace
	previous_attempt_id: string,
}

op_attempt_start :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Attempt_Start_Params) or_return
	if p.session_id == "" || p.problem_key == "" || p.language == "" {
		return {}, invalid("session_id, problem_key, and language must be non-empty strings")
	}
	action := first_nonempty(p.action, "fresh")
	if action != "fresh" && action != "register_existing" {
		return {}, invalid("action must be fresh or register_existing")
	}
	runner_kind := first_nonempty(p.runner_kind, "stdin_stdout")
	switch runner_kind {
	case "stdin_stdout", "odin_test_package", "provider_workspace":
	case:
		return {}, invalid("runner_kind must be stdin_stdout, odin_test_package, or provider_workspace")
	}
	if p.language != "odin" && runner_kind != "provider_workspace" {
		return {}, fail(.Unsupported_Capability, "the guaranteed local runner is Odin; use provider_workspace for another language")
	}
	problem, found := catalog_find(p.problem_key)
	if !found {
		return {}, fail(.Not_Found, "problem is not present in the bundled catalogue")
	}
	st := fold(store)
	session := find_session(&st, p.session_id)
	if session == nil {
		return {}, fail(.Not_Found, "session does not exist")
	}
	if session.status == .Closed {
		return {}, fail(.Request_Conflict, "cannot add an attempt to a closed session")
	}

	attempt_id := fmt_id("att", store.revision + 1)
	fresh := action == "fresh"
	source_path := p.source_path
	created_dir := ""
	// A fresh directory that does not end up recorded is removed again.
	defer if err != nil && created_dir != "" {
		os.remove_all(created_dir)
	}
	if fresh {
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

	payload := Attempt_Started{p.problem_key, p.language, source_path, source_hash, runner_kind, p.previous_attempt_id, fresh}
	ev, replayed := commit(ctx, store, req, .Attempt_Started, payload, p.session_id, attempt_id) or_return
	if replayed {
		// The original request already created its attempt; report that one.
		if created_dir != "" {
			os.remove_all(created_dir)
		}
		decode(string(ev.payload), &payload)
	}

	res = mutation_result(replayed)
	Metadata :: struct {
		schema_version:          int,
		attempt_id:              string,
		session_id:              string,
		problem_key:             string,
		language:                string,
		source_path:             string,
		source_hash_at_creation: string,
		runner_kind:             string,
	}
	metadata := Metadata{SCHEMA_VERSION, ev.attempt_id, p.session_id, p.problem_key, p.language, payload.source_path, payload.source_hash, payload.runner_kind}
	if write_private_file(learning_path(ctx.workspace, "attempts", ev.attempt_id, "metadata.json"), string(to_json(metadata))) != nil {
		append(&res.warnings, "attempt was recorded but its convenience metadata file could not be written; event replay remains authoritative")
	}

	Data :: struct {
		replayed:    Replayed `json:",omitempty"`,
		attempt_id:  string,
		source_path: string,
		source_hash: string,
		runner_kind: string,
	}
	res.data = to_json(Data{replayed_flag(replayed), ev.attempt_id, payload.source_path, payload.source_hash, payload.runner_kind})
	append(&res.next_actions, "review the statement and cases, then let the learner implement the solution")
	return
}

// create_fresh_attempt makes problems/<provider>/<slug>/<attempt>/ with a
// starter solution and an empty case file, removing it again on failure.
@(private = "file")
create_fresh_attempt :: proc(workspace: string, problem: Catalog_Problem, attempt_id: string) -> (source_path: string, err: Op_Error) {
	dir := join("problems", problem.provider, problem.slug, attempt_id)
	dir_abs := join(workspace, dir)
	if os.exists(dir_abs) {
		return "", fail(.Destination_Exists, "the fresh attempt destination already exists")
	}
	if mkdir_err := os.make_directory_all(dir_abs, os.perm(0o700)); mkdir_err != nil && mkdir_err != .Exist {
		return "", fail(.Storage_Error, "could not create the fresh attempt directory")
	}
	defer if err != nil {
		os.remove_all(dir_abs)
	}
	if !path_is_within_workspace(workspace, dir_abs) {
		return "", invalid("the fresh destination resolves outside the workspace through a symlink")
	}
	source_path = join(dir, "solution.odin")
	template := KATTIS_TEMPLATE if problem.provider == "kattis" else LOCAL_TEMPLATE
	if write_private_file(join(workspace, source_path), template) != nil {
		return "", fail(.Storage_Error, "could not write the fresh source file")
	}
	if write_private_file(join(dir_abs, "cases.json"), "[]\n") != nil {
		return "", fail(.Storage_Error, "could not initialize the local case file")
	}
	return source_path, nil
}

// -- case_add ------------------------------------------------------------------

Comparator :: enum {
	Exact,
	Trimmed,
	Tokens,
}

COMPARATOR_NAMES := [Comparator]string {
	.Exact   = "exact",
	.Trimmed = "trimmed",
	.Tokens  = "tokens",
}

Case_Add_Params :: struct {
	attempt_id:      string,
	input:           string,
	comparator:      string,
	provenance:      string,
	name:            string,
	expected:        Maybe(string),
	oracle_verified: bool,
	oracle_basis:    string,
}

op_case_add :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Case_Add_Params) or_return
	if p.attempt_id == "" || p.provenance == "" {
		return {}, invalid("attempt_id and provenance must be non-empty strings")
	}
	if _, ok := parse_enum(COMPARATOR_NAMES, p.comparator); !ok {
		return {}, invalid("comparator must be exact, trimmed, or tokens")
	}
	st := fold(store)
	attempt := find_attempt(&st, p.attempt_id)
	if attempt == nil {
		return {}, fail(.Not_Found, "attempt does not exist")
	}

	// Only a case with an expected output can have a verified oracle.
	_, has_expected := p.expected.?
	oracle_verified := p.oracle_verified && has_expected
	payload := Case_Added{
		case_id         = fmt_id("case", store.revision + 1),
		name            = p.name,
		input           = p.input,
		expected        = p.expected,
		comparator      = p.comparator,
		provenance      = p.provenance,
		oracle_verified = oracle_verified,
		oracle_basis    = p.oracle_basis,
	}
	ev, replayed := commit(ctx, store, req, .Case_Added, payload, attempt.session_id, p.attempt_id) or_return

	Data :: struct {
		replayed:        Replayed `json:",omitempty"`,
		case_id:         string,
		verified_oracle: bool,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), fmt_id("case", ev.sequence), oracle_verified})
	if !oracle_verified {
		append(&res.warnings, "this case has no verified oracle and cannot count as passing evidence")
	}
	return
}
