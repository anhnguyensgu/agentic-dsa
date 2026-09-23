package learning

// Operation registry and handlers (section 11 of AGENTIC_LEARNING.md).
//
// The CLI and native MCP server call the same handlers. Handlers are
// deterministic: they fold committed events into a projection and append new
// events. Verified runner/judge observations are only produced by their own
// handlers; agent-proposed judgments go through assessment_record.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

Context :: struct {
	workspace: string,
	actor:     string, // "agent:<host>" | "learner" | "tool"
	host:      string,
	now:       time.Time,
}

context_now :: proc(ctx: ^Context) -> time.Time {
	if ctx.now != (time.Time{}) { return ctx.now }
	return time.now()
}

Handler :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result

Operation :: struct {
	name:     string,
	handler:  Handler,
	mutating: bool,
}

operations := []Operation{
	{name = "workspace_init",      handler = op_workspace_init,      mutating = true},
	{name = "doctor",              handler = op_doctor,              mutating = false},
	{name = "profile_update",      handler = op_profile_update,      mutating = true},
	{name = "state_get",           handler = op_state_get,           mutating = false},
	{name = "problem_search",      handler = op_problem_search,      mutating = false},
	{name = "problem_get",         handler = op_problem_get,         mutating = false},
	{name = "session_start",       handler = op_session_start,       mutating = true},
	{name = "attempt_start",       handler = op_attempt_start,       mutating = true},
	{name = "case_add",            handler = op_case_add,            mutating = true},
	{name = "test_run",            handler = op_test_run,            mutating = true},
	{name = "submission_prepare",  handler = op_submission_prepare,  mutating = true},
	{name = "submission_send",     handler = op_submission_send,     mutating = true},
	{name = "job_check",           handler = op_job_check,           mutating = true},
	{name = "session_checkpoint",  handler = op_session_checkpoint,  mutating = true},
	{name = "session_resume",      handler = op_session_resume,      mutating = false},
	{name = "hint_record",         handler = op_hint_record,         mutating = true},
	{name = "evidence_record",     handler = op_evidence_record,     mutating = true},
	{name = "assessment_record",   handler = op_assessment_record,   mutating = true},
	{name = "session_close",       handler = op_session_close,       mutating = true},
	{name = "review_due",          handler = op_review_due,          mutating = false},
	{name = "review_update",       handler = op_review_update,       mutating = true},
	{name = "plan_next",           handler = op_plan_next,           mutating = false},
	{name = "progress_get",        handler = op_progress_get,        mutating = false},
	{name = "export_create",       handler = op_export_create,       mutating = true},
	{name = "import_validate",     handler = op_import_validate,     mutating = false},
	{name = "import_apply",        handler = op_import_apply,        mutating = true},
	{name = "data_delete",         handler = op_data_delete,         mutating = true},
}

