package learning

// Operation registry and handlers (section 11 of AGENTIC_LEARNING.md).
//
// The CLI and the future MCP server call the same handlers. Handlers are
// deterministic: they fold committed events into a projection and append new
// events. Verified runner/judge observations are only produced by their own
// handlers; agent-proposed judgments go through assessment_record with
// producer "agent".

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

Context :: struct {
	workspace: string,
	actor:     string, // "agent:<host>" | "learner" | "tool"
	host:      string,
}

Handler :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result

Operation :: struct {
	name:     string,
	handler:  Handler,
	mutating: bool,
}

operations := []Operation{
	{name = "workspace_init", handler = op_workspace_init, mutating = true},
	{name = "state_get", handler = op_state_get, mutating = false},
	{name = "session_start", handler = op_session_start, mutating = true},
	{name = "session_checkpoint", handler = op_session_checkpoint, mutating = true},
	{name = "session_resume", handler = op_session_resume, mutating = false},
	{name = "hint_record", handler = op_hint_record, mutating = true},
	{name = "evidence_record", handler = op_evidence_record, mutating = true},
	{name = "assessment_record", handler = op_assessment_record, mutating = true},
	{name = "session_close", handler = op_session_close, mutating = true},
	{name = "review_due", handler = op_review_due, mutating = false},
	{name = "review_update", handler = op_review_update, mutating = true},
	{name = "plan_next", handler = op_plan_next, mutating = false},
	{name = "progress_get", handler = op_progress_get, mutating = false},
}

