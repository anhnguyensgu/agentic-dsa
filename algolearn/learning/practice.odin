package learning

// Attempt preparation and versioned local cases. Provider identity is stored
// explicitly and never inferred from a directory name (sections 10-12).

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

safe_relative_path :: proc(path: string) -> bool {
	if path == "" || os.is_absolute_path(path) { return false }
	normalized, _ := strings.replace_all(path, "\\", "/")
	for part in strings.split(normalized, "/") {
		if part == "" || part == "." || part == ".." { return false }
	}
	return true
}

path_is_within_workspace :: proc(workspace, path: string) -> bool {
	workspace_abs, werr := os.get_absolute_path(workspace, context.allocator)
	if werr != nil { return false }
	path_abs, perr := os.get_absolute_path(path, context.allocator)
	if perr != nil { return false }
	prefix := strings.concatenate({workspace_abs, os.Path_Separator_String}) or_else workspace_abs
	return path_abs == workspace_abs || strings.has_prefix(path_abs, prefix)
}

read_source_hash :: proc(path: string) -> (string, Engine_Error) {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil { return "", .Not_Found }
	defer delete(bytes)
	return hash_hex(string(bytes)), .None
}

state_session_index :: proc(st: ^State, session_id: string) -> int {
	for _, i in st.sessions { if st.sessions[i].id == session_id { return i } }
	return -1
}

state_attempt_index :: proc(st: ^State, attempt_id: string) -> int {
	for _, i in st.attempts { if st.attempts[i].id == attempt_id { return i } }
	return -1
}

attempt_source_template :: proc(provider: string) -> string {
	if provider == "kattis" {
		return `package main

import "core:fmt"

main :: proc() {
	// Read stdin, solve the selected Kattis problem, and print the answer.
	fmt.eprintln("Learner solution not implemented yet")
}
`
	}
	return `package main

import "core:fmt"

main :: proc() {
	// This portable local harness uses stdin/stdout. Keep provider-specific
	// identity in attempt.json and replace this body with the learner's work.
	fmt.eprintln("Learner solution not implemented yet")
}
`
}