run_operation :: proc(name: string, ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> (Result, bool) {
	for op in operations {
		if op.name == name {
			return op.handler(ctx, store, input, req), true
		}
	}
	return error_result(.Not_Found, fmt.aprintf("unknown operation %q", name)), false
}

// -- result helpers -----------------------------------------------------------

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

// Input getters thread the first error through a Result so handlers read
// linearly. A failing getter marks `res` as an error result.
get_str :: proc(input: json.Value, key: string, res: ^Result) -> string {
	if res.status == .Error { return "" }
	s := jstr(jget(input, key))
	if s == "" {
		res^ = bad_input(fmt.aprintf("field %q must be a non-empty string", key))
		return ""
	}
	return s
}

get_int :: proc(input: json.Value, key: string, lo, hi: int, res: ^Result) -> int {
	if res.status == .Error { return 0 }
	n := jint(jget(input, key))
	if n < lo || n > hi {
		res^ = bad_input(fmt.aprintf("field %q must be between %d and %d", key, lo, hi))
		return 0
	}
	return n
}

// get_strs returns nil on absence; empty entries are an error.
get_strs :: proc(input: json.Value, key: string, res: ^Result) -> [dynamic]string {
	out := make([dynamic]string)
	if res.status == .Error { return out }
	arr := jarray(jget(input, key))
	for v in arr {
		s := jstr(v)
		if s == "" {
			delete(out)
			res^ = bad_input(fmt.aprintf("field %q must contain non-empty strings", key))
			return make([dynamic]string)
		}
		append(&out, s)
	}
	return out
}

get_opt_str :: proc(input: json.Value, key: string) -> string {
	return jstr(jget(input, key))
}

get_opt_bool :: proc(input: json.Value, key: string) -> bool {
	return jbool(jget(input, key))
}

// require_fields rejects unexpected fields (section 11) and enforces that
// required keys are present. The mutation envelope keys are allowed on every
// operation; the CLI injects them.
require_fields :: proc(input: json.Value, required, optional: []string) -> Result {
	if _, is_obj := input.(json.Object); !is_obj {
		return bad_input("input must be a JSON object")
	}
	allowed := make([dynamic]string, 0, len(optional) + 2)
	defer delete(allowed)
	for o in optional { append(&allowed, o) }
	append(&allowed, "request_id", "expected_revision")
	if !check_keys(input, required, allowed[:]) {
		return bad_input("input contains unexpected fields")
	}
	for key in required {
		if jget(input, key) == nil {
			return bad_input(fmt.aprintf("field %q is required", key))
		}
	}
	return ok_result()
}

// -- projection (section 10: replaceable, rebuilt from events) ----------------

Profile :: struct {
	initialized:         bool,
	learner_id:          string,
	goal:                string,
	language:            string,
	timezone:            string,
	experience:          string,
	explanation_language: string,
	teaching_preferences: string,
	authorization_policy: string,
	time_budget_minutes: int,
}

Session_State :: struct {
	id:                     string,
	objective:              string,
	mode:                   string,
	status:                 string, // active | paused | closed
	activity:               string, // understanding | planning | implementing | testing | reflecting | reviewing
	next_action:            string,
	summary:                string,
	closure_reason:         string, // completed | stopped | abandoned
	review_updates_applied: bool,
	max_hint_level:         int,
	solution_exposed:       bool,
	concepts:               [dynamic]string,
	current_attempt_id:     string,
	review_item_id:         string,
	has_fresh_attempt:      bool,
	verified_behavior:      bool,
	verified_source_hash:   string,
	agent_authored_algorithm: bool,
	approach_score3:        bool,
	correctness_score3:     bool,
	complexity_score3:      bool,
	independent_qualified:  bool,
	transfer_score3:        bool,
	started_ts:             string,
	closed_ts:              string,
}

Attempt_State :: struct {
	id:               string,
	session_id:       string,
	problem_key:      string,
	language:         string,
	source_path:      string,
	source_hash:      string,
	runner_kind:      string,
	previous_attempt_id: string,
	fresh:            bool,
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
	concept_id:        string,
	state:             string, // unknown | introduced | practicing | independent | retained
	independent_solves: int,
	assessments:       int,
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

note_concept :: proc(concepts: ^[dynamic]string, concept: string) {
	if concept == "" { return }
	for c in concepts {
		if c == concept { return }
	}
	append(concepts, concept)
}

concept_index :: proc(st: ^State, concept: string) -> int {
	if concept == "" { return -1 }
	for _, i in st.concepts {
		if st.concepts[i].concept_id == concept { return i }
	}
	append(&st.concepts, Concept_State{concept_id = concept, state = "introduced"})
	return len(st.concepts) - 1
}

fold :: proc(store: ^Store) -> State {
	st := State{workspace_id = store.workspace_id, revision = store.revision}
	for ev in store.events {
		payload, perr := json.parse(ev.payload, .JSON, parse_integers = true)
		if perr != nil { continue }
		switch ev.type {
		case "workspace_initialized":
			st.profile = Profile{
				initialized         = true,
				learner_id          = jstr(jget(payload, "learner_id")),
				goal                = jstr(jget(payload, "goal")),
				language            = jstr(jget(payload, "language")),
				timezone            = jstr(jget(payload, "timezone")),
				experience          = jstr(jget(payload, "experience")),
				explanation_language = jstr(jget(payload, "explanation_language")),
				teaching_preferences = jstr(jget(payload, "teaching_preferences")),
				authorization_policy = jstr(jget(payload, "authorization_policy")),
				time_budget_minutes = jint(jget(payload, "time_budget_minutes")),
			}
		case "profile_updated":
			st.profile.learner_id = jstr(jget(payload, "learner_id"))
			st.profile.goal = jstr(jget(payload, "goal"))
			st.profile.language = jstr(jget(payload, "language"))
			st.profile.timezone = jstr(jget(payload, "timezone"))
			st.profile.experience = jstr(jget(payload, "experience"))
			st.profile.explanation_language = jstr(jget(payload, "explanation_language"))
			st.profile.teaching_preferences = jstr(jget(payload, "teaching_preferences"))
			st.profile.authorization_policy = jstr(jget(payload, "authorization_policy"))
			st.profile.time_budget_minutes = jint(jget(payload, "time_budget_minutes"))
		case "session_started":
			s := Session_State{
				id        = ev.session_id,
				objective = jstr(jget(payload, "objective")),
				mode      = jstr(jget(payload, "mode")),
					status    = "active",
						activity  = "understanding",
						review_item_id = jstr(jget(payload, "review_item_id")),
						started_ts = ev.timestamp,
			}
			for c in jarray(jget(payload, "concept_ids")) {
				note_concept(&s.concepts, jstr(c))
			}
				append(&st.sessions, s)
		case "attempt_started":
			a := Attempt_State{
				id                  = ev.attempt_id,
				session_id          = ev.session_id,
				problem_key         = jstr(jget(payload, "problem_key")),
				language            = jstr(jget(payload, "language")),
				source_path         = jstr(jget(payload, "source_path")),
				source_hash         = jstr(jget(payload, "source_hash")),
				runner_kind         = jstr(jget(payload, "runner_kind")),
				previous_attempt_id = jstr(jget(payload, "previous_attempt_id")),
				fresh               = jbool(jget(payload, "fresh")),
				status              = "active",
			}
			append(&st.attempts, a)
			for _, i in st.sessions {
				if st.sessions[i].id == ev.session_id {
					st.sessions[i].current_attempt_id = ev.attempt_id
					st.sessions[i].has_fresh_attempt = a.fresh
				}
			}
		case "session_checkpoint":
			for _, i in st.sessions {
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
				for _, i in st.sessions {
					if st.sessions[i].id == ev.session_id {
						reason := jstr(jget(payload, "reason"))
						st.sessions[i].status = "paused" if reason == "stopped" else "closed"
						st.sessions[i].closure_reason = reason
						st.sessions[i].independent_qualified = jbool(jget(payload, "independent"))
						st.sessions[i].closed_ts = ev.timestamp
					// Review updates were computed once by the closing
					// handler and are frozen in the event payload, so
					// re-folding never applies them twice (section 6:
					// "Repeated closure cannot advance a review twice").
						for u, ui in jarray(jget(payload, "review_updates")) {
							if jstr(jget(u, "action")) == "update" {
								target := jstr(jget(u, "id"))
								for _, ri in st.reviews {
									if st.reviews[ri].id == target {
										st.reviews[ri].interval_index = jint(jget(u, "interval_index"))
										st.reviews[ri].due_ts = jstr(jget(u, "due_ts"))
										st.reviews[ri].last_outcome = jstr(jget(u, "last_outcome"))
										st.reviews[ri].state = jstr(jget(u, "state"))
									}
								}
								continue
							}
							append(&st.reviews, Review_Item{
							id                = fmt.aprintf("rev_%06d_%d", ev.sequence, ui),
							concept           = jstr(jget(u, "concept")),
							task_type         = jstr(jget(u, "task_type")),
							origin_session_id = ev.session_id,
							state             = "open",
							credit            = jstr(jget(u, "credit")),
							interval_index    = 0,
							due_ts            = jstr(jget(u, "due_ts")),
						})
					}
				}
			}
		case "hint_delivered":
			level := jint(jget(payload, "level"))
			for _, i in st.sessions {
				if st.sessions[i].id == ev.session_id {
					st.sessions[i].max_hint_level = max(st.sessions[i].max_hint_level, level)
					if level >= 4 { st.sessions[i].solution_exposed = true }
					for c in jarray(jget(payload, "concept_ids")) {
						note_concept(&st.sessions[i].concepts, jstr(c))
					}
				}
			}
			for _, i in st.attempts {
				if st.attempts[i].id == ev.attempt_id {
					st.attempts[i].hint_count += 1
					st.attempts[i].max_hint_level = max(st.attempts[i].max_hint_level, level)
					if level >= 4 { st.attempts[i].solution_exposed = true }
				}
			}
		case "evidence_recorded":
			concept_index(&st, jstr(jget(payload, "concept_id")))
			if jstr(jget(payload, "producer")) == "agent" && jstr(jget(payload, "evidence_type")) == "algorithm_code_change" {
				for _, i in st.sessions {
					if st.sessions[i].id == ev.session_id { st.sessions[i].agent_authored_algorithm = true }
				}
			}
			case "runner_observed":
			verified := jint(jget(payload, "verified_passed")) > 0 &&
			            jint(jget(payload, "verified_failed")) == 0 &&
			            jint(jget(payload, "unchecked")) == 0 &&
			            jstr(jget(payload, "source_hash")) != ""
			for _, i in st.sessions {
				if st.sessions[i].id == ev.session_id && st.sessions[i].current_attempt_id == ev.attempt_id {
					st.sessions[i].verified_behavior = verified
						st.sessions[i].verified_source_hash = jstr(jget(payload, "source_hash"))
					}
				}
			case "job_observed":
				verdict := strings.to_lower(jstr(jget(payload, "verdict")))
				verified := jstr(jget(payload, "state")) == "terminal" && verdict == "accepted" && jstr(jget(payload, "source_hash")) != ""
				if verified {
					for _, i in st.sessions {
						if st.sessions[i].id == ev.session_id && st.sessions[i].current_attempt_id == ev.attempt_id {
							st.sessions[i].verified_behavior = true
							st.sessions[i].verified_source_hash = jstr(jget(payload, "source_hash"))
						}
					}
				}
		case "assessment_recorded":
			ci := concept_index(&st, jstr(jget(payload, "concept_id")))
			st.concepts[ci].assessments += 1
			if jint(jget(payload, "score")) >= 1 {
				st.concepts[ci].state = "practicing"
			}
			for _, i in st.sessions {
				if st.sessions[i].id == ev.session_id {
					note_concept(&st.sessions[i].concepts, jstr(jget(payload, "concept_id")))
					if jint(jget(payload, "score")) == 3 && len(jarray(jget(payload, "evidence_ids"))) > 0 {
						switch jstr(jget(payload, "dimension")) {
						case "approach", "approach_invariant": st.sessions[i].approach_score3 = true
						case "correctness": st.sessions[i].correctness_score3 = true
							case "complexity": st.sessions[i].complexity_score3 = true
							case "transfer": st.sessions[i].transfer_score3 = true
						}
					}
				}
			}
		case "review_updated":
			target := jstr(jget(payload, "id"))
			for _, i in st.reviews {
				if st.reviews[i].id == target {
						if jstr(jget(payload, "action")) == "snooze" {
							st.reviews[i].state = "snoozed"
							if until := jstr(jget(payload, "until")); until != "" { st.reviews[i].due_ts = until }
					} else {
						st.reviews[i].state = "open"
					}
				}
			}
		}
	}
	// Concept promotion: a completed session whose work qualifies as an
	// independent qualifying solve promotes its concepts (section 9).
		for _, i in st.sessions {
		s := &st.sessions[i]
		if s.status != "closed" { continue }
			if s.closure_reason == "completed" && s.independent_qualified {
			for c in s.concepts {
				ci := concept_index(&st, c)
				st.concepts[ci].independent_solves += 1
				st.concepts[ci].state = "independent"
			}
		} else {
			for c in s.concepts {
				ci := concept_index(&st, c)
				if st.concepts[ci].state == "introduced" {
					st.concepts[ci].state = "practicing"
				}
			}
			}
		}
		// Retained understanding needs distinct qualifying problems, an
		// observed transfer dimension, and an independent delayed retrieval.
		for _, ci in st.concepts {
			concept := &st.concepts[ci]
			problem_keys := make([dynamic]string)
			transfer_found, delayed_found := false, false
			for &session in st.sessions {
				if !session.independent_qualified { continue }
				touches := false
				for c in session.concepts { if c == concept.concept_id { touches = true; break } }
				if !touches { continue }
				problem_key := ""
				for attempt in st.attempts { if attempt.id == session.current_attempt_id { problem_key = attempt.problem_key; break } }
				if problem_key != "" {
					seen := false
					for key in problem_keys { if key == problem_key { seen = true; break } }
					if !seen { append(&problem_keys, problem_key) }
				}
				if session.transfer_score3 { transfer_found = true }
				if session.mode == "review" && session.review_item_id != "" {
					origin_session_id := ""
					for review in st.reviews { if review.id == session.review_item_id { origin_session_id = review.origin_session_id; break } }
					for origin in st.sessions {
						if origin.id != origin_session_id || origin.closed_ts == "" || session.closed_ts == "" { continue }
						origin_time, origin_consumed := time.rfc3339_to_time_utc(origin.closed_ts)
						review_time, review_consumed := time.rfc3339_to_time_utc(session.closed_ts)
						if origin_consumed > 0 && review_consumed > 0 && time.diff(origin_time, review_time) >= 3 * DAY { delayed_found = true }
					}
				}
			}
			concept.independent_solves = len(problem_keys)
			if len(problem_keys) >= 2 && transfer_found && delayed_found { concept.state = "retained" }
			delete(problem_keys)
		}
		return st
}

// qualifies_independent reports whether a closed session's work can count as
// an independent qualifying solve: no algorithm-bearing exposure and
// assistance no higher than level 1 (section 9). This is the deterministic
// eligibility gate; the agent separately records rubric scores.
qualifies_independent :: proc(st: ^State, s: ^Session_State, workspace := "") -> bool {
	mode_ok := s.mode == "independent" || s.mode == "assessment" || s.mode == "review"
	source_current := s.verified_source_hash != ""
	if source_current && workspace != "" {
		source_current = false
		for attempt in st.attempts {
			if attempt.id != s.current_attempt_id { continue }
			current_hash, err := read_source_hash(join({workspace, attempt.source_path}))
			source_current = err == .None && current_hash == s.verified_source_hash
			break
		}
	}
	return mode_ok && s.has_fresh_attempt && s.verified_behavior && source_current &&
	       s.approach_score3 && s.correctness_score3 && s.complexity_score3 &&
	       s.max_hint_level <= 1 && !s.solution_exposed && !s.agent_authored_algorithm
}

// -- projection serialization ---------------------------------------------------

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
	obj_field_str(&o, "current_attempt_id", s.current_attempt_id)
	obj_field_str(&o, "review_item_id", s.review_item_id)
	obj_field_bool(&o, "verified_behavior", s.verified_behavior)
	obj_field_str(&o, "verified_source_hash", s.verified_source_hash)
	obj_field_bool(&o, "independent_qualified", s.independent_qualified)
	obj_field_bool(&o, "transfer_score3", s.transfer_score3)
	obj_field_str(&o, "started_ts", s.started_ts)
	obj_field_str(&o, "closed_ts", s.closed_ts)
	obj_field_strs(&o, "concepts", s.concepts[:])
	return obj_done(&o)
}

attempt_to_json :: proc(a: ^Attempt_State) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "id", a.id)
	obj_field_str(&o, "session_id", a.session_id)
	obj_field_str(&o, "problem_key", a.problem_key)
	obj_field_str(&o, "language", a.language)
	obj_field_str(&o, "source_path", a.source_path)
	obj_field_str(&o, "source_hash", a.source_hash)
	obj_field_str(&o, "runner_kind", a.runner_kind)
	obj_field_str(&o, "previous_attempt_id", a.previous_attempt_id)
	obj_field_bool(&o, "fresh", a.fresh)
	obj_field_str(&o, "status", a.status)
	obj_field_int(&o, "hint_count", a.hint_count)
	obj_field_int(&o, "max_hint_level", a.max_hint_level)
	obj_field_bool(&o, "solution_exposed", a.solution_exposed)
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

profile_to_json :: proc(p: ^Profile) -> string {
	o := obj_new()
	defer obj_free(&o)
	if p.initialized {
		obj_field_str(&o, "learner_id", p.learner_id)
		obj_field_str(&o, "goal", p.goal)
		obj_field_str(&o, "language", p.language)
		obj_field_str(&o, "timezone", p.timezone)
		obj_field_str(&o, "experience", p.experience)
		obj_field_str(&o, "explanation_language", p.explanation_language)
		obj_field_str(&o, "teaching_preferences", p.teaching_preferences)
		obj_field_str(&o, "authorization_policy", p.authorization_policy)
		obj_field_int(&o, "time_budget_minutes", p.time_budget_minutes)
	}
	return obj_done(&o)
}

state_to_json :: proc(st: ^State) -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_int(&o, "schema_version", SCHEMA_VERSION)
	obj_field_str(&o, "workspace_id", st.workspace_id)
	obj_field_int(&o, "revision", st.revision)
	obj_field_raw(&o, "profile", profile_to_json(&st.profile))

	sessions := make([dynamic]string)
	defer delete(sessions)
	for _, i in st.sessions { append(&sessions, session_to_json(&st.sessions[i])) }
	obj_field_raws(&o, "sessions", sessions[:])
	attempts := make([dynamic]string)
	defer delete(attempts)
	for _, i in st.attempts { append(&attempts, attempt_to_json(&st.attempts[i])) }
	obj_field_raws(&o, "attempts", attempts[:])

	reviews := make([dynamic]string)
	defer delete(reviews)
	for _, i in st.reviews { append(&reviews, review_to_json(&st.reviews[i])) }
	obj_field_raws(&o, "reviews", reviews[:])

	concepts := make([dynamic]string)
	defer delete(concepts)
	for _, i in st.concepts { append(&concepts, concept_to_json(&st.concepts[i])) }
	obj_field_raws(&o, "concepts", concepts[:])
	return obj_done(&o)
}