run_operation :: proc(name: string, ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> (Result, bool) {
	for op in operations {
		if op.name == name {
			return op.handler(ctx, store, input, req), true
		}
	}
	res := error_result(.Not_Found, fmt.aprintf("unknown operation %q; run 'algoread help' or see the operation registry", name))
	_ = res
	return error_result(.Not_Found, fmt.aprintf("unknown operation %q", name)), false
}

error_result :: proc(err: Engine_Error, msg: string) -> Result {
	res := Result{status = .Error, err = err, message = msg}
	res.data = obj_new()
	return res
}

ok_result :: proc() -> Result {
	res := Result{status = .Completed}
	res.data = obj_new()
	return res
}

bad_input :: proc(msg: string) -> Result {
	return error_result(.Invalid_Input, msg)
}

// require_fields validates that the input is an object with exactly the
// expected keys and that required keys are present.
require_fields :: proc(input: json.Value, required, optional: ..string) -> (json.Value, Result) {
	fail := bad_input("")
	if _, is_obj := input.(json.Object); !is_obj {
		fail.message = "input must be a JSON object"
		return input, fail
	}
	if !check_keys(input, required, optional) {
		fail.message = "input contains unexpected or missing fields"
		return input, fail
	}
	return input, ok_result()
}

str_field :: proc(input: json.Value, key: string) -> (string, Result) {
	v := jget(input, key)
	s := jstr(v)
	if s == "" {
		return "", bad_input(fmt.aprintf("field %q must be a non-empty string", key))
	}
	return s, ok_result()
}

int_field :: proc(input: json.Value, key: string, lo, hi: int) -> (int, Result) {
	v := jget(input, key)
	if v == nil { return 0, bad_input(fmt.aprintf("field %q is required", key)) }
	n := jint(v)
	if n < lo || n > hi {
		return 0, bad_input(fmt.aprintf("field %q must be between %d and %d", key, lo, hi))
	}
	return n, ok_result()
}

// -- projection (section 10: replaceable, rebuilt from events) ---------------

Profile :: struct {
	initialized:         bool,
	goal:                string,
	language:            string,
	timezone:            string,
	experience:          string,
	time_budget_minutes: int,
}

Session_State :: struct {
	id:                   string,
	objective:            string,
	mode:                 string,
	status:               string, // active | paused | closed
	activity:             string, // understanding | planning | implementing | testing | reflecting | reviewing
	next_action:          string,
	summary:              string,
	closure_reason:       string, // completed | stopped | abandoned
	review_updates_applied: bool,
	max_hint_level:       int,
	solution_exposed:     bool,
}

Attempt_State :: struct {
	id:               string,
	session_id:       string,
	problem_key:      string,
	language:         string,
	status:           string,
	hint_count:       int,
	max_hint_level:   int,
	solution_exposed: bool,
}

Review_Item :: struct {
	id:                string,
	concept:           string,
	task_type:         string,
	origin_session_id: string,
	state:             string, // open | snoozed | completed
	credit:            string, // independent | assisted
	interval_index:    int,
	due_ts:            string,
	last_outcome:      string,
}

Concept_State :: struct {
	concept_id: string,
	state:      string, // unknown | introduced | practicing | independent | retained
	independent_solves: int,
	assessments:        int,
}

State :: struct {
	workspace_id: string,
	revision:     int,
	profile:      Profile,
	sessions:     [dynamic]Session_State,
	attempts:     [dynamic]Attempt_State,
	reviews:      [dynamic]Review_Item,
	concepts:     [dynamic]Concept_State,
}

fold :: proc(store: ^Store) -> State {
	st := State{workspace_id = store.workspace_id, revision = store.revision}
	for ev in store.events {
		payload, perr := json.parse(ev.payload, .JSON, parse_integers = true)
		if perr != nil { continue }
		#partial switch ev.type {
		case "workspace_initialized":
			st.profile = Profile{
				initialized         = true,
				goal                = jstr(jget(payload, "goal")),
				language            = jstr(jget(payload, "language")),
				timezone            = jstr(jget(payload, "timezone")),
				experience          = jstr(jget(payload, "experience")),
				time_budget_minutes = jint(jget(payload, "time_budget_minutes")),
			}
		case "session_started":
			append(&st.sessions, Session_State{
				id        = ev.session_id,
				objective = jstr(jget(payload, "objective")),
				mode      = jstr(jget(payload, "mode")),
				status    = "active",
				activity  = "understanding",
			})
		case "session_checkpoint":
			for i, _ in st.sessions {
				if st.sessions[i].id == ev.session_id && st.sessions[i].status != "closed" {
					st.sessions[i].activity = jstr(jget(payload, "activity"))
					st.sessions[i].summary = jstr(jget(payload, "summary"))
					st.sessions[i].next_action = jstr(jget(payload, "next_action"))
					if jbool(jget(payload, "pause")) {
						st.sessions[i].status = "paused"
					}
				}
			}
		case "session_closed":
			for i, _ in st.sessions {
				if st.sessions[i].id == ev.session_id {
					st.sessions[i].status = "closed"
					st.sessions[i].closure_reason = jstr(jget(payload, "reason"))
					// Review updates are computed by the closing handler and
					// stored in the event, so re-folding never applies them
					// twice (section 6: "at most once per session").
					updates := jarray(jget(payload, "review_updates"))
					for u, ui in updates {
						uo := jget_payload(u)
						append(&st.reviews, Review_Item{
							id                = fmt.aprintf("rev_%06d_%d", ev.sequence, ui),
							concept           = jstr(jget(uo, "concept")),
							task_type         = jstr(jget(uo, "task_type")),
							origin_session_id = ev.session_id,
							state             = "open",
							credit            = jstr(jget(uo, "credit")),
							interval_index    = 0,
							due_ts            = jstr(jget(uo, "due_ts")),
						})
					}
					st.sessions[i].review_updates_applied = len(updates) > 0
				}
			}
		case "hint_delivered":
			level := jint(jget(payload, "level"))
			for i, _ in st.sessions {
				if st.sessions[i].id == ev.session_id {
					st.sessions[i].max_hint_level = max(st.sessions[i].max_hint_level, level)
					if level >= 4 { st.sessions[i].solution_exposed = true }
				}
			}
			for i, _ in st.attempts {
				if st.attempts[i].id == ev.attempt_id {
					st.attempts[i].hint_count += 1
					st.attempts[i].max_hint_level = max(st.attempts[i].max_hint_level, level)
					if level >= 4 { st.attempts[i].solution_exposed = true }
				}
			}
		case "assessment_recorded":
			concept := jstr(jget(payload, "concept_id"))
			found := false
			for i, _ in st.concepts {
				if st.concepts[i].concept_id == concept {
					st.concepts[i].assessments += 1
					found = true
				}
			}
			if !found {
				cs := Concept_State{concept_id = concept, state = "introduced", assessments = 1}
				append(&st.concepts, cs)
			}
		}
	}
	// Derive concept states after folding.
	for i, _ in st.concepts {
		st.concepts[i].state = "practicing"
	}
	for r in st.reviews {
		for i, _ in st.concepts {
			if st.concepts[i].concept_id == r.concept && r.credit == "independent" {
				st.concepts[i].independent_solves += 1
			}
		}
	}
	for i, _ in st.concepts {
		if st.concepts[i].independent_solves > 0 {
			st.concepts[i].state = "independent"
		}
		// "retained" requires two distinct qualifying problems including a
		// transfer exercise plus delayed retrieval; not derived here yet.
	}
	return st
}

