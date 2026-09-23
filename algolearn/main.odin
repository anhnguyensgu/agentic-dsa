package main

// algolearn: CLI entry point for the Algorithm Learning plugin (sections 5
// and 11 of AGENTIC_LEARNING.md). Convenience commands (init, doctor, resume)
// wrap the same operation registry as `algolearn call`; they never implement
// different behavior.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "learning"

VERSION :: "0.2.0"

USAGE :: `algolearn - Algorithm Learning engine

usage:
  algolearn init --workspace DIR [--input FILE|-] [--json]
  algolearn doctor --workspace DIR [--json]
  algolearn resume --workspace DIR [--json]
  algolearn serve --workspace DIR
  algolearn call OP --workspace DIR [--input FILE|-] [--json]
  algolearn version

Examples:
  algolearn call session_start --workspace . --input request.json --json

Operations: workspace_init, doctor, profile_update, state_get, problem_search,
  problem_get, plan_next, session_start, session_resume, attempt_start,
  evidence_record, hint_record, case_add, test_run, submission_prepare,
  submission_send, job_check, assessment_record, session_checkpoint,
  session_close, review_due, review_update, progress_get, export_create,
  import_validate, import_apply, data_delete

Mutating operations require request_id and expected_revision inside the
input JSON. Paths are workspace-relative; diagnostics go to stderr.
`

Options :: struct {
	command:          string,
	operation:        string,
	workspace:        string,
	input_path:       string,
	json_mode:        bool,
}

fail_usage :: proc(msg: string) {
	if msg != "" { fmt.eprintln("algolearn:", msg) }
	fmt.eprintln(USAGE)
	os.exit(2)
}

main :: proc() {
	opts := parse_args()
	switch opts.command {
	case "help":    fmt.println(USAGE); os.exit(0)
	case "version": fmt.printf("algolearn %s (schema %d)\n", VERSION, learning.SCHEMA_VERSION); os.exit(0)
	case "init":    os.exit(run_operation_and_report("workspace_init", opts))
	case "resume":  os.exit(run_operation_and_report("session_resume", opts))
	case "doctor":  os.exit(run_operation_and_report("doctor", opts))
	case "serve":   os.exit(run_mcp(opts))
	case "call":    os.exit(run_operation_and_report(opts.operation, opts))
	case:
		fail_usage(fmt.aprintf("unknown command %q", opts.command))
	}
	os.exit(0)
}

parse_args :: proc() -> (opts: Options) {
	args := os.args[1:]
	if len(args) == 0 { fail_usage("") }
	opts.command = args[0]
	i := 1
	for i < len(args) {
		a := args[i]
		switch a {
		case "--workspace":
			if i + 1 >= len(args) { fail_usage("--workspace needs a path") }
			i += 1
			opts.workspace = args[i]
		case "--input":
			if i + 1 >= len(args) { fail_usage("--input needs a file path or -") }
			i += 1
			opts.input_path = args[i]
		case "--json": opts.json_mode = true
		case:
			if opts.command == "call" && opts.operation == "" && !strings.has_prefix(a, "-") {
				opts.operation = a
			} else {
				fail_usage(fmt.aprintf("unexpected argument %q", a))
			}
		}
		i += 1
	}
	if opts.workspace == "" && (opts.command == "init" || opts.command == "doctor" || opts.command == "resume" || opts.command == "serve" || opts.command == "call") {
		fail_usage("--workspace is required")
	}
	if opts.command == "call" && opts.operation == "" {
		fail_usage("call needs an operation name")
	}
	return
}

read_input :: proc(path: string) -> (string, string) {
	if path == "" { return "{}", "" }
	if path == "-" {
		data, err := os.read_entire_file(os.stdin, context.allocator)
		if err != nil { return "", "could not read stdin" }
		defer delete(data)
		return strings.clone(string(data)), ""
	}
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil { return "", fmt.aprintf("could not read %s", path) }
	defer delete(data)
	return strings.clone(string(data)), ""
}

// build_request extracts/injects the mutation envelope fields (request_id,
// expected_revision) into the parsed input object.
build_request :: proc(input_text: string) -> (json.Value, learning.Request, string) {
	req := learning.Request{expected_revision = -1}
	v, perr := json.parse(input_text, .JSON, parse_integers = true)
	if perr != nil {
		return v, req, "input is not valid JSON"
	}
	if _, is_obj := v.(json.Object); !is_obj {
		return v, req, "input must be a JSON object"
	}
	req.request_id = learning.jstr(learning.jget(v, "request_id"))
	if req.request_id == "" {
		// Machine-generated fallback; agents should supply stable ids so
		// retries deduplicate.
		req.request_id = fmt.aprintf("req_%d", time.time_to_unix_nano(time.now()))
	}
	req.request_hash = learning.hash_hex(input_text)
	req.expected_revision = learning.jint(learning.jget(v, "expected_revision"))
	return v, req, ""
}

