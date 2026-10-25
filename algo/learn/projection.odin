package learn

// The projection (section 10): learner state folded from the event log. It is
// replaceable and rebuilt on demand; the log is the only source of truth.

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

// -- domain enums and their wire names -------------------------------------------

Mode :: enum {
	Guided,
	Independent,
	Assessment,
	Review,
	Worked_Example,
}

MODE_NAMES := [Mode]string {
	.Guided         = "guided",
	.Independent    = "independent",
	.Assessment     = "assessment",
	.Review         = "review",
	.Worked_Example = "worked_example",
}

Activity :: enum {
	Understanding,
	Planning,
	Implementing,
	Testing,
	Reflecting,
	Reviewing,
}

ACTIVITY_NAMES := [Activity]string {
	.Understanding = "understanding",
	.Planning      = "planning",
	.Implementing  = "implementing",
	.Testing       = "testing",
	.Reflecting    = "reflecting",
	.Reviewing     = "reviewing",
}

Session_Status :: enum {
	Active,
	Paused,
	Closed,
}

SESSION_STATUS_NAMES := [Session_Status]string {
	.Active = "active",
	.Paused = "paused",
	.Closed = "closed",
}

Closure_Reason :: enum {
	None,
	Completed,
	Stopped,
	Abandoned,
}

CLOSURE_REASON_NAMES := [Closure_Reason]string {
	.None      = "",
	.Completed = "completed",
	.Stopped   = "stopped",
	.Abandoned = "abandoned",
}

Review_State :: enum {
	Open,
	Snoozed,
	Completed,
}

REVIEW_STATE_NAMES := [Review_State]string {
	.Open      = "open",
	.Snoozed   = "snoozed",
	.Completed = "completed",
}

Credit :: enum {
	Assisted,
	Independent,
}

CREDIT_NAMES := [Credit]string {
	.Assisted    = "assisted",
	.Independent = "independent",
}

Concept_Level :: enum {
	Unknown,
	Introduced,
	Practicing,
	Independent,
	Retained,
}

CONCEPT_LEVEL_NAMES := [Concept_Level]string {
	.Unknown     = "unknown",
	.Introduced  = "introduced",
	.Practicing  = "practicing",
	.Independent = "independent",
	.Retained    = "retained",
}

Dimension :: enum {
	Recognition,
	Approach,
	Approach_Invariant,
	Correctness,
	Complexity,
	Implementation_Testing,
	Transfer,
}

DIMENSION_NAMES := [Dimension]string {
	.Recognition            = "recognition",
	.Approach               = "approach",
	.Approach_Invariant     = "approach_invariant",
	.Correctness            = "correctness",
	.Complexity             = "complexity",
	.Implementation_Testing = "implementation_testing",
	.Transfer               = "transfer",
}

// A retained concept needs an independent retrieval at least this long after
// the session it reviews.
RETENTION_DELAY :: 3 * DAY

// Hints at or above this level expose the solution itself.
SOLUTION_HINT_LEVEL :: 4

// -- projection -----------------------------------------------------------------

Profile :: struct {
	initialized:          bool `json:"-"`,
	learner_id:           string,
	goal:                 string,
	language:             string,
	timezone:             string,
	experience:           string,
	explanation_language: string,
	teaching_preferences: string,
	authorization_policy: string,
	time_budget_minutes:  int,
}

Session_State :: struct {
	id:                       string,
	objective:                string,
	mode:                     Mode,
	status:                   Session_Status,
	activity:                 Activity,
	next_action:              string,
	summary:                  string,
	closure_reason:           Closure_Reason,
	max_hint_level:           int,
	solution_exposed:         bool,
	current_attempt_id:       string,
	review_item_id:           string,
	verified_behavior:        bool,
	verified_source_hash:     string,
	independent_qualified:    bool,
	transfer_score3:          bool,
	started_ts:               string,
	closed_ts:                string,
	concepts:                 [dynamic]string,
	has_fresh_attempt:        bool,
	agent_authored_algorithm: bool,
	approach_score3:          bool,
	correctness_score3:       bool,
	complexity_score3:        bool,
}