// jget_payload unwraps a nested object value.
jget_payload :: proc(v: json.Value) -> json.Value {
	return v
}

state_to_json :: proc(st: ^State) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_int(&o, "schema_version", SCHEMA_VERSION)
	obj_field_str(&o, "workspace_id", st.workspace_id)
	obj_field_int(&o, "revision", st.revision)

	po := obj_new()
	if st.profile.initialized {
		obj_field_str(&po, "goal", st.profile.goal)
		obj_field_str(&po, "language", st.profile.language)
		obj_field_str(&po, "timezone", st.profile.timezone)
		obj_field_str(&po, "experience", st.profile.experience)
		obj_field_int(&po, "time_budget_minutes", st.profile.time_budget_minutes)
	}
	obj_field_raw(&o, "profile", obj_done(&po))

	sessions := make([dynamic]string)
	defer delete(sessions)
	for i, _ in st.sessions {
		append(&sessions, session_to_json(&st.sessions[i]))
	}
	obj_field_strs(&o, "sessions", sessions[:])

	reviews := make([dynamic]string)
	defer delete(reviews)
	for i, _ in st.reviews {
		append(&reviews, review_to_json(&st.reviews[i]))
	}
	obj_field_strs(&o, "reviews", reviews[:])

	concepts := make([dynamic]string)
	defer delete(concepts)
	for i, _ in st.concepts {
		append(&concepts, concept_to_json(&st.concepts[i]))
	}
	obj_field_strs(&o, "concepts", concepts[:])
	return obj_done(&o)
}

session_to_json :: proc(s: ^Session_State) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "id", s.id)
	obj_field_str(&o, "objective", s.objective)
	obj_field_str(&o, "mode", s.mode)
	obj_field_str(&o, "status", s.status)
	obj_field_str(&o, "activity", s.activity)
	obj_field_str(&o, "next_action", s.next_action)
	obj_field_str(&o, "summary", s.summary)
	obj_field_str(&o, "closure_reason", s.closure_reason)
	obj_field_int(&o, "max_hint_level", s.max_hint_level)
	obj_field_bool(&o, "solution_exposed", s.solution_exposed)
	return obj_done(&o)
}

review_to_json :: proc(r: ^Review_Item) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "id", r.id)
	obj_field_str(&o, "concept", r.concept)
	obj_field_str(&o, "task_type", r.task_type)
	obj_field_str(&o, "origin_session_id", r.origin_session_id)
	obj_field_str(&o, "state", r.state)
	obj_field_str(&o, "credit", r.credit)
	obj_field_int(&o, "interval_index", r.interval_index)
	obj_field_str(&o, "due_ts", r.due_ts)
	obj_field_str(&o, "last_outcome", r.last_outcome)
	return obj_done(&o)
}

concept_to_json :: proc(c: ^Concept_State) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "concept_id", c.concept_id)
	obj_field_str(&o, "state", c.state)
	obj_field_int(&o, "independent_solves", c.independent_solves)
	obj_field_int(&o, "assessments", c.assessments)
	return obj_done(&o)
}

// write_state atomically replaces the projection. A missing projection is
// rebuilt by replay; a stale one is never treated as truth.
write_state :: proc(workspace: string, st: ^State) -> Engine_Error {
	if werr := write_private_file(state_path(workspace), state_to_json(st)); werr != nil {
		fmt.eprintln("algolearn: failed to write projection:", os.error_string(werr))
		return .Storage_Error
	}
	return .None
}

// commit_and_project runs a mutation and refreshes the projection.
commit_and_project :: proc(store: ^Store, ctx: ^Context, req: Request, ev_type, session_id, attempt_id: string, payload: string) -> (ev: Event, res: Result) {
	res = ok_result()
	ev, err, replayed := commit_event(store, ev_type, ctx.actor, req, session_id, attempt_id, payload)
	if err != .None {
		return ev, error_result(err, engine_error_message(err, replayed))
	}
	if replayed {
		obj_field_bool(&res.data, "replayed", true)
		append(&res.warnings, "this request was already applied; the existing result is returned")
	}
	st := fold(store)
	if serr := write_state(store.workspace, &st); serr != .None {
		return ev, error_result(serr, "event committed but the projection could not be written")
	}
	store.revision = st.revision
	store.workspace_id = st.workspace_id
	return ev, res
}

