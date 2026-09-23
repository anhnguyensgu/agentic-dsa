package learning

// Bounded local Odin execution with source-bound artifacts (sections 12, 15,
// and acceptance A11/A14/A17). Commands are argument arrays; learner input is
// data on stdin and never interpolated into a shell command.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

MAX_CAPTURE_BYTES :: 256 * 1024
DEFAULT_TIMEOUT_SECONDS :: 10

Process_Observation :: struct {
	exit_code:       int,
	stdout:          string,
	stderr:          string,
	timed_out:       bool,
	output_exceeded: bool,
	start_failed:    bool,
}

filtered_child_environment :: proc(allow_provider_credentials := false) -> []string {
	env, err := os.environ(context.allocator)
	if err != nil { return nil }
	out := make([dynamic]string)
	for item in env {
		if allow_provider_credentials { append(&out, item); continue }
		lower := strings.to_lower(item)
		if strings.contains(lower, "token=") || strings.contains(lower, "secret=") ||
		   strings.contains(lower, "password=") || strings.contains(lower, "cookie=") ||
		   strings.contains(lower, "session=") || strings.contains(lower, "authorization=") ||
		   strings.has_prefix(lower, "kattis_") || strings.has_prefix(lower, "leetcode_") {
			continue
		}
		append(&out, item)
	}
	return out[:]
}

bounded_file_text :: proc(path: string, limit: int) -> string {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil { return "" }
	defer delete(data)
	n := min(len(data), limit)
	return strings.clone(string(data[:n]))
}

run_bounded :: proc(command: []string, input: string, timeout_seconds, output_limit: int, allow_provider_credentials := false) -> Process_Observation {
	obs: Process_Observation
	tmp, terr := os.make_directory_temp("", "algolearn-run-*", context.allocator)
	if terr != nil { obs.start_failed = true; return obs }
	defer os.remove_all(tmp)
	in_path := join({tmp, "stdin"})
	out_path := join({tmp, "stdout"})
	err_path := join({tmp, "stderr"})
	if write_private_file(in_path, input) != nil { obs.start_failed = true; return obs }
	in_file, ie := os.open(in_path)
	out_file, oe := os.create(out_path)
	err_file, ee := os.create(err_path)
	if ie != nil || oe != nil || ee != nil {
		if in_file != nil { os.close(in_file) }
		if out_file != nil { os.close(out_file) }
		if err_file != nil { os.close(err_file) }
		obs.start_failed = true
		return obs
	}
	env := filtered_child_environment(allow_provider_credentials)
	defer delete(env)
	process, pe := os.process_start({command = command, env = env, stdin = in_file, stdout = out_file, stderr = err_file})
	if pe != nil {
		os.close(in_file); os.close(out_file); os.close(err_file)
		obs.start_failed = true
		return obs
	}
	started := time.now()
	for {
		state, wait_err := os.process_wait(process, 20 * time.Millisecond)
		if wait_err == nil {
			obs.exit_code = state.exit_code
			break
		}
		if wait_err != .Timeout {
			_ = os.process_kill(process)
			_, _ = os.process_wait(process)
			obs.start_failed = true
			break
		}
		out_info, _ := os.stat(out_path, context.allocator)
		err_info, _ := os.stat(err_path, context.allocator)
		if out_info.size + err_info.size > i64(output_limit) {
			_ = os.process_kill(process)
			_, _ = os.process_wait(process)
			obs.output_exceeded = true
			break
		}
		if time.since(started) >= time.Duration(timeout_seconds) * time.Second {
			_ = os.process_kill(process)
			_, _ = os.process_wait(process)
			obs.timed_out = true
			break
		}
	}
	os.close(in_file); os.close(out_file); os.close(err_file)
	obs.stdout = bounded_file_text(out_path, output_limit)
	obs.stderr = bounded_file_text(err_path, output_limit)
	return obs
}

Case_Record :: struct {
	id:              string,
	name:            string,
	input:           string,
	expected:        string,
	expected_present: bool,
	comparator:      string,
	provenance:      string,
	oracle_verified: bool,
}