Attempt_State :: struct {
	id:                  string,
	session_id:          string,
	problem_key:         string,
	language:            string,
	source_path:         string,
	source_hash:         string,
	runner_kind:         string,
	previous_attempt_id: string,
	fresh:               bool,
	tests_hash:          string,
	hint_count:          int,
	max_hint_level:      int,
	solution_exposed:    bool,
}

Review_Item :: struct {
	id:                string,
	concept:           string,
	task_type:         string,
	origin_session_id: string,
	state:             Review_State,
	credit:            Credit,
	interval_index:    int,
	due_ts:            string,
	last_outcome:      string,
}

Concept_State :: struct {
	concept_id:         string,
	state:              Concept_Level,
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

find_session :: proc(st: ^State, id: string) -> ^Session_State {
	for &s in st.sessions {
		if s.id == id {
			return &s
		}
	}
	return nil
}

find_attempt :: proc(st: ^State, id: string) -> ^Attempt_State {
	for &a in st.attempts {
		if a.id == id {
			return &a
		}
	}
	return nil
}

find_review :: proc(st: ^State, id: string) -> ^Review_Item {
	for &r in st.reviews {
		if r.id == id {
			return &r
		}
	}
	return nil
}

// concept returns the concept's state, starting it as introduced.
concept :: proc(st: ^State, id: string) -> ^Concept_State {
	for &c in st.concepts {
		if c.concept_id == id {
			return &c
		}
	}
	append(&st.concepts, Concept_State{concept_id = id, state = .Introduced})
	return &st.concepts[len(st.concepts) - 1]
}

note_concept :: proc(concepts: ^[dynamic]string, id: string) {
	if id != "" && !contains(concepts[:], id) {
		append(concepts, id)
	}
}

fold :: proc(store: ^Store) -> (st: State) {
	st.workspace_id, st.revision = store.workspace_id, store.revision
	for ev in store.events {
		kind, known := parse_enum(EVENT_TYPE_NAMES, ev.type)
		if known {
			apply_event(&st, ev, kind)
		}
	}
	promote_concepts(&st)
	return
}

@(private = "file")
apply_event :: proc(st: ^State, ev: Event, kind: Event_Type) {
	payload := string(ev.payload)
	session := find_session(st, ev.session_id)

	#partial switch kind {
	case .Workspace_Initialized, .Profile_Updated:
		initialized := st.profile.initialized || kind == .Workspace_Initialized
		st.profile = {}
		decode(payload, &st.profile)
		st.profile.initialized = initialized

	case .Session_Started:
		p: Session_Started
		decode(payload, &p)
		s := Session_State {
			id             = ev.session_id,
			objective      = p.objective,
			status         = .Active,
			activity       = .Understanding,
			review_item_id = p.review_item_id,
			started_ts     = ev.timestamp,
		}
		s.mode, _ = parse_enum(MODE_NAMES, p.mode)
		for c in p.concept_ids {
			note_concept(&s.concepts, c)
		}
		append(&st.sessions, s)

	case .Attempt_Started:
		p: Attempt_Started
		decode(payload, &p)
		append(
			&st.attempts,
			Attempt_State {
				id = ev.attempt_id,
				session_id = ev.session_id,
				problem_key = p.problem_key,
				language = p.language,
				source_path = p.source_path,
				source_hash = p.source_hash,
				runner_kind = p.runner_kind,
				previous_attempt_id = p.previous_attempt_id,
				fresh = p.fresh,
				tests_hash = p.tests_hash,
			},
		)
		if session != nil {
			session.current_attempt_id = ev.attempt_id
			session.has_fresh_attempt = p.fresh
		}

	case .Session_Checkpoint:
		if session == nil || session.status == .Closed {
			break
		}
		p: Session_Checkpoint
		decode(payload, &p)
		if activity, ok := parse_enum(ACTIVITY_NAMES, p.activity); ok {
			session.activity = activity
		}
		session.summary = p.summary
		session.next_action = p.next_action
		if p.pause {
			session.status = .Paused
		}

	case .Session_Closed:
		if session == nil {
			break
		}
		p: Session_Closed
		decode(payload, &p)
		session.closure_reason, _ = parse_enum(CLOSURE_REASON_NAMES, p.reason)
		session.status = .Paused if session.closure_reason == .Stopped else .Closed
		session.independent_qualified = p.independent
		session.closed_ts = ev.timestamp
		// Review updates were computed once by the closing handler and frozen
		// in the payload, so replaying the log never applies them twice.
		updates: []Review_Update
		decode(string(p.review_updates), &updates)
		for u, i in updates {
			if u.action == "update" {
				if r := find_review(st, u.id); r != nil {
					r.interval_index = u.interval_index
					r.due_ts = u.due_ts
					r.last_outcome = u.last_outcome
					r.state, _ = parse_enum(REVIEW_STATE_NAMES, u.state)
				}
				continue
			}
			credit, _ := parse_enum(CREDIT_NAMES, u.credit)
			append(
				&st.reviews,
				Review_Item {
					id = fmt.aprintf("rev_%06d_%d", ev.sequence, i),
					concept = u.concept,
					task_type = u.task_type,
					origin_session_id = ev.session_id,
					state = .Open,
					credit = credit,
					due_ts = u.due_ts,
				},
			)
		}

	case .Hint_Delivered:
		p: Hint_Delivered
		decode(payload, &p)
		if session != nil {
			session.max_hint_level = max(session.max_hint_level, p.level)
			session.solution_exposed ||= p.level >= SOLUTION_HINT_LEVEL
			for c in p.concept_ids {
				note_concept(&session.concepts, c)
			}
		}
		if a := find_attempt(st, ev.attempt_id); a != nil {
			a.hint_count += 1
			a.max_hint_level = max(a.max_hint_level, p.level)
			a.solution_exposed ||= p.level >= SOLUTION_HINT_LEVEL
		}

	case .Evidence_Recorded:
		p: Evidence_Recorded
		decode(payload, &p)
		if p.concept_id != "" {
			concept(st, p.concept_id)
		}
		if session != nil && p.producer == "agent" && p.evidence_type == "algorithm_code_change" {
			session.agent_authored_algorithm = true
		}

	case .Runner_Observed:
		p: Runner_Observed
		decode(payload, &p)
		if session != nil && session.current_attempt_id == ev.attempt_id {
			session.verified_behavior =
				p.verified_passed > 0 &&
				p.verified_failed == 0 &&
				p.unchecked == 0 &&
				p.source_hash != ""
			session.verified_source_hash = p.source_hash
		}

	case .Job_Observed:
		p: Job_Observed
		decode(payload, &p)
		accepted :=
			p.state == "terminal" &&
			strings.to_lower(p.verdict) == "accepted" &&
			p.source_hash != ""
		if accepted && session != nil && session.current_attempt_id == ev.attempt_id {
			session.verified_behavior = true
			session.verified_source_hash = p.source_hash
		}

	case .Assessment_Recorded:
		p: Assessment_Recorded
		decode(payload, &p)
		c := concept(st, p.concept_id)
		c.assessments += 1
		if p.score >= 1 {
			c.state = .Practicing
		}
		if session == nil {
			break
		}
		note_concept(&session.concepts, p.concept_id)
		if p.score == 3 && len(p.evidence_ids) > 0 {
			dimension, _ := parse_enum(DIMENSION_NAMES, p.dimension)
			#partial switch dimension {
			case .Approach, .Approach_Invariant:
				session.approach_score3 = true
			case .Correctness:
				session.correctness_score3 = true
			case .Complexity:
				session.complexity_score3 = true
			case .Transfer:
				session.transfer_score3 = true
			}
		}

	case .Review_Updated:
		p: Review_Updated
		decode(payload, &p)
		r := find_review(st, p.id)
		if r == nil {
			break
		}
		if p.action == "snooze" {
			r.state = .Snoozed
			if p.until != "" {
				r.due_ts = p.until
			}
		} else {
			r.state = .Open
		}
	}
}

