package learn

// Handler tests: session lifecycle, honest assistance accounting, and the
// at-most-once review updates (sections 6, 9, and 18 A08/A09).

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

Fixture :: struct {
	ctx:   Context,
	store: Store,
}

// setup initializes a temporary workspace; the caller removes ctx.workspace.
setup :: proc(t: ^testing.T) -> (f: Fixture) {
	ws := temp_workspace(t)
	f.ctx = {workspace = ws, actor = "agent:test", host = "test", now = fake_now()}
	f.store, _ = load_store(ws)
	res := call(t, &f, "workspace_init", `{"goal":"foundations","language":"odin","timezone":"UTC","experience":"beginner","time_budget_minutes":30}`, {"init", "h0", 0})
	testing.expect_value(t, res.status, Status.Completed)
	return
}

call :: proc(t: ^testing.T, f: ^Fixture, operation, text: string, req := Request{expected_revision = -1}) -> Result {
	input, _, message := new_request(text)
	testing.expect_value(t, message, "")
	res, found := run_operation(operation, &f.ctx, &f.store, input, req)
	testing.expect(t, found)
	return res
}

has :: proc(res: Result, fragment: string) -> bool {
	return strings.contains(string(res.data), fragment)
}

@(test)
handlers_guided_session_records_assistance :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	// A guided session with a level-2 hint: practicing, not independent.
	res := call(t, &f, "session_start", `{"objective":"trace loops","mode":"guided","concept_ids":["foundations-tracing"]}`, {"s1", "h1", 1})
	testing.expect_value(t, res.status, Status.Completed)
	res = call(t, &f, "hint_record", `{"session_id":"sess_000002","level":2,"concept_ids":["foundations-tracing"],"content":"look for repeated work"}`, {"h1", "h2", 2})
	testing.expect_value(t, res.status, Status.Completed)
	close := `{"session_id":"sess_000002","reason":"completed"}`
	res = call(t, &f, "session_close", close, {"c1", "h3", 3})
	testing.expect_value(t, res.status, Status.Completed)

	// The review item is due tomorrow and carries no independent credit.
	st := fold(&f.store)
	testing.expect_value(t, len(st.reviews), 1)
	testing.expect_value(t, st.reviews[0].credit, Credit.Assisted)
	testing.expect_value(t, st.reviews[0].due_ts, "2025-09-20T16:40:00Z")

	// Closing twice must not create another review item (section 6).
	res = call(t, &f, "session_close", close, {"c2", "h4", 4})
	testing.expect_value(t, res.err, Engine_Error.Request_Conflict)
	st = fold(&f.store)
	testing.expect_value(t, len(st.reviews), 1)
}

