package learning

// The operation registry (section 11). The CLI and the MCP server call the
// same handlers through run_operation. Each operation declares its input as
// a params struct: the struct's fields are the accepted input fields, and the
// MCP tool schemas are derived from the same types.

import "core:encoding/json"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:time"

Input :: struct {
	fields: json.Object, // for presence checks
	text:   string,      // for typed decoding
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

Handler :: #type proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (Result, Op_Error)

Operation :: struct {
	name:     string,
	handler:  Handler,
	params:   typeid,
	required: []string,
	mutating: bool,
}

// Every operation accepts the mutation envelope; mutating ones require it.
ENVELOPE_FIELDS :: [?]string{"request_id", "expected_revision"}

OPERATIONS := [?]Operation {
	{"workspace_init", op_workspace_init, Workspace_Init_Params, {"goal", "language", "timezone", "experience", "time_budget_minutes"}, true},
	{"doctor", op_doctor, Doctor_Params, {}, false},
	{"profile_update", op_profile_update, Profile_Update_Params, {}, true},
	{"state_get", op_state_get, State_Get_Params, {}, false},
	{"problem_search", op_problem_search, Problem_Search_Params, {}, false},
	{"problem_get", op_problem_get, Problem_Get_Params, {"problem_key"}, false},
	{"session_start", op_session_start, Session_Start_Params, {"objective", "mode"}, true},
	{"attempt_start", op_attempt_start, Attempt_Start_Params, {"session_id", "problem_key", "language"}, true},
	{"case_add", op_case_add, Case_Add_Params, {"attempt_id", "input", "comparator", "provenance"}, true},
	{"test_run", op_test_run, Test_Run_Params, {"attempt_id"}, true},
	{"submission_prepare", op_submission_prepare, Submission_Prepare_Params, {"attempt_id"}, true},
	{"submission_send", op_submission_send, Submission_Send_Params, {"intent_id", "authorization_reference"}, true},
	{"job_check", op_job_check, Job_Check_Params, {"job_id"}, true},
	{"session_checkpoint", op_session_checkpoint, Session_Checkpoint_Params, {"session_id", "activity", "summary", "next_action"}, true},
	{"session_resume", op_session_resume, Session_Resume_Params, {}, false},
	{"hint_record", op_hint_record, Hint_Record_Params, {"session_id", "level"}, true},
	{"evidence_record", op_evidence_record, Evidence_Record_Params, {"session_id", "evidence_type", "producer"}, true},
	{"assessment_record", op_assessment_record, Assessment_Record_Params, {"session_id", "concept_id", "dimension", "score", "rationale", "rubric_version"}, true},
	{"session_close", op_session_close, Session_Close_Params, {"session_id", "reason"}, true},
	{"review_due", op_review_due, Review_Due_Params, {}, false},
	{"review_update", op_review_update, Review_Update_Params, {"review_id", "action"}, true},
	{"plan_next", op_plan_next, Plan_Next_Params, {}, false},
	{"progress_get", op_progress_get, Progress_Get_Params, {}, false},
	{"export_create", op_export_create, Export_Create_Params, {}, true},
	{"import_validate", op_import_validate, Import_Validate_Params, {}, false},
	{"import_apply", op_import_apply, Import_Apply_Params, {"kind", "source_hash"}, true},
	{"data_delete", op_data_delete, Data_Delete_Params, {"scope"}, true},
}

find_operation :: proc(name: string) -> (^Operation, bool) {
	for &op in OPERATIONS {
		if op.name == name {
			return &op, true
		}
	}
	return nil, false
}

// new_request parses the input document and extracts the mutation envelope.
// Callers should supply stable request ids so retries deduplicate.
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
	req.request_hash = hash_hex(text)
	req.expected_revision = jint(fields["expected_revision"])
	return
}

run_operation :: proc(name: string, ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, found: bool) {
	op, known := find_operation(name)
	if !known {
		return failure_result(Failure{code = .Not_Found, message = fmt.aprintf("unknown operation %q", name)}), false
	}
	err := check_fields(op, input)
	if err == nil {
		res, err = op.handler(ctx, store, input, req)
	}
	if failure, failed := err.(Failure); failed {
		return failure_result(failure), true
	}
	if res.data == "" {
		res.data = EMPTY_OBJECT
	}
	return res, true
}

