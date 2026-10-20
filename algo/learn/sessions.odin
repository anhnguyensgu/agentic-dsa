package learn

// Sessions, assistance accounting, evidence, and assessment (sections 6-9).

import "core:encoding/json"
import "core:fmt"
import "core:time"

// -- session_start -------------------------------------------------------------

Session_Start_Params :: struct {
	objective:      string,
	mode:           string,
	concept_ids:    []string,
	budget_minutes: int,
	problem_key:    string,
	review_item_id: string,
}

op_session_start :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Session_Start_Params) or_return
	nonempty({"objective", p.objective}, {"mode", p.mode}) or_return
	nonempty_items("concept_ids", p.concept_ids) or_return
	mode := enum_value(MODE_NAMES, "mode", p.mode) or_return
	if p.problem_key != "" {
		parse_problem_key(p.problem_key) or_return
	}
	if p.review_item_id != "" {
		if mode != .Review {
			return {}, invalid("review_item_id may only be used with review mode")
		}
		st := fold(store)
		if r := find_review(&st, p.review_item_id); r == nil || r.state == .Completed {
			return {}, fail(.Not_Found, "review_item_id does not name an open or snoozed review")
		}
	}

	// The id is minted from the sequence number this event will receive; ids
	// are only minted under the workspace lock, so it cannot collide.
	payload := Session_Started {
		objective      = p.objective,
		mode           = p.mode,
		problem_key    = p.problem_key,
		review_item_id = p.review_item_id,
		budget_minutes = p.budget_minutes if p.budget_minutes > 0 else nil,
		concept_ids    = p.concept_ids,
	}
	ev, replayed := commit(
		ctx,
		store,
		req,
		.Session_Started,
		payload,
		session_id = fmt_id("sess", store.revision + 1),
	) or_return

	Data :: struct {
		replayed:   Replayed `json:",omitempty"`,
		session_id: string,
		revision:   int,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), ev.session_id, ev.sequence})
	append(
		&res.next_actions,
		"state the expected learning outcome, then select or accept a problem",
	)
	return
}

// -- session_checkpoint --------------------------------------------------------

Session_Checkpoint_Params :: struct {
	session_id:  string,
	activity:    string,
	summary:     string,
	next_action: string,
	pause:       bool,
}

op_session_checkpoint :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Session_Checkpoint_Params) or_return
	nonempty(
		{"session_id", p.session_id},
		{"activity", p.activity},
		{"summary", p.summary},
		{"next_action", p.next_action},
	) or_return
	enum_value(ACTIVITY_NAMES, "activity", p.activity) or_return

	payload := Session_Checkpoint{p.activity, p.summary, p.next_action, p.pause}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Session_Checkpoint,
		payload,
		session_id = p.session_id,
	) or_return

	Data :: struct {
		replayed:         Replayed `json:",omitempty"`,
		handoff_json:     string `json:",omitempty"`,
		handoff_markdown: string `json:",omitempty"`,
	}
	data := Data {
		replayed = replayed_flag(replayed),
	}
	res = mutation_result(replayed)
	if write_session_handoff(store, p.session_id) != nil {
		append(
			&res.warnings,
			"checkpoint event was committed but the handoff view could not be written; event replay remains authoritative",
		)
	} else {
		data.handoff_json = join(LEARNING_DIR, "sessions", p.session_id, "handoff.json")
		data.handoff_markdown = join(LEARNING_DIR, "sessions", p.session_id, "handoff.md")
	}
	res.data = to_json(data)
	append(&res.next_actions, "checkpoint saved; another agent can resume with session_resume")
	return
}

// -- session_resume ------------------------------------------------------------

Session_Resume_Params :: struct {
	session_id: string,
}

op_session_resume :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Session_Resume_Params) or_return
	st := fold(store)
	if len(st.sessions) == 0 {
		Empty :: struct {
			resumable: bool,
		}
		res.data = to_json(Empty{false})
		append(&res.warnings, "no sessions recorded; run session_start to begin")
		return
	}
	s := &st.sessions[len(st.sessions) - 1]
	if p.session_id != "" {
		s = find_session(&st, p.session_id)
		if s == nil {
			return {}, fail(.Not_Found, "requested session does not exist")
		}
	}

	Data :: struct {
		resumable: bool,
		session:   Session_View,
		handoff:   Raw_JSON,
	}
	handoff, _ := session_handoff(store, s.id)
	res.data = to_json(Data{s.status != .Closed, session_view(s^), handoff})
	if s.status == .Closed {
		append(
			&res.next_actions,
			"the latest session is closed; start a new linked session to return to this work",
		)
	} else if s.next_action != "" {
		append(&res.next_actions, s.next_action)
	}
	if store.tail_warning != "" {
		append(&res.warnings, store.tail_warning)
	}
	return
}