@(test)
handlers_independent_session_promotes_concept :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	// Only a level-1 clarification; no solution exposure.
	call(t, &f, "session_start", `{"objective":"two-pointer window","mode":"independent","concept_ids":["arrays-window"]}`, {"s1", "h1", 1})
	call(t, &f, "hint_record", `{"session_id":"sess_000002","level":1,"content":"what happens with one element?"}`, {"h1", "h2", 2})

	// Independent credit needs a fresh attempt, verified behavior, and score-3
	// evidence for approach, correctness, and complexity.
	res := call(t, &f, "attempt_start", `{"session_id":"sess_000002","problem_key":"leetcode:two-sum","language":"odin","runner_kind":"stdin_stdout"}`, {"at1", "hat", 3})
	testing.expect_value(t, res.status, Status.Completed)
	source := join(f.ctx.workspace, "problems", "leetcode", "two-sum", "att_000004", "solution.odin")
	testing.expect_value(t, write_private_file(source, "package main\nimport \"core:fmt\"\nmain :: proc() { fmt.println(3) }\n"), nil)
	call(t, &f, "case_add", `{"attempt_id":"att_000004","name":"verified","input":"","expected":"3\n","comparator":"exact","provenance":"manually_checked","oracle_verified":true,"oracle_basis":"constant trace"}`, {"case1", "hcase", 4})
	res = call(t, &f, "test_run", `{"attempt_id":"att_000004","mode":"local"}`, {"run1", "hrun", 5})
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect_value(t, res.cli_exit, 0)
	evidence_id := f.store.events[len(f.store.events) - 1].event_id

	for dimension, i in ([?]string{"approach", "correctness", "complexity"}) {
		Assessment :: struct {
			session_id, concept_id, dimension: string,
			score:                             int,
			rationale, rubric_version:         string,
			evidence_ids:                      []string,
		}
		evidence := [?]string{evidence_id}
		text, _ := json.marshal(Assessment{"sess_000002", "arrays-window", dimension, 3, "learner independently justified this dimension", "1", evidence[:]})
		res = call(t, &f, "assessment_record", string(text), {fmt.aprintf("a%d", i), fmt.aprintf("ha%d", i), 6 + i})
		testing.expect_value(t, res.status, Status.Completed)
	}

	res = call(t, &f, "session_close", `{"session_id":"sess_000002","reason":"completed"}`, {"c1", "h3", 9})
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, has(res, `"independent":true`))

	st := fold(&f.store)
	testing.expect_value(t, len(st.reviews), 1)
	testing.expect_value(t, st.reviews[0].credit, Credit.Independent)
	testing.expect_value(t, len(st.concepts), 1)
	testing.expect_value(t, st.concepts[0].state, Concept_Level.Independent)
	testing.expect_value(t, st.concepts[0].independent_solves, 1)
}

@(test)
handlers_heavy_hint_blocks_independence :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	call(t, &f, "session_start", `{"objective":"binary search boundary","mode":"independent","concept_ids":["sorting-search"]}`, {"s1", "h1", 1})
	// A level-3 hint discloses the central invariant: no independent credit,
	// even in an independent session (sections 7 and 9).
	res := call(t, &f, "hint_record", `{"session_id":"sess_000002","level":3,"content":"the loop must keep the target inside [lo, hi)"}`, {"h1", "h2", 2})
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, len(res.warnings) > 0)

	res = call(t, &f, "session_close", `{"session_id":"sess_000002","reason":"completed"}`, {"c1", "h3", 3})
	testing.expect(t, has(res, `"independent":false`))

	st := fold(&f.store)
	testing.expect_value(t, st.reviews[0].credit, Credit.Assisted)
	testing.expect_value(t, st.concepts[0].state, Concept_Level.Practicing)
}

@(test)
handlers_review_due_and_snooze :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	call(t, &f, "session_start", `{"objective":"window","mode":"independent","concept_ids":["arrays-window"]}`, {"s1", "h1", 1})
	call(t, &f, "session_close", `{"session_id":"sess_000002","reason":"completed"}`, {"c1", "h3", 2})

	// Not due yet: the review is scheduled for tomorrow.
	testing.expect(t, has(call(t, &f, "review_due", `{}`), `"count":0`))

	// Two days later it is due.
	f.ctx.now = time.unix(FAKE_NOW + 2 * 24 * 3600, 0)
	testing.expect(t, has(call(t, &f, "review_due", `{}`), `"count":1`))

	// Snoozing hides it without pretending it was completed (section 9).
	res := call(t, &f, "review_update", `{"review_id":"rev_000003_0","action":"snooze"}`, {"sn1", "h9", 3})
	testing.expect_value(t, res.status, Status.Completed)
	testing.expect(t, has(call(t, &f, "review_due", `{}`), `"count":0`))
}

@(test)
handlers_reject_invalid_inputs :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	cases := [?]struct {
		operation, input: string,
		expected:         Engine_Error,
	}{
		// Unexpected fields are rejected (section 11).
		{"session_start", `{"objective":"x","mode":"guided","sneaky":"field"}`, .Invalid_Input},
		// Invalid enums are rejected.
		{"session_start", `{"objective":"x","mode":"speedrun"}`, .Invalid_Input},
		// Hint levels are bounded 0..4 (section 7).
		{"hint_record", `{"session_id":"sess_000002","level":9}`, .Invalid_Input},
		// Wrongly typed fields are rejected.
		{"hint_record", `{"session_id":"sess_000002","level":"high"}`, .Invalid_Input},
		// Agents cannot produce tool evidence (section 11).
		{"evidence_record", `{"session_id":"sess_000002","evidence_type":"run","producer":"tool"}`, .Invalid_Evidence},
	}
	for c in cases {
		res := call(t, &f, c.operation, c.input, {"bad", c.input, 1})
		testing.expectf(t, res.err == c.expected, "%s %s: got %v", c.operation, c.input, res.err)
	}
}