attempt_cases :: proc(store: ^Store, attempt_id: string) -> [dynamic]Case_Record {
	cases := make([dynamic]Case_Record)
	for ev in store.events {
		if ev.type != "case_added" || ev.attempt_id != attempt_id { continue }
		payload, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err != nil { continue }
		expected_value := jget(payload, "expected")
		_, is_null := expected_value.(json.Null)
		append(&cases, Case_Record{
			id               = jstr(jget(payload, "case_id")),
			name             = jstr(jget(payload, "name")),
			input            = jstr(jget(payload, "input")),
			expected         = jstr(expected_value),
			expected_present = expected_value != nil && !is_null,
			comparator       = jstr(jget(payload, "comparator")),
			provenance       = jstr(jget(payload, "provenance")),
			oracle_verified  = jbool(jget(payload, "oracle_verified")),
		})
	}
	return cases
}

compare_output :: proc(actual, expected, comparator: string) -> bool {
	switch comparator {
	case "exact":
		return actual == expected
	case "trimmed":
		return strings.trim_space(actual) == strings.trim_space(expected)
	case "tokens":
		a := strings.fields(actual)
		defer delete(a)
		b := strings.fields(expected)
		defer delete(b)
		if len(a) != len(b) { return false }
		for token, i in a { if token != b[i] { return false } }
		return true
	}
	return false
}