failure_result :: proc(f: Failure) -> (res: Result) {
	res = {status = .Error, err = f.code, message = f.message, data = EMPTY_OBJECT}
	if f.next_action != "" {
		append(&res.next_actions, f.next_action)
	}
	return
}

// check_fields rejects unexpected fields rather than ignoring them, and
// requires the declared ones (section 11).
@(private = "file")
check_fields :: proc(op: ^Operation, input: Input) -> Op_Error {
	accepted := reflect.struct_field_names(op.params)
	envelope := ENVELOPE_FIELDS
	for key in input.fields {
		if !contains(accepted, key) && !contains(envelope[:], key) {
			return invalid("input contains unexpected fields")
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

in_range :: proc(name: string, value, lo, hi: int) -> Op_Error {
	if value < lo || value > hi {
		return invalid(fmt.aprintf("field %q must be between %d and %d", name, lo, hi))
	}
	return nil
}

nonempty_items :: proc(name: string, items: []string) -> Op_Error {
	for item in items {
		if item == "" {
			return invalid(fmt.aprintf("field %q must contain non-empty strings", name))
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

// -- committing ----------------------------------------------------------------

COMMIT_ERROR_MESSAGES := #partial [Engine_Error]string {
	.Request_Conflict   = "this request id was already used for a different payload; use a fresh request id",
	.Stale_Revision     = "the workspace changed since it was loaded; reload state and retry with the current revision",
	.Destination_Exists = "learning storage already exists in this workspace",
	.Workspace_Locked   = "another client holds the workspace lock; retry after it releases",
	.Storage_Error      = "the event log needs repair before further writes",
}

commit_failure :: proc(code: Engine_Error) -> Op_Error {
	message := COMMIT_ERROR_MESSAGES[code]
	return fail(code, message if message != "" else ERROR_CODES[code])
}

// commit appends an event and refreshes the projection. A replayed request
// returns its original event.
commit :: proc(
	ctx: ^Context,
	store: ^Store,
	req: Request,
	type: Event_Type,
	payload: any,
	session_id := "",
	attempt_id := "",
) -> (ev: Event, replayed: bool, err: Op_Error) {
	commit_err: Engine_Error
	ev, replayed, commit_err = commit_event(store, EVENT_TYPE_NAMES[type], ctx.actor, req, session_id, attempt_id, to_json(payload))
	if commit_err != nil {
		return {}, false, commit_failure(commit_err)
	}
	st := fold(store)
	if write_state(store.workspace, &st) != nil {
		return ev, replayed, fail(.Storage_Error, "event committed but the projection could not be written")
	}
	store.revision, store.workspace_id = st.revision, st.workspace_id
	return ev, replayed, nil
}

// mutation_result starts the result of a committed operation.
mutation_result :: proc(replayed: bool) -> (res: Result) {
	if replayed {
		append(&res.warnings, "this request was already applied; the existing result is returned")
	}
	return
}

// Replayed marks data produced by a repeated request; it is omitted otherwise.
Replayed :: Maybe(bool)

replayed_flag :: proc(replayed: bool) -> Replayed {
	return true if replayed else nil
}

// -- envelope ------------------------------------------------------------------

// Envelope is the response contract shared by the CLI and MCP (section 11;
// schemas/envelope-v1.json).
Envelope :: struct {
	schema_version:     int,
	request_id:         string,
	workspace_revision: int,
	status:             string,
	data:               Raw_JSON,
	warnings:           []string,
	error:              Maybe(Envelope_Error), // null unless status is "error"
	next_actions:       []string,
}

Envelope_Error :: struct {
	code:    string,
	message: string,
}

envelope :: proc(req: Request, revision: int, res: Result) -> Raw_JSON {
	e := Envelope{
		schema_version     = SCHEMA_VERSION,
		request_id         = req.request_id,
		workspace_revision = revision,
		status             = STATUS_NAMES[res.status],
		data               = res.data if res.data != "" else EMPTY_OBJECT,
		warnings           = res.warnings[:],
		next_actions       = res.next_actions[:],
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