// promote_concepts applies section 9: a completed session that qualified as
// an independent solve promotes its concepts; retention additionally needs
// distinct problems, an observed transfer, and a delayed independent review.
@(private = "file")
promote_concepts :: proc(st: ^State) {
	for &s in st.sessions {
		if s.status != .Closed {
			continue
		}
		for id in s.concepts {
			c := concept(st, id)
			if s.closure_reason == .Completed && s.independent_qualified {
				c.independent_solves += 1
				c.state = .Independent
			} else if c.state == .Introduced {
				c.state = .Practicing
			}
		}
	}

	for &c in st.concepts {
		problem_keys := make([dynamic]string)
		transfer_found, delayed_found := false, false
		for &s in st.sessions {
			if !s.independent_qualified || !contains(s.concepts[:], c.concept_id) {
				continue
			}
			if a := find_attempt(st, s.current_attempt_id); a != nil && a.problem_key != "" {
				note_concept(&problem_keys, a.problem_key)
			}
			transfer_found ||= s.transfer_score3
			delayed_found ||= is_delayed_review(st, &s)
		}
		c.independent_solves = len(problem_keys)
		if len(problem_keys) >= 2 && transfer_found && delayed_found {
			c.state = .Retained
		}
	}
}

// is_delayed_review reports a review session closed at least RETENTION_DELAY
// after the session its review item came from.
@(private = "file")
is_delayed_review :: proc(st: ^State, s: ^Session_State) -> bool {
	if s.mode != .Review || s.review_item_id == "" || s.closed_ts == "" {
		return false
	}
	review := find_review(st, s.review_item_id)
	if review == nil {
		return false
	}
	origin := find_session(st, review.origin_session_id)
	if origin == nil || origin.closed_ts == "" {
		return false
	}
	origin_time, origin_consumed := time.rfc3339_to_time_utc(origin.closed_ts)
	review_time, review_consumed := time.rfc3339_to_time_utc(s.closed_ts)
	return(
		origin_consumed > 0 &&
		review_consumed > 0 &&
		time.diff(origin_time, review_time) >= RETENTION_DELAY \
	)
}