// write_state atomically replaces the projection. A missing or stale
// projection is rebuilt by replay; it is never the source of truth.
write_state :: proc(workspace: string, st: ^State) -> Engine_Error {
	if werr := write_private_file(state_path(workspace), state_to_json(st)); werr != nil {
		fmt.eprintln("algolearn: failed to write projection:", os.error_string(werr))
		return .Storage_Error
	}
	return .None
}

engine_error_message :: proc(err: Engine_Error) -> string {
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

// commit_and_project appends the event and refreshes the projection.
commit_and_project :: proc(store: ^Store, ctx: ^Context, req: Request, ev_type, session_id, attempt_id: string, payload: string) -> (Event, Result) {
	res := ok_result()
	ev, err, replayed := commit_event(store, ev_type, ctx.actor, req, session_id, attempt_id, payload)
	if err != .None {
		return ev, error_result(err, engine_error_message(err))
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

// -- handlers -----------------------------------------------------------------

MODES := [?]string{"guided", "independent", "assessment", "review", "worked_example"}

valid_mode :: proc(m: string) -> bool {
	for accepted in MODES { if accepted == m { return true } }
	return false
}

ACTIVITIES := [?]string{"understanding", "planning", "implementing", "testing", "reflecting", "reviewing"}

valid_activity :: proc(a: string) -> bool {
	for accepted in ACTIVITIES { if accepted == a { return true } }
	return false
}

enum_list :: proc(values: []string) -> string {
	return strings.join(values, ", ")
}

has_legacy_config :: proc(ws: string) -> bool {
	_, lerr := os.stat(join({ws, ".algo", "config.json"}), context.allocator)
	return lerr == nil
}

op_workspace_init :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"goal", "language", "timezone", "experience", "time_budget_minutes"}, {"learner_id", "explanation_language", "teaching_preferences", "authorization_policy", "import_legacy"}); fail.status == .Error {
		return fail
	}
	if _, ferr := os.stat(manifest_path(ctx.workspace), context.allocator); ferr == nil {
		return error_result(.Destination_Exists, engine_error_message(.Destination_Exists))
	}
	if derr := ensure_dirs(ctx.workspace); derr != nil {
		return error_result(.Storage_Error, fmt.aprintf("could not create learning directories: %s", os.error_string(derr)))
	}

	res := ok_result()
	goal := get_str(input, "goal", &res)
	language := get_str(input, "language", &res)
	timezone := get_str(input, "timezone", &res)
	experience := get_str(input, "experience", &res)
	budget := get_int(input, "time_budget_minutes", 5, 480, &res)
	if res.status == .Error { return res }

	p := obj_new()
	defer obj_free(&p)
	learner_id := get_opt_str(input, "learner_id")
	if learner_id == "" { learner_id = "learner_local" }
	explanation_language := get_opt_str(input, "explanation_language")
	if explanation_language == "" { explanation_language = "auto" }
	authorization_policy := get_opt_str(input, "authorization_policy")
	if authorization_policy == "" { authorization_policy = "ask" }
	obj_field_str(&p, "learner_id", learner_id)
	obj_field_str(&p, "goal", goal)
	obj_field_str(&p, "language", language)
	obj_field_str(&p, "timezone", timezone)
	obj_field_str(&p, "experience", experience)
	obj_field_str(&p, "explanation_language", explanation_language)
	obj_field_str(&p, "teaching_preferences", get_opt_str(input, "teaching_preferences"))
	obj_field_str(&p, "authorization_policy", authorization_policy)
	obj_field_int(&p, "time_budget_minutes", budget)

	ev, commit_res := commit_and_project(store, ctx, req, "workspace_initialized", "", "", obj_done(&p))
	if commit_res.status == .Error { return commit_res }
	res = commit_res

	if has_legacy_config(ctx.workspace) {
		// Legacy data is preserved untouched; importing it is explicit
		// (section 10, "Legacy .algo import").
		append(&res.warnings, "legacy .algo/config.json detected; it is preserved and can be imported with import_validate")
	}
	workspace_id := ev.workspace_id
	if workspace_id == "" {
		workspace_id = fmt.aprintf("ws_%s", hash_hex(ctx.workspace)[:24])
	}

	// The manifest marks the workspace initialized and pins the versions;
	// doctor reads it and re-init is refused on its existence.
	m := obj_new()
	defer obj_free(&m)
	obj_field_int(&m, "schema_version", SCHEMA_VERSION)
	obj_field_str(&m, "engine_version", ENGINE_VERSION)
	obj_field_str(&m, "workspace_id", workspace_id)
	obj_field_str(&m, "created", ev.timestamp)
	if merr := write_private_file(manifest_path(ctx.workspace), obj_done(&m)); merr != nil {
		return error_result(.Storage_Error, "workspace initialized but the manifest could not be written")
	}
	obj_field_str(&res.data, "workspace_id", workspace_id)
	obj_field_int(&res.data, "revision", ev.sequence)
	append(&res.next_actions, "run plan_next to choose a first objective, or session_start to begin practicing")
	return res
}

