// `algo learn`: CLI and MCP entry point for the Algorithm Learning engine
// (sections 5 and 11 of AGENTIC_LEARNING.md). The convenience commands (init,
// doctor, resume) run the same operation registry as `algo learn call`; they
// never behave differently.
package learn

import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:strings"

USAGE :: `algo learn - Algorithm Learning engine

usage:
  algo learn init --workspace DIR [--input FILE|-] [--json]
  algo learn doctor --workspace DIR [--json]
  algo learn resume --workspace DIR [--json]
  algo learn serve --workspace DIR
  algo learn call OP --workspace DIR [--input FILE|-] [--json]
  algo learn version

Examples:
  algo learn call session_start --workspace . --input request.json --json

Operations: workspace_init, doctor, profile_update, state_get, problem_search,
  problem_get, plan_next, session_start, session_resume, attempt_start,
  evidence_record, hint_record, case_add, test_run, submission_prepare,
  submission_send, job_check, assessment_record, session_checkpoint,
  session_close, review_due, review_update, progress_get, export_create,
  import_validate, import_apply, data_delete

Mutating operations require request_id and expected_revision inside the
input JSON. Paths are workspace-relative; diagnostics go to stderr.`

CLI_HOST :: "generic-cli"

Command :: enum {
	Help,
	Version,
	Init,
	Doctor,
	Resume,
	Serve,
	Call,
}

COMMAND_NAMES := [Command]string {
	.Help    = "help",
	.Version = "version",
	.Init    = "init",
	.Doctor  = "doctor",
	.Resume  = "resume",
	.Serve   = "serve",
	.Call    = "call",
}

// The operation each convenience command runs; call names its own.
COMMAND_OPERATIONS := #partial [Command]string {
	.Init   = "workspace_init",
	.Doctor = "doctor",
	.Resume = "session_resume",
}

Options :: struct {
	command:    Command,
	operation:  string,
	workspace:  string,
	input_path: string, // "" for an empty object, "-" for stdin
	json:       bool,   // the envelope is the only output format today
}

run :: proc(args: []string) -> int {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("algolearn: out of memory")
		return 1
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	opts, usage_error := parse_args(args)
	if usage_error != "" {
		fmt.eprintln("algolearn:", usage_error)
		fmt.eprintln(USAGE)
		return EXIT_INVALID_INPUT
	}
	switch opts.command {
	case .Help:
		fmt.println(USAGE)
		return 0
	case .Version:
		fmt.printf("algolearn %s (schema %d)\n", ENGINE_VERSION, SCHEMA_VERSION)
		return 0
	case .Serve:
		return serve_mcp(opts.workspace)
	case .Init, .Doctor, .Resume, .Call:
	}
	return call_operation(opts)
}

// parse_args returns a non-empty usage_error for invalid arguments.
parse_args :: proc(args: []string) -> (opts: Options, usage_error: string) {
	if len(args) == 0 {
		return {}, "missing command"
	}
	command, known := parse_enum(COMMAND_NAMES, args[0])
	if !known {
		return {}, fmt.aprintf("unknown command %q", args[0])
	}
	opts.command = command
	for i := 1; i < len(args); i += 1 {
		switch arg := args[i]; arg {
		case "--workspace", "--input":
			i += 1
			if i >= len(args) {
				return {}, fmt.aprintf("%s needs a value", arg)
			}
			if arg == "--workspace" {
				opts.workspace = args[i]
			} else {
				opts.input_path = args[i]
			}
		case "--json":
			opts.json = true
		case:
			if opts.command != .Call || opts.operation != "" || strings.has_prefix(arg, "-") {
				return {}, fmt.aprintf("unexpected argument %q", arg)
			}
			opts.operation = arg
		}
	}
	switch opts.command {
	case .Help, .Version:
	case .Init, .Doctor, .Resume, .Serve, .Call:
		if opts.workspace == "" {
			return {}, "--workspace is required"
		}
	}
	if opts.command == .Call && opts.operation == "" {
		return {}, "call needs an operation name"
	}
	if opts.operation == "" {
		opts.operation = COMMAND_OPERATIONS[opts.command]
	}
	return opts, ""
}

call_operation :: proc(opts: Options) -> int {
	text, read_ok := read_input(opts.input_path)
	if !read_ok {
		fmt.eprintln("algolearn: could not read", opts.input_path if opts.input_path != "-" else "stdin")
		return EXIT_INVALID_INPUT
	}
	input, req, message := new_request(text)
	if message != "" {
		fmt.eprintln("algolearn:", message)
		return EXIT_INVALID_INPUT
	}

	store, load_err := load_store(opts.workspace)
	if load_err != nil {
		res := failure_result({code = load_err, message = "could not load the event log"})
		fmt.println(envelope(req, 0, res))
		return 1
	}
	ctx := Context{workspace = opts.workspace, actor = "agent:" + CLI_HOST, host = CLI_HOST}
	res, found := run_operation(opts.operation, &ctx, &store, input, req)
	// The JSON envelope is the machine contract; text mode prints it too
	// until a richer text rendering exists.
	fmt.println(envelope(req, store.revision, res))
	if !found {
		return 1
	}
	return exit_code(res)
}

read_input :: proc(path: string) -> (text: string, ok: bool) {
	switch path {
	case "":
		return "{}", true
	case "-":
		data, err := os.read_entire_file(os.stdin, context.allocator)
		return string(data), err == nil
	}
	data, err := os.read_entire_file(path, context.allocator)
	return string(data), err == nil
}