// qualifies_independent is the deterministic eligibility gate for an
// independent solve (section 9): a fresh attempt whose current source is the
// one that verifiably passed, score-3 approach/correctness/complexity
// evidence, assistance no higher than level 1, and no algorithm exposure. The
// agent separately records rubric scores.
qualifies_independent :: proc(st: ^State, s: ^Session_State, workspace := "") -> bool {
	source_current := s.verified_source_hash != ""
	if source_current && workspace != "" {
		source_current = false
		if a := find_attempt(st, s.current_attempt_id); a != nil {
			current_hash, err := read_source_hash(join(workspace, a.source_path))
			source_current = err == nil && current_hash == s.verified_source_hash
		}
	}
	mode_ok := s.mode == .Independent || s.mode == .Assessment || s.mode == .Review
	unassisted := s.max_hint_level <= 1 && !s.solution_exposed && !s.agent_authored_algorithm
	scored := s.approach_score3 && s.correctness_score3 && s.complexity_score3
	return(
		mode_ok &&
		s.has_fresh_attempt &&
		s.verified_behavior &&
		source_current &&
		scored &&
		unassisted \
	)
}

// -- public views -----------------------------------------------------------------

Session_View :: struct {
	id:                    string,
	objective:             string,
	mode:                  string,
	status:                string,
	activity:              string,
	next_action:           string,
	summary:               string,
	closure_reason:        string,
	max_hint_level:        int,
	solution_exposed:      bool,
	current_attempt_id:    string,
	review_item_id:        string,
	verified_behavior:     bool,
	verified_source_hash:  string,
	independent_qualified: bool,
	transfer_score3:       bool,
	started_ts:            string,
	closed_ts:             string,
	concepts:              []string,
}

Attempt_View :: struct {
	id:                  string,
	session_id:          string,
	problem_key:         string,
	language:            string,
	source_path:         string,
	source_hash:         string,
	runner_kind:         string,
	previous_attempt_id: string,
	fresh:               bool,
	status:              string,
	hint_count:          int,
	max_hint_level:      int,
	solution_exposed:    bool,
}

Review_View :: struct {
	id:                string,
	concept:           string,
	task_type:         string,
	origin_session_id: string,
	state:             string,
	credit:            string,
	interval_index:    int,
	due_ts:            string,
	last_outcome:      string,
}

Concept_View :: struct {
	concept_id:         string,
	state:              string,
	independent_solves: int,
	assessments:        int,
}