run_operation_and_report :: proc(op_name: string, opts: Options) -> (exit_code: int) {
	input_text, ierr := read_input(opts.input_path)
	if ierr != "" {
		fmt.eprintln("algolearn:", ierr)
		return 2
	}
	input, req, perr := build_request(input_text)
	if perr != "" {
		fmt.eprintln("algolearn:", perr)
		return 2
	}

	store, lerr := learning.load_store(opts.workspace)
	if lerr != .None {
		print_envelope(opts, make_envelope(req, 0, learning.error_result(lerr, "could not load the event log")))
		return 1
	}

	ctx := learning.Context{workspace = opts.workspace, actor = fmt.aprintf("agent:%s", host_id()), host = host_id()}
	res, found := learning.run_operation(op_name, &ctx, &store, input, req)
	if !found {
		print_envelope(opts, make_envelope(req, store.revision, res))
		return 1
	}

	rev := store.revision
	print_envelope(opts, make_envelope(req, rev, res))
	if res.status == .Pending { return 5 }
	if res.status == .Error {
		code := learning.exit_code_for(res.err)
		return code if code != 0 else 1
	}
	if res.cli_exit != 0 { return res.cli_exit }
	return 0
}

host_id :: proc() -> string { return "generic-cli" }

// -- envelope printing (section 11) --------------------------------------------

make_envelope :: proc(req: learning.Request, revision: int, res_in: learning.Result) -> string {
	res := res_in
	res.data = res_in.data
	o := learning.obj_new()
	defer learning.obj_free(&o)
	learning.obj_field_int(&o, "schema_version", learning.SCHEMA_VERSION)
	learning.obj_field_str(&o, "request_id", req.request_id)
	learning.obj_field_int(&o, "workspace_revision", revision)
	learning.obj_field_str(&o, "status", learning.status_string(res.status))
	learning.obj_field_raw(&o, "data", learning.obj_done(&res.data))
	learning.obj_field_strs(&o, "warnings", res.warnings[:])
	if res.status == .Error {
		e := learning.obj_new()
		defer learning.obj_free(&e)
		learning.obj_field_str(&e, "code", learning.error_code(res.err))
		learning.obj_field_str(&e, "message", res.message)
		learning.obj_field_raw(&o, "error", learning.obj_done(&e))
	} else {
		learning.obj_field_raw(&o, "error", "null")
	}
	learning.obj_field_strs(&o, "next_actions", res.next_actions[:])
	return learning.obj_done(&o)
}

print_envelope :: proc(opts: Options, envelope: string) {
	// The JSON envelope is the machine contract; text mode prints it too
	// until richer text rendering is added.
	fmt.println(envelope)
}

// -- convenience commands (section 5) ------------------------------------------

run_call :: proc(opts: Options) {
	os.exit(run_operation_and_report(opts.operation, opts))
}

run_doctor :: proc(opts: Options) -> int {
	o := learning.obj_new()
	defer learning.obj_free(&o)
	learning.obj_field_int(&o, "schema_version", learning.SCHEMA_VERSION)
	learning.obj_field_str(&o, "engine_version", VERSION)

	ok := true

	// Workspace access.
	ws_ok := os.is_directory(opts.workspace)
	if !ws_ok { ok = false }
	learning.obj_field_bool(&o, "workspace_accessible", ws_ok)
	if !ws_ok {
		learning.obj_field_str(&o, "remedy", "create or point --workspace at a writable practice directory")
	}

	// Learning storage.
	_, lerr := os.stat(learning.manifest_path(opts.workspace), context.allocator)
	initialized := lerr == nil
	learning.obj_field_bool(&o, "initialized", initialized)
	if !initialized {
		learning.obj_field_str(&o, "remedy", "run: algoread init --workspace <dir>")
	}

	// Event log readability.
	store, serr := learning.load_store(opts.workspace)
	learning.obj_field_bool(&o, "event_log_readable", serr == .None)
	if serr != .None { ok = false }
	if store.tail_warning != "" {
		learning.obj_field_str(&o, "event_log_warning", store.tail_warning)
	}
	learning.obj_field_int(&o, "workspace_revision", store.revision)

	// Odin compiler availability: search PATH.
	odin_found := find_on_path("odin")
	learning.obj_field_bool(&o, "odin_compiler", odin_found)
	if !odin_found {
		learning.obj_field_str(&o, "remedy", "install the Odin compiler and add it to PATH; local practice requires it")
	}

	learning.obj_field_bool(&o, "ok", ok)
	if opts.json_mode {
		fmt.println(learning.obj_done(&o))
	} else {
		fmt.printf("algolearn doctor — engine %s (schema %d)\n", VERSION, learning.SCHEMA_VERSION)
		fmt.printf("  workspace:  %s\n", opts.workspace)
		fmt.printf("  storage:    %s\n", "initialized" if initialized else "not initialized (run: algolearn init)")
		fmt.printf("  event log:  %s (revision %d)\n", "ok" if serr == .None else "unreadable", store.revision)
		fmt.printf("  odin:       %s\n", "found" if odin_found else "not found on PATH")
		fmt.printf("  ready:      %s\n", "yes" if ok else "no")
	}
	return 0 if ok else 1
}

find_on_path :: proc(name: string) -> bool {
	path_env := os.get_env("PATH", context.allocator)
	for dir in strings.split(path_env, ":") {
		candidate := learning.join({dir, name})
		if os.is_file(candidate) { return true }
	}
	return false
}