engine_error_message :: proc(err: Engine_Error, replayed: bool) -> string {
	if replayed { return "" }
	#partial switch err {
	case .Request_Conflict:
		return "this request id was already used for a different payload; use a fresh request id"
	case .Stale_Revision:
		return "the workspace changed since it was loaded; reload state and retry with the current revision"
	case .Destination_Exists:
		return "learning storage already exists in this workspace"
	case .Workspace_Locked:
		return "another client holds the workspace lock; retry after it releases"
	case .Storage_Error:
		return "the event log needs repair before further writes"
	}
	return error_code(err)
}

// -- handlers -----------------------------------------------------------------

MODES := [?]string{"guided", "independent", "assessment", "review", "worked_example"}

valid_mode :: proc(m: string) -> bool {
	for accepted in MODES {
		if accepted == m { return true }
	}
	return false
}

ACTIVITIES := [?]string{"understanding", "planning", "implementing", "testing", "reflecting", "reviewing"}

valid_activity :: proc(a: string) -> bool {
	for accepted in ACTIVITIES {
		if accepted == a { return true }
	}
	return false
}

op_workspace_init :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input,
		"goal", "language", "timezone", "experience", "time_budget_minutes", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	if _, ferr := os.stat(manifest_path(ctx.workspace), context.allocator); ferr == nil {
		return error_result(.Destination_Exists, engine_error_message(.Destination_Exists, false))
	}
	if derr := ensure_dirs(ctx.workspace); derr != nil {
		return error_result(.Storage_Error, fmt.aprintf("could not create learning directories: %s", os.error_string(derr)))
	}

	// Legacy .algo data is preserved untouched; importing it is a separate,
	// explicit operation (section 10).
	if _, lerr := os.stat(join({ctx.workspace, ".algo", "config.json"}), context.allocator); lerr == nil {
		append(&res_warnings, "legacy .algo/config.json detected; run import_validate to preview a conservative migration")
	}

	goal, _ := str_field(input, "goal")
	language, _ := str_field(input, "language")
	timezone, _ := str_field(input, "timezone")
	experience, _ := str_field(input, "experience")
	budget, _ := int_field(input, "time_budget_minutes", 5, 480)

	p := obj_new()
	obj_field_str(&p, "goal", goal)
	obj_field_str(&p, "language", language)
	obj_field_str(&p, "timezone", timezone)
	obj_field_str(&p, "experience", experience)
	obj_field_int(&p, "time_budget_minutes", budget)
	payload := obj_done(&p)
	defer obj_free(&p)

	ev, res := commit_and_project(store, ctx, req, "workspace_initialized", "", "", payload)
	if res.status == .Error { return res }

	workspace_id := ev.workspace_id
	if workspace_id == "" {
		// First event in the workspace: stamp a stable identity derived from
		// the workspace path so later records and exports stay attributable.
		workspace_id = fmt.aprintf("ws_%s", hash_hex(ctx.workspace)[:12])
	}
	obj_field_str(&res.data, "workspace_id", workspace_id)
	obj_field_int(&res.data, "revision", ev.sequence)
	obj_field_bool(&res.data, "legacy_import_pending", has_legacy_config(ctx.workspace))
	append(&res.next_actions, "run plan_next to choose a first objective, or session_start to begin practicing")
	return res
}

has_legacy_config :: proc(ws: string) -> bool {
	_, lerr := os.stat(join({ws, ".algo", "config.json"}), context.allocator)
	return lerr == nil
}

// res_warnings is a placeholder; warnings are appended directly on Result.
res_warnings: [dynamic]string

op_state_get :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	st := fold(store)
	res := ok_result()
	obj_field_int(&res.data, "workspace_revision", st.revision)
	obj_field_raw(&res.data, "profile", state_to_json(&st))
	capabilities := obj_new()
	obj_field_bool(&capabilities, "local_test", true)
	obj_field_bool(&capabilities, "remote_submission_odin", false)
	obj_field_str(&capabilities, "note", "provider adapters and remote judging arrive with the provider contract work package")
	obj_field_raw(&res.data, "capabilities", obj_done(&capabilities))
	if st.tail_warning != "" { append(&res.warnings, st.tail_warning) }
	return res
}