// -- hint_record ---------------------------------------------------------------

// Hints at or above this level disclose algorithmic structure (section 7).
STRUCTURAL_HINT_LEVEL :: 3

Hint_Record_Params :: struct {
	session_id:  string,
	level:       int,
	attempt_id:  string,
	content:     string,
	concept_ids: []string,
}

op_hint_record :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Hint_Record_Params) or_return
	nonempty({"session_id", p.session_id}) or_return
	in_range("level", p.level, 0, SOLUTION_HINT_LEVEL) or_return
	nonempty_items("concept_ids", p.concept_ids) or_return

	payload := Hint_Delivered{p.level, p.content, p.concept_ids}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Hint_Delivered,
		payload,
		p.session_id,
		p.attempt_id,
	) or_return

	Data :: struct {
		replayed: Replayed `json:",omitempty"`,
		level:    int,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), p.level})
	if p.level >= STRUCTURAL_HINT_LEVEL {
		append(
			&res.warnings,
			fmt.aprintf(
				"level %d discloses algorithmic structure; this attempt can no longer qualify as independent",
				p.level,
			),
		)
	}
	return
}

// -- evidence_record -----------------------------------------------------------

Evidence_Record_Params :: struct {
	session_id:    string,
	evidence_type: string,
	producer:      string,
	attempt_id:    string,
	concept_id:    string,
	content:       string,
	artifact_hash: string,
}

op_evidence_record :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Evidence_Record_Params) or_return
	nonempty(
		{"session_id", p.session_id},
		{"evidence_type", p.evidence_type},
		{"producer", p.producer},
	) or_return
	// Runner and provider observations come only from their own handlers;
	// agents may record claims, never tool evidence (section 11).
	switch p.producer {
	case "learner", "agent", "import":
	case:
		return {}, fail(.Invalid_Evidence, "producer must be learner, agent, or import; runner and judge evidence is recorded by its own handlers")
	}

	payload := Evidence_Recorded {
		p.evidence_type,
		p.producer,
		p.concept_id,
		p.content,
		p.artifact_hash,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Evidence_Recorded,
		payload,
		p.session_id,
		p.attempt_id,
	) or_return
	return replayed_result(replayed), nil
}

// -- assessment_record ---------------------------------------------------------

UNKNOWN_SCORE :: -1

Assessment_Record_Params :: struct {
	session_id:     string,
	concept_id:     string,
	dimension:      string,
	score:          json.Value, // 0..3 or "unknown"
	rationale:      string,
	rubric_version: string,
	evidence_ids:   []string,
}

op_assessment_record :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Assessment_Record_Params) or_return
	nonempty(
		{"session_id", p.session_id},
		{"concept_id", p.concept_id},
		{"dimension", p.dimension},
		{"rationale", p.rationale},
		{"rubric_version", p.rubric_version},
	) or_return
	if _, ok := parse_enum(DIMENSION_NAMES, p.dimension); !ok {
		return {}, invalid("dimension must be recognition, approach, approach_invariant, correctness, complexity, implementation_testing, or transfer")
	}
	score := parse_score(p.score) or_return
	nonempty_items("evidence_ids", p.evidence_ids) or_return
	if score != UNKNOWN_SCORE && len(p.evidence_ids) == 0 {
		return {}, fail(.Invalid_Evidence, "an observed score requires at least one evidence id; use unknown when nothing was observed")
	}
	for id in p.evidence_ids {
		if !is_session_evidence(store, p.session_id, id) {
			return {}, fail(.Invalid_Evidence, fmt.aprintf("evidence %q does not exist in this session", id))
		}
	}

	payload := Assessment_Recorded {
		p.concept_id,
		p.dimension,
		score,
		p.rationale,
		p.rubric_version,
		p.evidence_ids,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Assessment_Recorded,
		payload,
		session_id = p.session_id,
	) or_return
	return replayed_result(replayed), nil
}

// Section 9 scores: 0..3, or "unknown" when nothing was observed.
parse_score :: proc(v: json.Value) -> (int, Op_Error) {
	#partial switch s in v {
	case string:
		if s == "unknown" {
			return UNKNOWN_SCORE, nil
		}
	case json.Integer:
		if s >= 0 && s <= 3 {
			return int(s), nil
		}
	}
	return 0, invalid(`score must be 0..3 or "unknown"`)
}

