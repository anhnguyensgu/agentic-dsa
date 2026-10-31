package learn

// The operation registry. The CLI and the MCP server call the same handlers
// through run_operation. Each operation declares its input as a params
// struct: the struct's fields are the accepted input fields, and the MCP tool
// schemas are derived from the same types. Operations keep no state; anything
// they need from earlier calls arrives as parameters.

import "core:encoding/json"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:time"

Input :: struct {
	fields: json.Object, // for presence checks
	text:   string, // for typed decoding
}

Failure :: struct {
	code:        Engine_Error,
	message:     string,
	next_action: string,
}

// Op_Error is nil on success, so handlers propagate failures with or_return.
Op_Error :: union {
	Failure,
}

Handler :: #type proc(ctx: ^Context, input: Input, req: Request) -> (Result, Op_Error)

Operation :: struct {
	name:        string,
	description: string,
	handler:     Handler,
	params:      typeid,
	required:    []string,
}

// Every operation accepts a request_id, echoed in its envelope.
ENVELOPE_FIELDS :: [?]string{"request_id"}

OPERATIONS := [?]Operation {
	{
		"doctor",
		"Report whether the workspace, the Odin compiler, and each judge provider are ready. Stores nothing.",
		op_doctor,
		Doctor_Params,
		{},
	},
	{
		"attempt_start",
		"Create a fresh attempt for a <provider>:<slug> problem (an Odin scaffold, or the provider's own download for Exercism), or register an existing source file. Returns attempt_id, source_path, source_hash, and tests_hash, plus an attempt_started event to keep.",
		op_attempt_start,
		Attempt_Start_Params,
		{"problem_key", "language"},
	},
	{
		"test_run",
		"Compile and run an Odin source with time and output limits. stdin_stdout runs the cases you pass; odin_test_package runs the package's own tests and needs the tests_hash attempt_start returned. Returns verified and unverified counts and a self-contained runner_observed event.",
		op_test_run,
		Test_Run_Params,
		{"source_path"},
	},
	{
		"submit",
		"Send a source to the problem's online judge, once, after the learner asked for it. Returns the remote_id and a submission_sent event; keep them and poll with job_check. Never resubmit for a pending or unknown outcome.",
		op_submit,
		Submit_Params,
		{"problem_key", "language", "source_path", "authorization_reference"},
	},
	{
		"job_check",
		"Poll a judge for the verdict of a submission by provider and remote_id. Returns its state and a job_observed event. Creates no new submission.",
		op_job_check,
		Job_Check_Params,
		{"provider", "remote_id"},
	},
}

find_operation :: proc(name: string) -> (^Operation, bool) {
	for &op in OPERATIONS {
		if op.name == name {
			return &op, true
		}
	}
	return nil, false
}

// new_request parses the input document and extracts its request_id.
new_request :: proc(text: string) -> (input: Input, req: Request, message: string) {
	value, err := json.parse_string(text, .JSON, parse_integers = true)
	if err != nil {
		return {}, {}, "input is not valid JSON"
	}
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, {}, "input must be a JSON object"
	}
	input = {fields, text}
	req.request_id = jstr(fields["request_id"])
	if req.request_id == "" {
		req.request_id = fmt.aprintf("req_%d", time.time_to_unix_nano(time.now()))
	}
	return
}

run_operation :: proc(
	name: string,
	ctx: ^Context,
	input: Input,
	req: Request,
) -> (
	res: Result,
	found: bool,
) {
	op, known := find_operation(name)
	if !known {
		return failure_result(
				Failure{code = .Not_Found, message = fmt.aprintf("unknown operation %q", name)},
			),
			false
	}
	err := check_fields(op, input)
	if err == nil {
		res, err = op.handler(ctx, input, req)
	}
	if failure, failed := err.(Failure); failed {
		// A failure can still carry events, such as an unknown send outcome.
		events := res.events
		res = failure_result(failure)
		res.events = events
		return res, true
	}
	if res.data == "" {
		res.data = EMPTY_OBJECT
	}
	return res, true
}

failure_result :: proc(f: Failure) -> (res: Result) {
	res = {
		status  = .Error,
		err     = f.code,
		message = f.message,
		data    = EMPTY_OBJECT,
	}
	if f.next_action != "" {
		append(&res.next_actions, f.next_action)
	}
	return
}

// check_fields rejects unexpected fields rather than ignoring them, and
// requires the declared ones.
@(private = "file")
check_fields :: proc(op: ^Operation, input: Input) -> Op_Error {
	accepted := reflect.struct_field_names(op.params)
	envelope := ENVELOPE_FIELDS
	for key in input.fields {
		if !contains(accepted, key) && !contains(envelope[:], key) {
			return invalid(fmt.aprintf("input contains unexpected field %q", key))
		}
	}
	for key in op.required {
		if _, present := input.fields[key]; !present {
			return invalid(fmt.aprintf("field %q is required", key))
		}
	}
	return nil
}

// params decodes the input into an operation's params struct.
params :: proc(input: Input, $T: typeid) -> (p: T, err: Op_Error) {
	if !decode(input.text, &p) {
		return p, invalid("input field types do not match the operation schema")
	}
	return p, nil
}

// -- failures and validation --------------------------------------------------

fail :: proc(code: Engine_Error, message: string) -> Op_Error {
	return Failure{code = code, message = message}
}

invalid :: proc(message: string) -> Op_Error {
	return Failure{code = .Invalid_Input, message = message}
}

// nonempty requires each {name, value} pair to hold a non-empty string.
nonempty :: proc(fields: ..[2]string) -> Op_Error {
	for f in fields {
		if f[1] == "" {
			return invalid(fmt.aprintf("field %q must be a non-empty string", f[0]))
		}
	}
	return nil
}

// enum_value parses a wire name, failing with the list of accepted names.
enum_value :: proc(names: [$E]string, field, value: string) -> (E, Op_Error) {
	if e, ok := parse_enum(names, value); ok {
		return e, nil
	}
	accepted := make([dynamic]string)
	for name in names {
		append(&accepted, name)
	}
	return {}, invalid(fmt.aprintf("%s must be one of: %s", field, strings.join(accepted[:], ", ")))
}

// -- envelope ------------------------------------------------------------------

// Envelope is the response contract shared by the CLI and MCP
// (schemas/envelope-v2.json).
Envelope :: struct {
	schema_version: int,
	request_id:     string,
	status:         string,
	data:           Raw_JSON,
	events:         []Event,
	warnings:       []string,
	error:          Maybe(Envelope_Error), // null unless status is "error"
	next_actions:   []string,
}

Envelope_Error :: struct {
	code:    string,
	message: string,
}

envelope :: proc(req: Request, res: Result) -> Raw_JSON {
	e := Envelope {
		schema_version = SCHEMA_VERSION,
		request_id     = req.request_id,
		status         = STATUS_NAMES[res.status],
		data           = res.data if res.data != "" else EMPTY_OBJECT,
		events         = res.events[:],
		warnings       = res.warnings[:],
		next_actions   = res.next_actions[:],
	}
	if res.status == .Error {
		e.error = Envelope_Error{ERROR_CODES[res.err], res.message}
	}
	return to_json(e)
}

// exit_code maps a result to the CLI's documented exit codes.
exit_code :: proc(res: Result) -> int {
	switch res.status {
	case .Pending:
		return EXIT_PENDING
	case .Error:
		return max(exit_code_for(res.err), 1)
	case .Completed:
	}
	return res.cli_exit
}