op_profile_update :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"learner_id", "goal", "language", "timezone", "experience", "explanation_language", "teaching_preferences", "authorization_policy", "time_budget_minutes"}); fail.status == .Error {
		return fail
	}
	obj, _ := input.(json.Object)
	field_count := 0
	for key in obj { if key != "request_id" && key != "expected_revision" { field_count += 1 } }
	if field_count == 0 {
		return bad_input("profile_update requires at least one preference field")
	}
	st := fold(store)
	if !st.profile.initialized { return error_result(.Not_Found, "initialize the workspace before updating its profile") }
	p := st.profile
	if v := get_opt_str(input, "learner_id"); v != "" { p.learner_id = v }
	if v := get_opt_str(input, "goal"); v != "" { p.goal = v }
	if v := get_opt_str(input, "language"); v != "" { p.language = v }
	if v := get_opt_str(input, "timezone"); v != "" { p.timezone = v }
	if v := get_opt_str(input, "experience"); v != "" { p.experience = v }
	if v := get_opt_str(input, "explanation_language"); v != "" { p.explanation_language = v }
	if jget(input, "teaching_preferences") != nil { p.teaching_preferences = get_opt_str(input, "teaching_preferences") }
	if v := get_opt_str(input, "authorization_policy"); v != "" { p.authorization_policy = v }
	if jget(input, "time_budget_minutes") != nil {
		budget := jint(jget(input, "time_budget_minutes"))
		if budget < 5 || budget > 480 { return bad_input("time_budget_minutes must be between 5 and 480") }
		p.time_budget_minutes = budget
	}
	payload := obj_new()
	defer obj_free(&payload)
	obj_field_str(&payload, "learner_id", p.learner_id)
	obj_field_str(&payload, "goal", p.goal)
	obj_field_str(&payload, "language", p.language)
	obj_field_str(&payload, "timezone", p.timezone)
	obj_field_str(&payload, "experience", p.experience)
	obj_field_str(&payload, "explanation_language", p.explanation_language)
	obj_field_str(&payload, "teaching_preferences", p.teaching_preferences)
	obj_field_str(&payload, "authorization_policy", p.authorization_policy)
	obj_field_int(&payload, "time_budget_minutes", p.time_budget_minutes)
	_, res := commit_and_project(store, ctx, req, "profile_updated", "", "", obj_done(&payload))
	if res.status == .Error { return res }
	obj_field_raw(&res.data, "profile", profile_to_json(&p))
	append(&res.next_actions, "future plans and schedules will use the updated profile")
	return res
}