op_test_run :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"attempt_id"}, {"mode", "timeout_seconds", "source_selection"}); fail.status == .Error { return fail }
	attempt_id := jstr(jget(input, "attempt_id"))
	mode := get_opt_str(input, "mode")
	if mode == "" { mode = "local" }
	if mode != "local" { return error_result(.Unsupported_Capability, "remote example execution is available only through a configured provider adapter") }
	timeout_seconds := jint(jget(input, "timeout_seconds"))
	if timeout_seconds == 0 { timeout_seconds = DEFAULT_TIMEOUT_SECONDS }
	if timeout_seconds < 1 || timeout_seconds > 60 { return bad_input("timeout_seconds must be between 1 and 60") }
	st := fold(store)
	ai := state_attempt_index(&st, attempt_id)
	if ai < 0 { return error_result(.Not_Found, "attempt does not exist") }
	a := &st.attempts[ai]
	if a.language != "odin" { return error_result(.Unsupported_Capability, "the guaranteed local runner supports Odin attempts") }
	if a.runner_kind != "stdin_stdout" {
		return error_result(.Unsupported_Capability, "this attempt requires its provider workspace runner; use the provider tool until it is registered as stdin_stdout")
	}
	source_abs := join({ctx.workspace, a.source_path})
	source_hash, herr := read_source_hash(source_abs)
	if herr != .None { return error_result(.Not_Found, "the attempt source file is missing") }
	cases := attempt_cases(store, attempt_id)
	defer delete(cases)
	res := ok_result()
	if len(cases) == 0 {
		obj_field_str(&res.data, "outcome", "unverified")
		obj_field_int(&res.data, "verified_passed", 0)
		obj_field_int(&res.data, "verified_failed", 0)
		obj_field_int(&res.data, "unchecked", 0)
		obj_field_str(&res.data, "source_hash", source_hash)
		append(&res.warnings, "no cases are registered; zero cases cannot establish passing behavior")
		append(&res.next_actions, "add an official or independently verified case with case_add")
		res.cli_exit = 4
		return res
	}

	run_tmp, terr := os.make_directory_temp("", "algolearn-build-*", context.allocator)
	if terr != nil { return error_result(.Storage_Error, "could not create the bounded build directory") }
	defer os.remove_all(run_tmp)
	binary := join({run_tmp, "solution"})
	build_cmd := [6]string{"odin", "build", source_abs, "-file", "-o:none", fmt.aprintf("-out:%s", binary)}
	build := run_bounded(build_cmd[:], "", timeout_seconds, MAX_CAPTURE_BYTES)
	if build.start_failed { return error_result(.Unsupported_Capability, "could not start the Odin compiler") }
	if build.timed_out || build.output_exceeded || build.exit_code != 0 {
		obj_field_str(&res.data, "outcome", "compile_error")
		obj_field_str(&res.data, "source_hash", source_hash)
		obj_field_bool(&res.data, "timed_out", build.timed_out)
		obj_field_bool(&res.data, "output_limit_exceeded", build.output_exceeded)
		obj_field_str(&res.data, "diagnostic", build.stderr)
		res.cli_exit = 3
		return res
	}

	case_results := make([dynamic]string)
	defer delete(case_results)
	passed, failed, unchecked := 0, 0, 0
	for c in cases {
		obs := run_bounded({binary}, c.input, timeout_seconds, MAX_CAPTURE_BYTES)
		verified := c.expected_present && c.oracle_verified
		case_ok := false
		if !obs.start_failed && !obs.timed_out && !obs.output_exceeded && obs.exit_code == 0 && verified {
			case_ok = compare_output(obs.stdout, c.expected, c.comparator)
		}
		if !verified { unchecked += 1 } else if case_ok { passed += 1 } else { failed += 1 }
		item := obj_new()
		obj_field_str(&item, "case_id", c.id)
		obj_field_str(&item, "name", c.name)
		obj_field_bool(&item, "verified", verified)
		obj_field_bool(&item, "passed", case_ok)
		obj_field_str(&item, "comparator", c.comparator)
		obj_field_str(&item, "provenance", c.provenance)
		obj_field_int(&item, "exit_code", obs.exit_code)
		obj_field_bool(&item, "timed_out", obs.timed_out)
		obj_field_bool(&item, "output_limit_exceeded", obs.output_exceeded)
		obj_field_str(&item, "actual", obs.stdout)
		obj_field_str(&item, "stderr", obs.stderr)
		append(&case_results, obj_done(&item))
		obj_free(&item)
	}
	outcome := "passed"
	if failed > 0 { outcome = "failed" } else if unchecked > 0 || passed == 0 { outcome = "unverified" }
	artifact_id := fmt.aprintf("artifact_%s", hash_hex(fmt.aprintf("%s:%s:%s", attempt_id, source_hash, req.request_id))[:16])
	report := obj_new()
	defer obj_free(&report)
	obj_field_int(&report, "schema_version", SCHEMA_VERSION)
	obj_field_str(&report, "artifact_id", artifact_id)
	obj_field_str(&report, "attempt_id", attempt_id)
	obj_field_str(&report, "source_hash", source_hash)
	obj_field_str(&report, "outcome", outcome)
	obj_field_int(&report, "verified_passed", passed)
	obj_field_int(&report, "verified_failed", failed)
	obj_field_int(&report, "unchecked", unchecked)
	obj_field_raws(&report, "cases", case_results[:])
	report_json := obj_done(&report)
	artifact_path := join({ctx.workspace, LEARNING_DIR, "artifacts", artifact_id, "report.json"})
	if err := write_private_file(artifact_path, report_json); err != nil { return error_result(.Storage_Error, "could not persist the run artifact") }
	snapshot_path := join({ctx.workspace, LEARNING_DIR, "attempts", attempt_id, "snapshots", fmt.aprintf("%s.odin", source_hash)})
	source_bytes, _ := os.read_entire_file(source_abs, context.allocator)
	if source_bytes == nil || write_private_file(snapshot_path, string(source_bytes)) != nil {
		if source_bytes != nil { delete(source_bytes) }
		return error_result(.Storage_Error, "could not persist the exact tested source snapshot")
	}
	delete(source_bytes)
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "artifact_id", artifact_id)
	obj_field_str(&p, "source_hash", source_hash)
	obj_field_str(&p, "outcome", outcome)
	obj_field_int(&p, "verified_passed", passed)
	obj_field_int(&p, "verified_failed", failed)
	obj_field_int(&p, "unchecked", unchecked)
	_, commit_res := commit_and_project(store, ctx, req, "runner_observed", a.session_id, attempt_id, obj_done(&p))
	if commit_res.status == .Error { return commit_res }
	res = commit_res
	obj_field_str(&res.data, "artifact_id", artifact_id)
	obj_field_str(&res.data, "outcome", outcome)
	obj_field_str(&res.data, "source_hash", source_hash)
	obj_field_int(&res.data, "verified_passed", passed)
	obj_field_int(&res.data, "verified_failed", failed)
	obj_field_int(&res.data, "unchecked", unchecked)
	obj_field_raws(&res.data, "cases", case_results[:])
	if outcome == "failed" { res.cli_exit = 3 }
	if outcome == "unverified" {
		res.cli_exit = 4
		append(&res.warnings, "unchecked cases remain separate from verified passing evidence")
	}
	return res
}