@(test)
handlers_replay_returns_the_original_ids :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	start := `{"objective":"trace loops","mode":"guided"}`
	first := call(t, &f, "session_start", start, {"s1", "same", 1})
	call(t, &f, "hint_record", `{"session_id":"sess_000002","level":0}`, {"h1", "h1", 2})
	again := call(t, &f, "session_start", start, {"s1", "same", 3})
	testing.expect(t, has(again, `"replayed":true`))
	testing.expect(t, has(first, `"session_id":"sess_000002"`) && has(again, `"session_id":"sess_000002"`))
}

@(test)
handlers_emit_structured_object_arrays :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	f := setup(t)
	defer os.remove_all(f.ctx.workspace)

	call(t, &f, "session_start", `{"objective":"trace loops","mode":"guided","concept_ids":["foundations"]}`, {"s1", "hs", 1})

	State_Data :: struct {
		sessions: []Session_View,
	}
	state: State_Data
	testing.expect(t, decode(string(call(t, &f, "state_get", `{}`).data), &state))
	testing.expect_value(t, len(state.sessions), 1)
	testing.expect_value(t, state.sessions[0].mode, "guided")

	Search_Data :: struct {
		problems: []Problem_View,
	}
	search: Search_Data
	testing.expect(t, decode(string(call(t, &f, "problem_search", `{"provider":"leetcode","limit":1}`).data), &search))
	testing.expect_value(t, len(search.problems), 1)
	testing.expect_value(t, search.problems[0].provider, "leetcode")
}

@(test)
independent_eligibility_is_bound_to_current_verified_source :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	source_path := "problems/local/eligibility/solution.odin"
	source := join(ws, source_path)
	original := "package main\nmain :: proc() {}\n"
	testing.expect_value(t, write_private_file(source, original), nil)
	st: State
	append(&st.attempts, Attempt_State{id = "a1", source_path = source_path, fresh = true})
	session := Session_State{
		mode                 = .Independent,
		current_attempt_id   = "a1",
		has_fresh_attempt    = true,
		verified_behavior    = true,
		verified_source_hash = hash_hex(original),
		approach_score3      = true,
		correctness_score3   = true,
		complexity_score3    = true,
	}
	testing.expect(t, qualifies_independent(&st, &session, ws))

	// Editing the source after verification removes eligibility.
	testing.expect_value(t, write_private_file(source, strings.concatenate({original, "// changed\n"})), nil)
	testing.expect(t, !qualifies_independent(&st, &session, ws))
	testing.expect_value(t, write_private_file(source, original), nil)

	session.max_hint_level = 3
	testing.expect(t, !qualifies_independent(&st, &session, ws))
	session.max_hint_level = 0
	session.agent_authored_algorithm = true
	testing.expect(t, !qualifies_independent(&st, &session, ws))
}

@(test)
provider_names_from_the_log_never_become_paths :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	// An imported event could name any provider; only known ones resolve.
	evil := join(ws, "evil")
	testing.expect_value(t, write_private_file(evil, "#!/bin/sh\n"), nil)
	for name in ([?]string{"../evil", "evil", "/bin/sh", ""}) {
		_, err := provider_command(name)
		testing.expectf(t, err != nil, "resolved provider %q", name)
	}
	for name in PROVIDERS {
		command, err := provider_command(name)
		testing.expectf(t, err == nil, "known provider %q did not resolve", name)
		testing.expect_value(t, len(command), 3)
		testing.expect_value(t, command[1], "judge")
		testing.expect_value(t, command[2], name)
	}
}