op_state_get :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"session_id", "detail"}); fail.status == .Error { return fail }
	detail := get_opt_str(input, "detail")
	if detail == "" { detail = "full" }
	if detail != "summary" && detail != "full" { return bad_input("detail must be summary or full") }
	selected_session := get_opt_str(input, "session_id")
	st := fold(store)
	res := ok_result()
	obj_field_int(&res.data, "workspace_revision", st.revision)
	obj_field_raw(&res.data, "profile", profile_to_json(&st.profile))
	sessions := make([dynamic]string)
	defer delete(sessions)
	for _, i in st.sessions {
		if selected_session == "" || st.sessions[i].id == selected_session { append(&sessions, session_to_json(&st.sessions[i])) }
	}
	if selected_session != "" && len(sessions) == 0 { return error_result(.Not_Found, "session does not exist") }
	obj_field_raws(&res.data, "sessions", sessions[:])
	attempts := make([dynamic]string)
	defer delete(attempts)
	if detail == "full" {
		for _, i in st.attempts {
			if selected_session == "" || st.attempts[i].session_id == selected_session { append(&attempts, attempt_to_json(&st.attempts[i])) }
		}
	}
	obj_field_raws(&res.data, "attempts", attempts[:])
	capabilities := obj_new()
	defer obj_free(&capabilities)
	obj_field_bool(&capabilities, "local_test", true)
	obj_field_bool(&capabilities, "kattis_remote_submission_odin", true)
	obj_field_bool(&capabilities, "leetcode_remote_submission_odin", false)
	obj_field_bool(&capabilities, "mcp", true)
	obj_field_str(&capabilities, "note", "current availability is reported by doctor; LeetCode Odin remains local-practice only")
	obj_field_raw(&res.data, "capabilities", obj_done(&capabilities))
	if store.tail_warning != "" { append(&res.warnings, store.tail_warning) }
	return res
}

op_session_start :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"objective", "mode"}, {"concept_ids", "budget_minutes", "problem_key", "review_item_id"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	objective := get_str(input, "objective", &res)
	mode := get_str(input, "mode", &res)
	concepts := get_strs(input, "concept_ids", &res)
	if res.status == .Error { return res }
	defer delete(concepts)
	if !valid_mode(mode) {
		return bad_input(fmt.aprintf("mode must be one of: %s", enum_list(MODES[:])))
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "objective", objective)
	obj_field_str(&p, "mode", mode)
	obj_field_str(&p, "problem_key", get_opt_str(input, "problem_key"))
	obj_field_str(&p, "review_item_id", get_opt_str(input, "review_item_id"))
	if v := jint(jget(input, "budget_minutes")); v > 0 {
		obj_field_int(&p, "budget_minutes", v)
	}
	obj_field_strs(&p, "concept_ids", concepts[:])
	if review_id := get_opt_str(input, "review_item_id"); review_id != "" {
		if mode != "review" { return bad_input("review_item_id may only be used with review mode") }
		st := fold(store)
		found_review := false
		for review in st.reviews { if review.id == review_id && review.state != "completed" { found_review = true } }
		if !found_review { return error_result(.Not_Found, "review_item_id does not name an open or snoozed review") }
	}

	// The sequence used for the id matches commit_event's because ids are
	// minted under the same lock (single writer at a time).
	session_id := fmt_id("sess", store.revision + 1)
	ev, commit_res := commit_and_project(store, ctx, req, "session_started", session_id, "", obj_done(&p))
	if commit_res.status == .Error { return commit_res }
	res = commit_res
	obj_field_str(&res.data, "session_id", session_id)
	obj_field_int(&res.data, "revision", ev.sequence)
	append(&res.next_actions, "state the expected learning outcome, then select or accept a problem")
	return res
}