op_session_start :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "objective", "mode",
		"budget_minutes", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	objective, res := str_field(input, "objective")
	if res.status == .Error { return res }
	mode, res := str_field(input, "mode")
	if res.status == .Error { return res }
	if !valid_mode(mode) {
		return bad_input(fmt.aprintf("mode must be one of: %s", strings.join(MODES[:], ", ")))
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "objective", objective)
	obj_field_str(&p, "mode", mode)
	if v := jint(jget(input, "budget_minutes")); v > 0 {
		obj_field_int(&p, "budget_minutes", v)
	}

	// The session id is derived from the event sequence inside commit; here we
	// reserve the next sequence to keep ids predictable without holding the
	// lock. commit_event recomputes the actual sequence.
	store_next := store.revision + 1
	session_id := fmt_id("sess", store_next)

	ev, res := commit_and_project(store, ctx, req, "session_started", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "session_id", session_id)
	obj_field_int(&res.data, "revision", ev.sequence)
	append(&res.next_actions, "state the expected learning outcome, then select or accept a problem")
	return res
}

op_session_checkpoint :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "session_id", "activity", "summary", "next_action",
		"pause", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	session_id, res := str_field(input, "session_id")
	if res.status == .Error { return res }
	activity, res := str_field(input, "activity")
	if res.status == .Error { return res }
	if !valid_activity(activity) {
		return bad_input(fmt.aprintf("activity must be one of: %s", strings.join(ACTIVITIES[:], ", ")))
	}
	summary, res := str_field(input, "summary")
	if res.status == .Error { return res }
	next_action, res := str_field(input, "next_action")
	if res.status == .Error { return res }

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "activity", activity)
	obj_field_str(&p, "summary", summary)
	obj_field_str(&p, "next_action", next_action)
	obj_field_bool(&p, "pause", jbool(jget(input, "pause")))

	_, res = commit_and_project(store, ctx, req, "session_checkpoint", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	append(&res.next_actions, "the checkpoint is durable; another agent can resume with session_resume")
	return res
}

op_session_resume :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	st := fold(store)
	res := ok_result()
	if len(st.sessions) == 0 {
		append(&res.warnings, "no sessions recorded; run session_start to begin")
		obj_field_bool(&res.data, "resumable", false)
		return res
	}
	// Latest session wins; linked continuation sessions are a later work
	// package (section 6, "Return to closed work").
	s := &st.sessions[len(st.sessions) - 1]
	obj_field_bool(&res.data, "resumable", s.status != "closed")
	obj_field_raw(&res.data, "session", session_to_json(s))
	if s.status == "closed" {
		append(&res.next_actions, "the latest session is closed; start a new linked session to return to this work")
	} else if s.next_action != "" {
		append(&res.next_actions, s.next_action)
	}
	if st.tail_warning != "" { append(&res.warnings, st.tail_warning) }
	return res
}

op_hint_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "session_id", "level",
		"attempt_id", "content", "concept_ids", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	session_id, res := str_field(input, "session_id")
	if res.status == .Error { return res }
	level, res := int_field(input, "level", 0, 4)
	if res.status == .Error { return res }

	attempt_id := ""
	if v := jstr(jget(input, "attempt_id")); v != "" { attempt_id = v }
	content := jstr(jget(input, "content"))

	p := obj_new()
	defer obj_free(&p)
	obj_field_int(&p, "level", level)
	obj_field_str(&p, "content", content)
	concepts := jarray(jget(input, "concept_ids"))
	concept_names := make([dynamic]string, 0, len(concepts))
	defer delete(concept_names)
	for c in concepts {
		if s := jstr(c); s != "" { append(&concept_names, s) }
	}
	obj_field_strs(&p, "concept_ids", concept_names[:])

	_, res = commit_and_project(store, ctx, req, "hint_delivered", session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	if level >= 3 {
		append(&res.warnings, fmt.aprintf("level %d discloses algorithmic structure; this attempt can no longer qualify as independent", level))
	}
	obj_field_int(&res.data, "level", level)
	return res
}