op_attempt_start :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "problem_key", "language"}, {"action", "source_path", "runner_kind", "previous_attempt_id"}); fail.status == .Error { return fail }
	session_id := jstr(jget(input, "session_id"))
	problem_key := jstr(jget(input, "problem_key"))
	language := jstr(jget(input, "language"))
	if session_id == "" || problem_key == "" || language == "" { return bad_input("session_id, problem_key, and language must be non-empty strings") }
	action := get_opt_str(input, "action")
	if action == "" { action = "fresh" }
	if action != "fresh" && action != "register_existing" { return bad_input("action must be fresh or register_existing") }
	runner_kind := get_opt_str(input, "runner_kind")
	if runner_kind == "" { runner_kind = "stdin_stdout" }
	if runner_kind != "stdin_stdout" && runner_kind != "odin_test_package" && runner_kind != "provider_workspace" {
		return bad_input("runner_kind must be stdin_stdout, odin_test_package, or provider_workspace")
	}
	if language != "odin" && runner_kind != "provider_workspace" {
		return error_result(.Unsupported_Capability, "the guaranteed local runner is Odin; use provider_workspace for another language")
	}
	problem, found := catalog_find(problem_key)
	if !found { return error_result(.Not_Found, "problem is not present in the bundled catalogue") }
	st := fold(store)
	si := state_session_index(&st, session_id)
	if si < 0 { return error_result(.Not_Found, "session does not exist") }
	if st.sessions[si].status == "closed" { return error_result(.Request_Conflict, "cannot add an attempt to a closed session") }

	attempt_id := fmt_id("att", store.revision + 1)
	source_rel := get_opt_str(input, "source_path")
	fresh := action == "fresh"
	created_dir := ""
	if fresh {
		provider := jstr(jget(problem, "provider"))
		slug := jstr(jget(problem, "slug"))
		dir_rel := join({"problems", provider, slug, attempt_id})
		created_dir = join({ctx.workspace, dir_rel})
		if os.is_file(created_dir) || os.is_directory(created_dir) {
			return error_result(.Destination_Exists, "the fresh attempt destination already exists")
		}
		if err := os.make_directory_all(created_dir, os.perm(0o700)); err != nil && err != .Exist {
			return error_result(.Storage_Error, "could not create the fresh attempt directory")
		}
		if !path_is_within_workspace(ctx.workspace, created_dir) {
			os.remove_all(created_dir)
			return bad_input("the fresh destination resolves outside the workspace through a symlink")
		}
		source_rel = join({dir_rel, "solution.odin"})
		if err := write_private_file(join({ctx.workspace, source_rel}), attempt_source_template(provider)); err != nil {
			os.remove_all(created_dir)
			return error_result(.Storage_Error, "could not write the fresh source file")
		}
		if err := write_private_file(join({created_dir, "cases.json"}), "[]\n"); err != nil {
			os.remove_all(created_dir)
			return error_result(.Storage_Error, "could not initialize the local case file")
		}
	} else {
		if !safe_relative_path(source_rel) { return bad_input("source_path must be a safe workspace-relative path") }
		source_abs := join({ctx.workspace, source_rel})
		if !os.is_file(source_abs) { return error_result(.Not_Found, "the source_path does not name a file in the workspace") }
		if !path_is_within_workspace(ctx.workspace, source_abs) { return bad_input("source_path resolves outside the workspace through a symlink") }
	}

	source_hash, herr := read_source_hash(join({ctx.workspace, source_rel}))
	if herr != .None {
		if created_dir != "" { os.remove_all(created_dir) }
		return error_result(herr, "could not hash the attempt source")
	}
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "problem_key", problem_key)
	obj_field_str(&p, "language", language)
	obj_field_str(&p, "source_path", source_rel)
	obj_field_str(&p, "source_hash", source_hash)
	obj_field_str(&p, "runner_kind", runner_kind)
	obj_field_str(&p, "previous_attempt_id", get_opt_str(input, "previous_attempt_id"))
	obj_field_bool(&p, "fresh", fresh)

	_, res := commit_and_project(store, ctx, req, "attempt_started", session_id, attempt_id, obj_done(&p))
	if res.status == .Error {
		if created_dir != "" { os.remove_all(created_dir) }
		return res
	}
	metadata := obj_new()
	defer obj_free(&metadata)
	obj_field_int(&metadata, "schema_version", SCHEMA_VERSION)
	obj_field_str(&metadata, "attempt_id", attempt_id)
	obj_field_str(&metadata, "session_id", session_id)
	obj_field_str(&metadata, "problem_key", problem_key)
	obj_field_str(&metadata, "language", language)
	obj_field_str(&metadata, "source_path", source_rel)
	obj_field_str(&metadata, "source_hash_at_creation", source_hash)
	obj_field_str(&metadata, "runner_kind", runner_kind)
	meta_path := join({ctx.workspace, LEARNING_DIR, "attempts", attempt_id, "metadata.json"})
	if err := write_private_file(meta_path, obj_done(&metadata)); err != nil {
		append(&res.warnings, "attempt was recorded but its convenience metadata file could not be written; event replay remains authoritative")
	}
	obj_field_str(&res.data, "attempt_id", attempt_id)
	obj_field_str(&res.data, "source_path", source_rel)
	obj_field_str(&res.data, "source_hash", source_hash)
	obj_field_str(&res.data, "runner_kind", runner_kind)
	append(&res.next_actions, "review the statement and cases, then let the learner implement the solution")
	return res
}

op_case_add :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"attempt_id", "input", "comparator", "provenance"}, {"name", "expected", "oracle_verified", "oracle_basis"}); fail.status == .Error { return fail }
	attempt_id := jstr(jget(input, "attempt_id"))
	case_input := jstr(jget(input, "input"))
	comparator := jstr(jget(input, "comparator"))
	provenance := jstr(jget(input, "provenance"))
	if attempt_id == "" || provenance == "" { return bad_input("attempt_id and provenance must be non-empty strings") }
	if comparator != "exact" && comparator != "trimmed" && comparator != "tokens" { return bad_input("comparator must be exact, trimmed, or tokens") }
	st := fold(store)
	ai := state_attempt_index(&st, attempt_id)
	if ai < 0 { return error_result(.Not_Found, "attempt does not exist") }
	expected_present := jget(input, "expected") != nil
	expected := get_opt_str(input, "expected")
	oracle_verified := jbool(jget(input, "oracle_verified")) && expected_present
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "case_id", fmt_id("case", store.revision + 1))
	obj_field_str(&p, "name", get_opt_str(input, "name"))
	obj_field_str(&p, "input", case_input)
	if expected_present { obj_field_str(&p, "expected", expected) } else { obj_field_raw(&p, "expected", "null") }
	obj_field_str(&p, "comparator", comparator)
	obj_field_str(&p, "provenance", provenance)
	obj_field_bool(&p, "oracle_verified", oracle_verified)
	obj_field_str(&p, "oracle_basis", get_opt_str(input, "oracle_basis"))
	_, res := commit_and_project(store, ctx, req, "case_added", st.attempts[ai].session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "case_id", fmt_id("case", store.revision))
	obj_field_bool(&res.data, "verified_oracle", oracle_verified)
	if !oracle_verified {
		append(&res.warnings, "this case has no verified oracle and cannot count as passing evidence")
	}
	return res
}
