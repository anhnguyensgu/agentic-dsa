package learning

// Handler tests: session lifecycle, honest assistance accounting, and the
// at-most-once review updates (sections 6, 9, and 18 A08/A09).

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

parse_input :: proc(t: ^testing.T, text: string) -> json.Value {
	v, err := json.parse(text, .JSON, parse_integers = true)
	if !testing.expect(t, err == nil) {
		return nil
	}
	return v
}

init_workspace :: proc(t: ^testing.T, ws: string) -> Result {
	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	store, lerr := load_store(ws)
	testing.expect_value(t, lerr, Engine_Error.None)
	input := parse_input(t, `{"goal":"foundations","language":"odin","timezone":"UTC","experience":"beginner","time_budget_minutes":30}`)
	req := Request{request_id = "init", request_hash = "hi", expected_revision = 0}
	res, found := run_operation("workspace_init", &ctx, &store, input, req)
	testing.expect(t, found)
	testing.expect_value(t, res.status, Status.Completed)
	return res
}

@(test)
handlers_guided_session_records_assistance :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)

	store, _ := load_store(ws)

	// Guided session with a level-2 hint: practicing, not independent.
	start_input := parse_input(t, `{"objective":"trace loops","mode":"guided","concept_ids":["foundations-tracing"]}`)
	req := Request{request_id = "s1", request_hash = "h1", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, start_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	hint_input := parse_input(t, `{"session_id":"sess_000002","level":2,"concept_ids":["foundations-tracing"],"content":"look for repeated work"}`)
	req = Request{request_id = "h1", request_hash = "h2", expected_revision = 2}
	res, _ = run_operation("hint_record", &ctx, &store, hint_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	close_input := parse_input(t, `{"session_id":"sess_000002","reason":"completed"}`)
	req = Request{request_id = "c1", request_hash = "h3", expected_revision = 3}
	res, _ = run_operation("session_close", &ctx, &store, close_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	// The review item exists, is due tomorrow, and carries no independent credit.
	st := fold(&store)
	testing.expect_value(t, len(st.reviews), 1)
	testing.expect_value(t, st.reviews[0].credit, "assisted")
	testing.expect_value(t, st.reviews[0].due_ts, "2025-09-20T16:40:00Z")

	// Closing twice must not create another review item (section 6).
	req = Request{request_id = "c2", request_hash = "h4", expected_revision = 4}
	res, _ = run_operation("session_close", &ctx, &store, close_input, req)
	testing.expect_value(t, res.status, Status.Error)
	testing.expect_value(t, res.err, Engine_Error.Request_Conflict)

	st = fold(&store)
	testing.expect_value(t, len(st.reviews), 1)
}

@(test)
handlers_independent_session_promotes_concept :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)
	store, _ := load_store(ws)

	// Independent session: only a level-1 clarification, no solution exposure.
	start_input := parse_input(t, `{"objective":"two-pointer window","mode":"independent","concept_ids":["arrays-window"]}`)
	req := Request{request_id = "s1", request_hash = "h1", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, start_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	hint_input := parse_input(t, `{"session_id":"sess_000002","level":1,"content":"what happens with one element?"}`)
	req = Request{request_id = "h1", request_hash = "h2", expected_revision = 2}
	res, _ = run_operation("hint_record", &ctx, &store, hint_input, req)
	testing.expect_value(t, res.status, Status.Completed)


	// Independent credit requires a fresh attempt, verified behavior, and
	// score-3 evidence for approach, correctness, and complexity.
	attempt_input := parse_input(t, `{"session_id":"sess_000002","problem_key":"leetcode:two-sum","language":"odin","runner_kind":"stdin_stdout"}`)
	req = Request{request_id = "at1", request_hash = "hat", expected_revision = 3}
	res, _ = run_operation("attempt_start", &ctx, &store, attempt_input, req)
	testing.expect_value(t, res.status, Status.Completed)
	source_path := join({ws, "problems", "leetcode", "two-sum", "att_000004", "solution.odin"})
	testing.expect_value(t, write_private_file(source_path, "package main\nimport \"core:fmt\"\nmain :: proc() { fmt.println(3) }\n"), nil)

	case_input := parse_input(t, `{"attempt_id":"att_000004","name":"verified","input":"","expected":"3\n","comparator":"exact","provenance":"manually_checked","oracle_verified":true,"oracle_basis":"constant trace"}`)
	req = Request{request_id = "case1", request_hash = "hcase", expected_revision = 4}
	res, _ = run_operation("case_add", &ctx, &store, case_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	run_input := parse_input(t, `{"attempt_id":"att_000004","mode":"local"}`)
	req = Request{request_id = "run1", request_hash = "hrun", expected_revision = 5}
	res, _ = run_operation("test_run", &ctx, &store, run_input, req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect_value(t, res.cli_exit, 0)
	evidence_id := store.events[len(store.events)-1].event_id

	dimensions := [?]string{"approach", "correctness", "complexity"}
	for dimension, i in dimensions {
		/*
		assessment_json := fmt.aprintf(`{"session_id":"sess_000002","concept_id":"arrays-window","dimension":"%s","score":3,"rationale":"learner independently justified this dimension","rubric_version":"1","evidence_ids":["ev_000006"]}`, dimension)
		*/
		/*
		assessment_json := strings.concatenate({"{\\\"session_id\\\":\\\"sess_000002\\\",\\\"concept_id\\\":\\\"arrays-window\\\",\\\"dimension\\\":\\\"", dimension, "\\\",\\\"score\\\":3,\\\"rationale\\\":\\\"learner independently justified this dimension\\\",\\\"rubric_version\\\":\\\"1\\\",\\\"evidence_ids\\\":[\\\"ev_000006\\\"]}"})
		*/
		assessment := obj_new()
		obj_field_str(&assessment, "session_id", "sess_000002")
		obj_field_str(&assessment, "concept_id", "arrays-window")
		obj_field_str(&assessment, "dimension", dimension)
		obj_field_int(&assessment, "score", 3)
		obj_field_str(&assessment, "rationale", "learner independently justified this dimension")
		obj_field_str(&assessment, "rubric_version", "1")
		obj_field_strs(&assessment, "evidence_ids", {evidence_id})
		assessment_json := obj_done(&assessment)
		obj_free(&assessment)
		assess_input := parse_input(t, assessment_json)
		req = Request{request_id = fmt.aprintf("a%d", i), request_hash = fmt.aprintf("ha%d", i), expected_revision = 6 + i}
		res, _ = run_operation("assessment_record", &ctx, &store, assess_input, req)
		testing.expect_value(t, res.status, Status.Completed)
	}

	close_input := parse_input(t, `{"session_id":"sess_000002","reason":"completed"}`)
	req = Request{request_id = "c1", request_hash = "h3", expected_revision = 9}
	res, _ = run_operation("session_close", &ctx, &store, close_input, req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, strings.contains(string(res.data.buf[:]), "\"independent\":true"))

	st := fold(&store)
	testing.expect_value(t, len(st.reviews), 1)
	testing.expect_value(t, st.reviews[0].credit, "independent")
	testing.expect_value(t, len(st.concepts), 1)
	testing.expect_value(t, st.concepts[0].state, "independent")
	testing.expect_value(t, st.concepts[0].independent_solves, 1)
}

@(test)
handlers_heavy_hint_blocks_independence :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)
	store, _ := load_store(ws)

	start_input := parse_input(t, `{"objective":"binary search boundary","mode":"independent","concept_ids":["sorting-search"]}`)
	req := Request{request_id = "s1", request_hash = "h1", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, start_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	// A level-3 hint discloses the central invariant: no independent credit,
	// even though the session mode was independent (sections 7 and 9).
	hint_input := parse_input(t, `{"session_id":"sess_000002","level":3,"content":"the loop must keep the target inside [lo, hi)"}`)
	req = Request{request_id = "h1", request_hash = "h2", expected_revision = 2}
	res, _ = run_operation("hint_record", &ctx, &store, hint_input, req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, len(res.warnings) > 0)

	close_input := parse_input(t, `{"session_id":"sess_000002","reason":"completed"}`)
	req = Request{request_id = "c1", request_hash = "h3", expected_revision = 3}
	res, _ = run_operation("session_close", &ctx, &store, close_input, req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, strings.contains(string(res.data.buf[:]), "\"independent\":false"))

	st := fold(&store)
	testing.expect_value(t, st.reviews[0].credit, "assisted")
	testing.expect_value(t, st.concepts[0].state, "practicing")
}

@(test)
handlers_review_due_and_snooze :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)
	store, _ := load_store(ws)

	start_input := parse_input(t, `{"objective":"window","mode":"independent","concept_ids":["arrays-window"]}`)
	req := Request{request_id = "s1", request_hash = "h1", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, start_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	close_input := parse_input(t, `{"session_id":"sess_000002","reason":"completed"}`)
	req = Request{request_id = "c1", request_hash = "h3", expected_revision = 2}
	res, _ = run_operation("session_close", &ctx, &store, close_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	// Not due yet (review is scheduled for tomorrow).
	due_input := parse_input(t, `{}`)
	empty_req := Request{}
	res, _ = run_operation("review_due", &ctx, &store, due_input, empty_req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, strings.contains(string(res.data.buf[:]), "\"count\":0"))

	// A day later it is due.
	ctx.now = time.unix(1758300000 + 2 * 24 * 3600, 0)
	res, _ = run_operation("review_due", &ctx, &store, due_input, empty_req)
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, strings.contains(string(res.data.buf[:]), "\"count\":1"))

	// Snoozing hides it without pretending it was completed (section 9).
	snooze_input := parse_input(t, `{"review_id":"rev_000003_0","action":"snooze"}`)
	req = Request{request_id = "sn1", request_hash = "h9", expected_revision = 3}
	res, _ = run_operation("review_update", &ctx, &store, snooze_input, req)
	testing.expect_value(t, res.status, Status.Completed)

	res, _ = run_operation("review_due", &ctx, &store, due_input, empty_req)
	testing.expect(t, strings.contains(string(res.data.buf[:]), "\"count\":0"))
}

@(test)
handlers_reject_invalid_inputs :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	freeze_clock(t)
	defer unfreeze_clock()
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)
	store, _ := load_store(ws)

	// Unexpected fields are rejected (section 11).
	bad := parse_input(t, `{"objective":"x","mode":"guided","sneaky":"field"}`)
	req := Request{request_id = "b1", request_hash = "hb", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, bad, req)
	testing.expect_value(t, res.status, Status.Error)
	testing.expect_value(t, res.err, Engine_Error.Invalid_Input)

	// Invalid enums are rejected.
	bad_mode := parse_input(t, `{"objective":"x","mode":"speedrun"}`)
	req = Request{request_id = "b2", request_hash = "hc", expected_revision = 1}
	res, _ = run_operation("session_start", &ctx, &store, bad_mode, req)
	testing.expect_value(t, res.err, Engine_Error.Invalid_Input)

	// Hint levels are bounded 0..4 (section 7).
	bad_level := parse_input(t, `{"session_id":"sess_000002","level":9}`)
	req = Request{request_id = "b3", request_hash = "hd", expected_revision = 1}
	res, _ = run_operation("hint_record", &ctx, &store, bad_level, req)
	testing.expect_value(t, res.err, Engine_Error.Invalid_Input)

	// Agent-produced tool evidence is rejected (section 11).
	fake_tool := parse_input(t, `{"session_id":"sess_000002","evidence_type":"run","producer":"tool"}`)
	req = Request{request_id = "b4", request_hash = "he", expected_revision = 1}
	res, _ = run_operation("evidence_record", &ctx, &store, fake_tool, req)
	testing.expect_value(t, res.err, Engine_Error.Invalid_Evidence)
}