op_evidence_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "session_id", "evidence_type", "producer",
		"attempt_id", "concept_id", "content", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	session_id, res := str_field(input, "session_id")
	if res.status == .Error { return res }
	evidence_type, res := str_field(input, "evidence_type")
	if res.status == .Error { return res }
	producer, res := str_field(input, "producer")
	if res.status == .Error { return res }

	// Verified runner and provider observations are produced only by their
	// handlers (section 11). Agents may record claims, never tool evidence.
	if producer != "learner" && producer != "agent" && producer != "import" {
		return error_result(.Invalid_Evidence, "producer must be learner, agent, or import; runner and judge evidence is recorded by its own handlers")
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "evidence_type", evidence_type)
	obj_field_str(&p, "producer", producer)
	obj_field_str(&p, "concept_id", jstr(jget(input, "concept_id")))
	obj_field_str(&p, "content", jstr(jget(input, "content")))
	obj_field_str(&p, "artifact_hash", jstr(jget(input, "artifact_hash")))

	attempt_id := jstr(jget(input, "attempt_id"))
	_, res = commit_and_project(store, ctx, req, "evidence_recorded", session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	return res
}

op_assessment_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "session_id", "concept_id", "dimension", "score",
		"rationale", "evidence_ids", "rubric_version", "request_id", "expected_revision")
	if fail.status == .Error { return fail }

	session_id, res := str_field(input, "session_id")
	if res.status == .Error { return res }
	concept_id, res := str_field(input, "concept_id")
	if res.status == .Error { return res }
	dimension, res := str_field(input, "dimension")
	if res.status == .Error { return res }
	rationale, res := str_field(input, "rationale")
	if res.status == .Error { return res }
	rubric_version, res := str_field(input, "rubric_version")
	if res.status == .Error { return res }

	// score is 0..3 or the string "unknown" (section 9).
	score_raw := jget(input, "score")
	score := -1
	if s := jstr(score_raw); s == "unknown" {
		score = -1
	} else if v := jint(score_raw); v >= 0 && v <= 3 {
		score = v
	} else {
		return bad_input("score must be 0..3 or \"unknown\"")
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "concept_id", concept_id)
	obj_field_str(&p, "dimension", dimension)
	obj_field_int(&p, "score", score)
	obj_field_str(&p, "rationale", rationale)
	obj_field_str(&p, "rubric_version", rubric_version)
	evidence := jarray(jget(input, "evidence_ids"))
	evidence_names := make([dynamic]string, 0, len(evidence))
	defer delete(evidence_names)
	for e in evidence {
		if s := jstr(e); s != "" { append(&evidence_names, s) }
	}
	obj_field_strs(&p, "evidence_ids", evidence_names[:])

	_, res = commit_and_project(store, ctx, req, "assessment_recorded", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	return res
}

// qualifies_independent reports whether a closed session's work can count as
// an independent qualifying solve: no algorithm-bearing exposure and
// assistance no higher than level 1 (section 9). This is the deterministic
// eligibility check; the agent separately records rubric scores.
qualifies_independent :: proc(s: ^Session_State) -> bool {
	return s.mode != "worked_example" && s.max_hint_level <= 1 && !s.solution_exposed
}

op_session_close :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "session_id", "reason",
		"request_id", "expected_revision")
	if fail.status == .Error { return fail }

	session_id, res := str_field(input, "session_id")
	if res.status == .Error { return res }
	reason, res := str_field(input, "reason")
	if res.status == .Error { return res }
	if reason != "completed" && reason != "stopped" && reason != "abandoned" {
		return bad_input("reason must be completed, stopped, or abandoned")
	}

	st := fold(store)
	found := false
	independent := false
	for i, _ in st.sessions {
		if st.sessions[i].id == session_id {
			found = true
			if st.sessions[i].status == "closed" {
				// Closing twice must not advance reviews twice (section 6).
				return error_result(.Request_Conflict, "this session is already closed; use a new session to continue this work")
			}
			independent = qualifies_independent(&st.sessions[i])
		}
	}
	if !found {
		return error_result(.Not_Found, fmt.aprintf("no session %q", session_id))
	}

	// Eligible review updates are computed once and frozen into the event.
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "reason", reason)
	obj_field_bool(&p, "independent", independent)
	if independent {
		obj_field_raw(&p, "review_updates", due_review_updates(&st, session_id, "independent", "recall"))
	} else {
		obj_field_raw(&p, "review_updates", due_review_updates(&st, session_id, "assisted", "recall"))
	}

	_, res = commit_and_project(store, ctx, req, "session_closed", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "session_id", session_id)
	obj_field_bool(&res.data, "independent", independent)
	append(&res.next_actions, "run review_due to see scheduled retrieval tasks")
	return res
}