op_session_checkpoint :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "activity", "summary", "next_action"}, {"pause"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	session_id := get_str(input, "session_id", &res)
	activity := get_str(input, "activity", &res)
	summary := get_str(input, "summary", &res)
	next_action := get_str(input, "next_action", &res)
	if res.status == .Error { return res }
	if !valid_activity(activity) {
		return bad_input(fmt.aprintf("activity must be one of: %s", enum_list(ACTIVITIES[:])))
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "activity", activity)
	obj_field_str(&p, "summary", summary)
	obj_field_str(&p, "next_action", next_action)
	obj_field_bool(&p, "pause", get_opt_bool(input, "pause"))

	_, res = commit_and_project(store, ctx, req, "session_checkpoint", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	if herr := write_session_handoff(store, session_id); herr != .None {
		append(&res.warnings, "checkpoint event was committed but the handoff view could not be written; event replay remains authoritative")
	} else {
		obj_field_str(&res.data, "handoff_json", join({LEARNING_DIR, "sessions", session_id, "handoff.json"}))
		obj_field_str(&res.data, "handoff_markdown", join({LEARNING_DIR, "sessions", session_id, "handoff.md"}))
	}
	append(&res.next_actions, "checkpoint saved; another agent can resume with session_resume")
	return res
}

op_session_resume :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"session_id"}); fail.status == .Error { return fail }
	st := fold(store)
	res := ok_result()
	if len(st.sessions) == 0 {
		obj_field_bool(&res.data, "resumable", false)
		append(&res.warnings, "no sessions recorded; run session_start to begin")
		return res
	}
	si := len(st.sessions) - 1
	if requested := get_opt_str(input, "session_id"); requested != "" {
		si = state_session_index(&st, requested)
		if si < 0 { return error_result(.Not_Found, "requested session does not exist") }
	}
	s := &st.sessions[si]
	obj_field_bool(&res.data, "resumable", s.status != "closed")
	obj_field_raw(&res.data, "session", session_to_json(s))
	handoff, _ := session_handoff_json(store, s.id)
	obj_field_raw(&res.data, "handoff", handoff)
	if s.status == "closed" {
		append(&res.next_actions, "the latest session is closed; start a new linked session to return to this work")
	} else if s.next_action != "" {
		append(&res.next_actions, s.next_action)
	}
	if store.tail_warning != "" { append(&res.warnings, store.tail_warning) }
	return res
}

op_hint_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "level"}, {"attempt_id", "content", "concept_ids"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	session_id := get_str(input, "session_id", &res)
	level := get_int(input, "level", 0, 4, &res)
	concepts := get_strs(input, "concept_ids", &res)
	if res.status == .Error { return res }
	defer delete(concepts)

	p := obj_new()
	defer obj_free(&p)
	obj_field_int(&p, "level", level)
	obj_field_str(&p, "content", get_opt_str(input, "content"))
	obj_field_strs(&p, "concept_ids", concepts[:])

	attempt_id := get_opt_str(input, "attempt_id")
	_, res = commit_and_project(store, ctx, req, "hint_delivered", session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	obj_field_int(&res.data, "level", level)
	if level >= 3 {
		append(&res.warnings, fmt.aprintf("level %d discloses algorithmic structure; this attempt can no longer qualify as independent", level))
	}
	return res
}

op_evidence_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "evidence_type", "producer"}, {"attempt_id", "concept_id", "content", "artifact_hash"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	session_id := get_str(input, "session_id", &res)
	evidence_type := get_str(input, "evidence_type", &res)
	producer := get_str(input, "producer", &res)
	if res.status == .Error { return res }

	// Verified runner and provider observations are produced only by their
	// own handlers (section 11); agents may record claims, never tool
	// evidence.
	if producer != "learner" && producer != "agent" && producer != "import" {
		return error_result(.Invalid_Evidence, "producer must be learner, agent, or import; runner and judge evidence is recorded by its own handlers")
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "evidence_type", evidence_type)
	obj_field_str(&p, "producer", producer)
	obj_field_str(&p, "concept_id", get_opt_str(input, "concept_id"))
	obj_field_str(&p, "content", get_opt_str(input, "content"))
	obj_field_str(&p, "artifact_hash", get_opt_str(input, "artifact_hash"))

	attempt_id := get_opt_str(input, "attempt_id")
	_, res = commit_and_project(store, ctx, req, "evidence_recorded", session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	return res
}

op_assessment_record :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "concept_id", "dimension", "score", "rationale", "rubric_version"}, {"evidence_ids"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	session_id := get_str(input, "session_id", &res)
	concept_id := get_str(input, "concept_id", &res)
	dimension := get_str(input, "dimension", &res)
	rationale := get_str(input, "rationale", &res)
	rubric_version := get_str(input, "rubric_version", &res)
	if res.status == .Error { return res }
	if dimension != "recognition" && dimension != "approach" && dimension != "approach_invariant" &&
	   dimension != "correctness" && dimension != "complexity" && dimension != "implementation_testing" && dimension != "transfer" {
		return bad_input("dimension must be recognition, approach, approach_invariant, correctness, complexity, implementation_testing, or transfer")
	}

	// score is 0..3 or the string "unknown" (section 9).
	score := -1
	score_raw := jget(input, "score")
	if s := jstr(score_raw); s == "unknown" {
		score = -1
	} else if v := jint(score_raw); v >= 0 && v <= 3 {
		score = v
	} else {
		return bad_input("score must be 0..3 or \"unknown\"")
	}

	evidence := get_strs(input, "evidence_ids", &res)
	if res.status == .Error { return res }
	defer delete(evidence)
	if score >= 0 && len(evidence) == 0 { return error_result(.Invalid_Evidence, "an observed score requires at least one evidence id; use unknown when nothing was observed") }
	for evidence_id in evidence {
		found := false
		for ev in store.events {
			if ev.event_id == evidence_id && ev.session_id == session_id &&
			   (ev.type == "evidence_recorded" || ev.type == "runner_observed" || ev.type == "job_observed" || ev.type == "judge_observed") {
				found = true
				break
			}
		}
		if !found { return error_result(.Invalid_Evidence, fmt.aprintf("evidence %q does not exist in this session", evidence_id)) }
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "concept_id", concept_id)
	obj_field_str(&p, "dimension", dimension)
	obj_field_int(&p, "score", score)
	obj_field_str(&p, "rationale", rationale)
	obj_field_str(&p, "rubric_version", rubric_version)
	obj_field_strs(&p, "evidence_ids", evidence[:])

	_, res = commit_and_project(store, ctx, req, "assessment_recorded", session_id, "", obj_done(&p))
	if res.status == .Error { return res }
	return res
}