State_View :: struct {
	schema_version: int,
	workspace_id:   string,
	revision:       int,
	profile:        Raw_JSON,
	sessions:       []Session_View,
	attempts:       []Attempt_View,
	reviews:        []Review_View,
	concepts:       []Concept_View,
}

session_view :: proc(s: Session_State) -> Session_View {
	return {
		id = s.id,
		objective = s.objective,
		mode = MODE_NAMES[s.mode],
		status = SESSION_STATUS_NAMES[s.status],
		activity = ACTIVITY_NAMES[s.activity],
		next_action = s.next_action,
		summary = s.summary,
		closure_reason = CLOSURE_REASON_NAMES[s.closure_reason],
		max_hint_level = s.max_hint_level,
		solution_exposed = s.solution_exposed,
		current_attempt_id = s.current_attempt_id,
		review_item_id = s.review_item_id,
		verified_behavior = s.verified_behavior,
		verified_source_hash = s.verified_source_hash,
		independent_qualified = s.independent_qualified,
		transfer_score3 = s.transfer_score3,
		started_ts = s.started_ts,
		closed_ts = s.closed_ts,
		concepts = s.concepts[:],
	}
}

attempt_view :: proc(a: Attempt_State) -> Attempt_View {
	return {
		id = a.id,
		session_id = a.session_id,
		problem_key = a.problem_key,
		language = a.language,
		source_path = a.source_path,
		source_hash = a.source_hash,
		runner_kind = a.runner_kind,
		previous_attempt_id = a.previous_attempt_id,
		fresh = a.fresh,
		status = "active",
		hint_count = a.hint_count,
		max_hint_level = a.max_hint_level,
		solution_exposed = a.solution_exposed,
	}
}

review_view :: proc(r: Review_Item) -> Review_View {
	return {
		id = r.id,
		concept = r.concept,
		task_type = r.task_type,
		origin_session_id = r.origin_session_id,
		state = REVIEW_STATE_NAMES[r.state],
		credit = CREDIT_NAMES[r.credit],
		interval_index = r.interval_index,
		due_ts = r.due_ts,
		last_outcome = r.last_outcome,
	}
}

concept_view :: proc(c: Concept_State) -> Concept_View {
	return {c.concept_id, CONCEPT_LEVEL_NAMES[c.state], c.independent_solves, c.assessments}
}

// An uninitialized workspace has an empty profile object.
profile_view :: proc(p: Profile) -> Raw_JSON {
	return to_json(p) if p.initialized else EMPTY_OBJECT
}

session_views :: proc(sessions: []Session_State) -> []Session_View {
	views := make([]Session_View, len(sessions))
	for s, i in sessions {
		views[i] = session_view(s)
	}
	return views
}

attempt_views :: proc(attempts: []Attempt_State) -> []Attempt_View {
	views := make([]Attempt_View, len(attempts))
	for a, i in attempts {
		views[i] = attempt_view(a)
	}
	return views
}

review_views :: proc(reviews: []Review_Item) -> []Review_View {
	views := make([]Review_View, len(reviews))
	for r, i in reviews {
		views[i] = review_view(r)
	}
	return views
}

concept_views :: proc(concepts: []Concept_State) -> []Concept_View {
	views := make([]Concept_View, len(concepts))
	for c, i in concepts {
		views[i] = concept_view(c)
	}
	return views
}

state_view :: proc(st: ^State) -> State_View {
	return {
		schema_version = SCHEMA_VERSION,
		workspace_id = st.workspace_id,
		revision = st.revision,
		profile = profile_view(st.profile),
		sessions = session_views(st.sessions[:]),
		attempts = attempt_views(st.attempts[:]),
		reviews = review_views(st.reviews[:]),
		concepts = concept_views(st.concepts[:]),
	}
}

// write_state atomically replaces the projection file.
write_state :: proc(workspace: string, st: ^State) -> Engine_Error {
	if err := write_private_file(state_path(workspace), string(to_json(state_view(st))));
	   err != nil {
		fmt.eprintln("algolearn: failed to write projection:", os.error_string(err))
		return .Storage_Error
	}
	return nil
}