is_session_evidence :: proc(store: ^Store, session_id, event_id: string) -> bool {
	for ev in store.events {
		if ev.event_id == event_id &&
		   ev.session_id == session_id &&
		   is_event(ev, EVIDENCE_EVENTS) {
			return true
		}
	}
	return false
}

replayed_result :: proc(replayed: bool) -> (res: Result) {
	Data :: struct {
		replayed: Replayed `json:",omitempty"`,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed)})
	return
}

// -- session_close -------------------------------------------------------------

Session_Close_Params :: struct {
	session_id:     string,
	reason:         string,
	review_outcome: string,
}

op_session_close :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Session_Close_Params) or_return
	nonempty({"session_id", p.session_id}, {"reason", p.reason}) or_return
	reason, known_reason := parse_enum(CLOSURE_REASON_NAMES, p.reason)
	if !known_reason || reason == .None {
		return {}, invalid("reason must be completed, stopped, or abandoned")
	}
	if p.review_outcome != "" {
		if _, ok := review_outcome_from_string(p.review_outcome); !ok {
			return {}, invalid("review_outcome is not a supported review outcome")
		}
	}

	Data :: struct {
		replayed:    Replayed `json:",omitempty"`,
		session_id:  string,
		independent: Maybe(bool) `json:",omitempty"`,
		revision:    Maybe(int) `json:",omitempty"`,
	}

	// An identical retry replays before the already-closed guard, so retries
	// succeed while a session still never advances its reviews twice.
	for ev in store.events {
		if ev.request_id == req.request_id && ev.type == EVENT_TYPE_NAMES[.Session_Closed] {
			if ev.request_hash == req.request_hash {
				res.data = to_json(Data{replayed = true, session_id = p.session_id})
				return
			}
			break
		}
	}

	st := fold(store)
	session := find_session(&st, p.session_id)
	if session == nil {
		return {}, fail(.Not_Found, fmt.aprintf("no session %q", p.session_id))
	}
	if session.status == .Closed {
		return {}, fail(.Request_Conflict, "this session is already closed; use a new session to continue this work")
	}
	independent := reason == .Completed && qualifies_independent(&st, session, ctx.workspace)
	if p.review_outcome != "" && p.review_outcome != "independent_correct" {
		independent = false
	}

	// Review updates are computed once here and frozen into the event.
	payload := Session_Closed {
		reason         = p.reason,
		independent    = independent,
		review_updates = due_review_updates(
			&st,
			session,
			reason,
			independent,
			p.review_outcome,
			context_now(ctx),
		),
	}
	ev, replayed := commit(
		ctx,
		store,
		req,
		.Session_Closed,
		payload,
		session_id = p.session_id,
	) or_return

	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), p.session_id, independent, ev.sequence})
	append(&res.next_actions, "run review_due to see scheduled retrieval tasks")
	return
}

// due_review_updates computes a closing session's review changes. A review
// session advances its own item; any other completed session schedules one
// initial recall item per concept it touched (section 9: assisted study and
// independent solves alike start at the initial interval).
due_review_updates :: proc(
	st: ^State,
	session: ^Session_State,
	reason: Closure_Reason,
	independent: bool,
	review_outcome: string,
	now: time.Time,
) -> Raw_JSON {
	if reason != .Completed {
		return "[]"
	}
	if session.review_item_id != "" {
		review := find_review(st, session.review_item_id)
		if review == nil {
			return "[]"
		}
		outcome_name := review_outcome
		if outcome_name == "" {
			outcome_name = "independent_correct" if independent else "correct_after_help"
		}
		outcome, _ := review_outcome_from_string(outcome_name)
		index, due := apply_outcome(review.interval_index, review.due_ts, outcome, now)
		return to_json(
			[]Review_Advanced {
				{"update", review.id, index, due, outcome_name, REVIEW_STATE_NAMES[.Open]},
			},
		)
	}

	due := rfc3339_utc(time.time_add(now, INITIAL_INTERVAL_DAYS * DAY))
	credit := CREDIT_NAMES[.Independent if independent else .Assisted]
	scheduled := make([dynamic]Review_Scheduled)
	seen := make([dynamic]string)
	concepts: for c in session.concepts {
		if contains(seen[:], c) {
			continue
		}
		for r in st.reviews {
			if r.concept == c && r.task_type == "recall" && r.state != .Completed {
				continue concepts
			}
		}
		append(&seen, c)
		append(&scheduled, Review_Scheduled{c, "recall", credit, due})
	}
	return to_json(scheduled[:])
}