op_session_close :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"session_id", "reason"}, {"review_outcome"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	session_id := get_str(input, "session_id", &res)
	reason := get_str(input, "reason", &res)
	if res.status == .Error { return res }
	if reason != "completed" && reason != "stopped" && reason != "abandoned" {
		return bad_input("reason must be completed, stopped, or abandoned")
	}
	review_outcome := get_opt_str(input, "review_outcome")
	if review_outcome != "" {
		if _, ok := review_outcome_from_string(review_outcome); !ok { return bad_input("review_outcome is not a supported review outcome") }
	}

	// A repeated identical request returns its existing result (section 10);
	// this must come before the already-closed guard so retries replay
	// instead of erroring, while still never advancing reviews twice.
	if req.request_id != "" {
		for e in store.events {
			if e.request_id == req.request_id && e.type == "session_closed" {
				if e.request_hash == req.request_hash {
					res := ok_result()
					obj_field_bool(&res.data, "replayed", true)
					obj_field_str(&res.data, "session_id", session_id)
					return res
				}
				break
			}
		}
	}

	st := fold(store)
	found := false
	independent := false
	for _, i in st.sessions {
		if st.sessions[i].id == session_id {
			found = true
			if st.sessions[i].status == "closed" {
				// Closing twice must not advance reviews twice (section 6).
				return error_result(.Request_Conflict, "this session is already closed; use a new session to continue this work")
			}
			independent = reason == "completed" && qualifies_independent(&st, &st.sessions[i], ctx.workspace)
		}
	}
	if !found {
		return error_result(.Not_Found, fmt.aprintf("no session %q", session_id))
	}
	if review_outcome != "" && review_outcome != "independent_correct" { independent = false }

	// Eligible review updates are computed once and frozen into the event.
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "reason", reason)
	obj_field_bool(&p, "independent", independent)
	obj_field_raw(&p, "review_updates", due_review_updates(&st, session_id, reason, independent, review_outcome, context_now(ctx)))

	ev, commit_res := commit_and_project(store, ctx, req, "session_closed", session_id, "", obj_done(&p))
	if commit_res.status == .Error { return commit_res }
	res = commit_res
	obj_field_str(&res.data, "session_id", session_id)
	obj_field_bool(&res.data, "independent", independent)
	obj_field_int(&res.data, "revision", ev.sequence)
	append(&res.next_actions, "run review_due to see scheduled retrieval tasks")
	return res
}

// due_review_updates builds the review_updates array for a closing session:
// one 1-day retrieval item per concept the session touched (section 9:
// assisted study and independent solves alike start at the initial interval).
due_review_updates :: proc(st: ^State, session_id, reason: string, independent: bool, review_outcome: string, now: time.Time) -> string {
	concepts := make([dynamic]string)
	defer delete(concepts)
	review_item_id := ""
	for _, i in st.sessions {
		if st.sessions[i].id == session_id {
			for c in st.sessions[i].concepts { append(&concepts, c) }
			review_item_id = st.sessions[i].review_item_id
		}
	}
	if reason != "completed" { return "[]" }
	if review_item_id != "" {
		for review in st.reviews {
			if review.id != review_item_id { continue }
			outcome_text := review_outcome
			if outcome_text == "" { outcome_text = "independent_correct" if independent else "correct_after_help" }
			outcome, ok := review_outcome_from_string(outcome_text)
			if !ok { return "[]" }
			new_index, new_due := apply_outcome(review.interval_index, review.due_ts, outcome, now)
			o := obj_new()
			defer obj_free(&o)
			obj_field_str(&o, "action", "update")
			obj_field_str(&o, "id", review.id)
			obj_field_int(&o, "interval_index", new_index)
			obj_field_str(&o, "due_ts", new_due)
			obj_field_str(&o, "last_outcome", outcome_text)
			obj_field_str(&o, "state", "open")
			return fmt.aprintf("[%s]", obj_done(&o))
		}
		return "[]"
	}
	due := rfc3339_utc(time.time_add(now, time.Duration(INITIAL_INTERVAL_DAYS) * DAY))
	credit := "assisted" if !independent else "independent"

	items := make([dynamic]string)
	defer delete(items)
	seen := make([dynamic]string)
	defer delete(seen)
	for c in concepts {
		duplicate := false
		for s in seen { if s == c { duplicate = true } }
		if duplicate { continue }
		already_open := false
		for review in st.reviews {
			if review.concept == c && review.task_type == "recall" && review.state != "completed" { already_open = true; break }
		}
		if already_open { continue }
		append(&seen, c)
		o := obj_new()
		obj_field_str(&o, "concept", c)
		obj_field_str(&o, "task_type", "recall")
		obj_field_str(&o, "credit", credit)
		obj_field_str(&o, "due_ts", due)
		append(&items, obj_done(&o))
		obj_free(&o)
	}
	return fmt.aprintf("[%s]", strings.join(items[:], ","))
}

op_review_due :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"date", "time_budget_minutes", "concept_id"}); fail.status == .Error { return fail }
	st := fold(store)
	res := ok_result()
	now := rfc3339_utc(context_now(ctx))
	if date := get_opt_str(input, "date"); date != "" {
		if len(date) == 10 { now = strings.concatenate({date, "T23:59:59Z"}) or_else now }
		else { now = date }
	}
	concept_filter := get_opt_str(input, "concept_id")
	budget := jint(jget(input, "time_budget_minutes"))
	limit := 100
	if budget > 0 { limit = max(1, budget / 10) }
	due := make([dynamic]string)
	defer delete(due)
	for _, i in st.reviews {
		r := &st.reviews[i]
		if r.state != "open" { continue }
		if r.due_ts > now { continue }
		if concept_filter != "" && r.concept != concept_filter { continue }
		append(&due, review_to_json(r))
		if len(due) >= limit { break }
	}
	obj_field_raws(&res.data, "due", due[:])
	obj_field_int(&res.data, "count", len(due))
	return res
}

op_review_update :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"review_id", "action"}, {"until"}); fail.status == .Error {
		return fail
	}
	res := ok_result()
	review_id := get_str(input, "review_id", &res)
	action := get_str(input, "action", &res)
	if res.status == .Error { return res }
	if action != "snooze" && action != "resume" {
		return bad_input("action must be snooze or resume; completing a review happens through a review session's assessment")
	}

	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "id", review_id)
	obj_field_str(&p, "action", action)
	obj_field_str(&p, "until", get_opt_str(input, "until"))
	_, res = commit_and_project(store, ctx, req, "review_updated", "", "", obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "review_id", review_id)
	obj_field_str(&res.data, "state", "snoozed" if action == "snooze" else "open")
	return res
}