@(test)
handlers_emit_structured_object_arrays :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	ctx := Context{workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	init_workspace(t, ws)
	store, _ := load_store(ws)
	start := parse_input(t, `{"objective":"trace loops","mode":"guided","concept_ids":["foundations"]}`)
	req := Request{request_id = "s1", request_hash = "hs", expected_revision = 1}
	res, _ := run_operation("session_start", &ctx, &store, start, req)
	testing.expect_value(t, res.status, Status.Completed)

	state_input := parse_input(t, `{}`)
	res, _ = run_operation("state_get", &ctx, &store, state_input, Request{})
	encoded := obj_done(&res.data)
	parsed, err := json.parse(encoded, .JSON, parse_integers = true)
	testing.expect_value(t, err, nil)
	sessions := jarray(jget(parsed, "sessions"))
	testing.expect_value(t, len(sessions), 1)
	_, session_is_object := sessions[0].(json.Object)
	testing.expect(t, session_is_object)

	search := parse_input(t, `{"provider":"leetcode","limit":1}`)
	res, _ = run_operation("problem_search", &ctx, &store, search, Request{})
	encoded = obj_done(&res.data)
	parsed, err = json.parse(encoded, .JSON, parse_integers = true)
	testing.expect_value(t, err, nil)
	problems := jarray(jget(parsed, "problems"))
	testing.expect_value(t, len(problems), 1)
	_, problem_is_object := problems[0].(json.Object)
	testing.expect(t, problem_is_object)
}