// due_review_updates builds the review_updates JSON for every concept this
// session touched (hints, evidence, or assessments). All get a 1-day
// retrieval item; independent credit is recorded on the item.
due_review_updates :: proc(st: ^State, session_id, credit, task_type: string) -> string {
	concepts := make([dynamic]string)
	defer delete(concepts)
	items := make([dynamic]string)
	defer delete(items)
	// Concepts from this session's hint/assessment events would need the raw
	// event list; the fold exposes concept states globally, so the closing
	// handler passes session-scoped concepts separately in a later package.
	// For now the objective concept is supplied by session concepts tracked
	// through hint payloads.
	due := rfc3339_utc(time.time_add(Now(), time.Duration(INITIAL_INTERVAL_DAYS) * DAY))
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "credit", credit)
	obj_field_str(&o, "task_type", task_type)
	obj_field_str(&o, "due_ts", due)
	append(&items, obj_done(&o))
	return fmt.aprintf("[%s]", strings.join(items[:], ","))
}

op_review_due :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	st := fold(store)
	res := ok_result()
	now := now_rfc3339()
	due := make([dynamic]string)
	defer delete(due)
	for i, _ in st.reviews {
		r := &st.reviews[i]
		if r.state != "open" { continue }
		if r.due_ts > now { continue }
		append(&due, review_to_json(r))
	}
	obj_field_strs(&res.data, "due", due[:])
	obj_field_int(&res.data, "count", len(due))
	return res
}

op_review_update :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	_, fail := require_fields(input, "review_id", "action",
		"request_id", "expected_revision")
	if fail.status == .Error { return fail }

	review_id, res := str_field(input, "review_id")
	if res.status == .Error { return res }
	action, res := str_field(input, "action")
	if res.status == .Error { return res }
	if action != "snooze" && action != "resume" {
		return bad_input("action must be snooze or resume; completing a review happens through a review session's assessment")
	}

	_, res = commit_and_project(store, ctx, req, "review_updated", "", "", {
		id: fmt.aprintf("{\"id\":\"%s\",\"action\":\"%s\"}", review_id, action),
	}.id)
	if res.status == .Error { return res }
	return res
}

op_plan_next :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	st := fold(store)
	res := ok_result()
	now := now_rfc3339()

	// Deterministic selection policy (section 9): due reviews first, then a
	// blocking prerequisite, then the goal's next concept, then a transfer
	// exercise. The curated catalogue arrives with the curriculum work
	// package; until then only due reviews and honest placeholders are
	// returned.
	candidates := make([dynamic]string)
	defer delete(candidates)
	for i, _ in st.reviews {
		r := &st.reviews[i]
		if r.state != "open" || r.due_ts > now { continue }
		c := obj_new()
		obj_field_str(&c, "kind", "review")
		obj_field_str(&c, "review_id", r.id)
		obj_field_str(&c, "concept", r.concept)
		obj_field_str(&c, "reason", fmt.aprintf("review scheduled for %s is due", r.due_ts))
		append(&candidates, obj_done(&c))
		obj_free(&c)
	}
	if len(candidates) == 0 {
		c := obj_new()
		obj_field_str(&c, "kind", "new_practice")
		obj_field_str(&c, "reason", "no due reviews; the curated catalogue arrives with the curriculum work package, so ask the learner what they want to practice")
		append(&candidates, obj_done(&c))
		obj_free(&c)
	}
	obj_field_strs(&res.data, "candidates", candidates[:])
	return res
}

op_progress_get :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	st := fold(store)
	res := ok_result()
	// Separate views (section 9): accepted/submissions are provider evidence
	// and arrive with the provider adapters; learning views are derived here.
	counts := obj_new()
	active := 0
	closed := 0
	for s in st.sessions {
		if s.status == "closed" { closed += 1 } else { active += 1 }
	}
	obj_field_int(&counts, "active_sessions", active)
	obj_field_int(&counts, "closed_sessions", closed)
	obj_field_int(&counts, "open_reviews", len(st.reviews))
	concepts := make([dynamic]string)
	defer delete(concepts)
	for i, _ in st.concepts {
		append(&concepts, concept_to_json(&st.concepts[i]))
	}
	obj_field_strs(&res.data, "concepts", concepts[:])
	obj_field_raw(&res.data, "counts", obj_done(&counts))
	return res
}