op_plan_next :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"goal", "time_budget_minutes", "topic", "mode", "language", "offline", "exclude_problem_keys"}); fail.status == .Error { return fail }
	st := fold(store)
	res := ok_result()
	now := rfc3339_utc(context_now(ctx))
	budget := jint(jget(input, "time_budget_minutes"))
	if budget == 0 { budget = st.profile.time_budget_minutes }
	if budget == 0 { budget = 30 }
	if budget < 5 || budget > 480 { return bad_input("time_budget_minutes must be between 5 and 480") }
	language := get_opt_str(input, "language")
	if language == "" { language = st.profile.language }
	if language == "" { language = "odin" }
	mode := get_opt_str(input, "mode")
	if mode == "" { mode = "guided" }
	if !valid_mode(mode) { return bad_input(fmt.aprintf("mode must be one of: %s", enum_list(MODES[:]))) }
	excluded := get_strs(input, "exclude_problem_keys", &res)
	if res.status == .Error { return res }
	defer delete(excluded)

	// Deterministic policy: one due review first, then an unmet prerequisite
	// or goal concept. Stable catalogue order is the tie-break.
	candidates := make([dynamic]string)
	defer delete(candidates)
	for _, i in st.reviews {
		r := &st.reviews[i]
		if r.state != "open" || r.due_ts > now { continue }
		c := obj_new()
		obj_field_str(&c, "kind", "review")
		obj_field_str(&c, "review_id", r.id)
		obj_field_str(&c, "concept", r.concept)
		obj_field_str(&c, "reason", fmt.aprintf("review scheduled for %s is due", r.due_ts))
		append(&candidates, obj_done(&c))
		obj_free(&c)
		break
	}
	topic := get_opt_str(input, "topic")
	if topic == "" {
		concept_doc, parse_err := json.parse(CONCEPTS_JSON, .JSON, parse_integers = true)
		if parse_err == nil {
			for concept in jarray(jget(concept_doc, "concepts")) {
				id := jstr(jget(concept, "id"))
				mastered := false
				for state in st.concepts { if state.concept_id == id && (state.state == "independent" || state.state == "retained") { mastered = true } }
				if mastered { continue }
				prereqs_met := true
				for prereq in jarray(jget(concept, "prerequisites")) {
					met := false
					for state in st.concepts { if state.concept_id == jstr(prereq) && (state.state == "independent" || state.state == "retained") { met = true } }
					if !met { prereqs_met = false; topic = jstr(prereq); break }
				}
				if topic == "" && prereqs_met { topic = id }
				if topic != "" { break }
			}
		}
	}
	if topic == "" { topic = "foundations" }
	problems, catalog_err := catalog_problems()
	if catalog_err != .None { return error_result(catalog_err, "the bundled catalogue could not be read") }
	for problem in problems {
		if len(candidates) >= 3 { break }
		problem_key := jstr(jget(problem, "problem_key"))
		skip := false
		for key in excluded { if key == problem_key { skip = true } }
		if skip || !catalog_has_string(jget(problem, "concept_ids"), topic) { continue }
		if jint(jget(problem, "effort_minutes")) > budget { continue }
		local_ok := language == "odin" && catalog_has_string(jget(problem, "practice_modes"), "odin_local")
		remote_ok := catalog_has_string(jget(problem, "judge_languages"), language)
		if !local_ok && !remote_ok { continue }
		recent := false
		for attempt in st.attempts { if attempt.problem_key == problem_key { recent = true; break } }
		if recent { continue }
		c := obj_new()
		obj_field_str(&c, "kind", "new_practice")
		obj_field_str(&c, "concept", topic)
		obj_field_raw(&c, "problem", catalog_problem_json(problem, "assessment" if mode == "assessment" || mode == "independent" else "learning"))
		obj_field_str(&c, "reason", fmt.aprintf("targets %s, fits the %d-minute budget, and has no recorded prior attempt", topic, budget))
		limitations := make([dynamic]string)
		if jstr(jget(problem, "provider")) == "leetcode" && language == "odin" {
			append(&limitations, "Odin is local-practice only for LeetCode")
		}
		obj_field_strs(&c, "capability_limitations", limitations[:])
		delete(limitations)
		append(&candidates, obj_done(&c))
		obj_free(&c)
	}
	obj_field_raws(&res.data, "candidates", candidates[:])
	obj_field_str(&res.data, "target_concept", topic)
	obj_field_int(&res.data, "time_budget_minutes", budget)
	obj_field_str(&res.data, "language", language)
	if len(candidates) == 0 { append(&res.warnings, "no bundled problem satisfies the current constraints; choose a cached review or a clearly labelled local micro-exercise") }
	return res
}

op_progress_get :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"goal", "topic", "date_scope"}); fail.status == .Error { return fail }
	st := fold(store)
	res := ok_result()
	// Separate views (section 9): accepted submissions are provider evidence
	// and arrive with the provider adapters; learning views are derived here.
	counts := obj_new()
	defer obj_free(&counts)
	active, closed, assisted_sessions, independent_sessions := 0, 0, 0, 0
	for &s in st.sessions {
		if s.status == "closed" {
			closed += 1
			if s.independent_qualified { independent_sessions += 1 } else if s.closure_reason == "completed" { assisted_sessions += 1 }
		} else { active += 1 }
	}
	obj_field_int(&counts, "active_sessions", active)
	obj_field_int(&counts, "closed_sessions", closed)
	obj_field_int(&counts, "open_reviews", len(st.reviews))
	obj_field_int(&counts, "assisted_sessions", assisted_sessions)
	obj_field_int(&counts, "independent_sessions", independent_sessions)
	verified_runs, failed_runs, unverified_runs := 0, 0, 0
	accepted, pending_jobs, unknown_submissions := 0, 0, 0
	for ev in store.events {
		payload, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err != nil { continue }
		if ev.type == "runner_observed" {
			switch jstr(jget(payload, "outcome")) {
			case "passed": verified_runs += 1
			case "failed": failed_runs += 1
			case: unverified_runs += 1
			}
		} else if ev.type == "job_observed" {
			if jstr(jget(payload, "state")) == "terminal" {
				if strings.to_lower(jstr(jget(payload, "verdict"))) == "accepted" { accepted += 1 }
			} else { pending_jobs += 1 }
		} else if ev.type == "submission_outcome_unknown" { unknown_submissions += 1 }
	}
	execution := obj_new()
	defer obj_free(&execution)
	obj_field_int(&execution, "verified_passed_runs", verified_runs)
	obj_field_int(&execution, "failed_runs", failed_runs)
	obj_field_int(&execution, "unverified_runs", unverified_runs)
	judge := obj_new()
	defer obj_free(&judge)
	obj_field_int(&judge, "accepted", accepted)
	obj_field_int(&judge, "pending", pending_jobs)
	obj_field_int(&judge, "outcome_unknown", unknown_submissions)
	obj_field_raw(&res.data, "execution", obj_done(&execution))
	obj_field_raw(&res.data, "judge", obj_done(&judge))
	concepts := make([dynamic]string)
	defer delete(concepts)
	curriculum, curriculum_err := json.parse(CONCEPTS_JSON, .JSON, parse_integers = true)
	if curriculum_err == nil {
		for concept in jarray(jget(curriculum, "concepts")) {
			id := jstr(jget(concept, "id"))
			found := false
			for _, i in st.concepts {
				if st.concepts[i].concept_id == id { append(&concepts, concept_to_json(&st.concepts[i])); found = true; break }
			}
			if !found {
				unknown := Concept_State{concept_id = id, state = "unknown"}
				append(&concepts, concept_to_json(&unknown))
			}
		}
	} else {
		for _, i in st.concepts { append(&concepts, concept_to_json(&st.concepts[i])) }
	}
	obj_field_raws(&res.data, "concepts", concepts[:])
	obj_field_raw(&res.data, "counts", obj_done(&counts))
	return res
}