@(test)
independent_eligibility_is_bound_to_current_verified_source :: proc(t: ^testing.T) {
	arena := with_arena(t)
	defer mem.dynamic_arena_destroy(&arena)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	source_rel := "problems/local/eligibility/solution.odin"
	source := join({ws, source_rel})
	original := "package main\nmain :: proc() {}\n"
	testing.expect_value(t, write_private_file(source, original), nil)
	hash := hash_hex(original)
	st := State{}
	append(&st.attempts, Attempt_State{id = "a1", source_path = source_rel, fresh = true})
	session := Session_State{
		mode = "independent", current_attempt_id = "a1", has_fresh_attempt = true,
		verified_behavior = true, verified_source_hash = hash,
		approach_score3 = true, correctness_score3 = true, complexity_score3 = true,
	}
	testing.expect(t, qualifies_independent(&st, &session, ws))
	changed := strings.concatenate({original, "// changed\n"})
	testing.expect_value(t, write_private_file(source, changed), nil)
	testing.expect(t, !qualifies_independent(&st, &session, ws))
	testing.expect_value(t, write_private_file(source, original), nil)
	session.max_hint_level = 3
	testing.expect(t, !qualifies_independent(&st, &session, ws))
	session.max_hint_level = 0
	session.agent_authored_algorithm = true
	testing.expect(t, !qualifies_independent(&st, &session, ws))
}
