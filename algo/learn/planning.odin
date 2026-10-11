package learn

// Next-step planning and progress views (sections 8 and 9).

import "core:fmt"
import "core:strings"

DEFAULT_BUDGET_MINUTES :: 30
MAX_PLAN_CANDIDATES :: 3

Plan_Next_Params :: struct {
	goal:                 string,
	time_budget_minutes:  int,
	topic:                string,
	mode:                 string,
	language:             string,
	offline:              bool,
	exclude_problem_keys: []string,
}

Review_Candidate :: struct {
	kind:      string,
	review_id: string,
	concept:   string,
	reason:    string,
}

Practice_Candidate :: struct {
	kind:                   string,
	concept:                string,
	problem:                Problem_View,
	reason:                 string,
	capability_limitations: []string,
}

// op_plan_next is a deterministic policy: one due review first, then new
// practice on the first unmet prerequisite or goal concept, in stable
// catalogue order.
op_plan_next :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Plan_Next_Params) or_return
	st := fold(store)
	budget := first_nonzero(p.time_budget_minutes, st.profile.time_budget_minutes, DEFAULT_BUDGET_MINUTES)
	if budget < MIN_BUDGET_MINUTES || budget > MAX_BUDGET_MINUTES {
		return {}, invalid("time_budget_minutes must be between 5 and 480")
	}
	language := first_nonempty(p.language, st.profile.language, "odin")
	mode := enum_value(MODE_NAMES, "mode", first_nonempty(p.mode, "guided")) or_return
	nonempty_items("exclude_problem_keys", p.exclude_problem_keys) or_return

	candidates := make([dynamic]Raw_JSON)
	now := rfc3339_utc(context_now(ctx))
	for r in st.reviews {
		if r.state == .Open && r.due_ts <= now {
			append(&candidates, to_json(Review_Candidate{"review", r.id, r.concept, fmt.aprintf("review scheduled for %s is due", r.due_ts)}))
			break
		}
	}

	topic := p.topic if p.topic != "" else next_topic(&st)
	problems, catalog_err := catalog_problems()
	if catalog_err != nil {
		return {}, fail(catalog_err, "the bundled catalogue could not be read")
	}
	audience := Audience.Assessment if mode == .Assessment || mode == .Independent else Audience.Learning
	for problem in problems {
		if len(candidates) >= MAX_PLAN_CANDIDATES {
			break
		}
		if contains(p.exclude_problem_keys, problem.problem_key) ||
		   !contains(problem.concept_ids, topic) ||
		   problem.effort_minutes > budget ||
		   !supports_language(problem, language) ||
		   attempted(&st, problem.problem_key) {
			continue
		}
		limitations := make([dynamic]string)
		if problem.provider == "leetcode" && language == "odin" {
			append(&limitations, "Odin is local-practice only for LeetCode")
		}
		append(&candidates, to_json(Practice_Candidate{
			kind                   = "new_practice",
			concept                = topic,
			problem                = problem_view(problem, audience),
			reason                 = fmt.aprintf("targets %s, fits the %d-minute budget, and has no recorded prior attempt", topic, budget),
			capability_limitations = limitations[:],
		}))
	}

	Data :: struct {
		candidates:          []Raw_JSON,
		target_concept:      string,
		time_budget_minutes: int,
		language:            string,
	}
	res.data = to_json(Data{candidates[:], topic, budget, language})
	if len(candidates) == 0 {
		append(&res.warnings, "no bundled problem satisfies the current constraints; choose a cached review or a clearly labelled local micro-exercise")
	}
	return
}

// next_topic is the first curriculum concept not yet mastered, or its first
// unmet prerequisite.
next_topic :: proc(st: ^State) -> string {
	concepts, ok := curriculum_concepts()
	if !ok {
		return "foundations"
	}
	for c in concepts {
		if mastered(st, c.id) {
			continue
		}
		for prerequisite in c.prerequisites {
			if !mastered(st, prerequisite) {
				return prerequisite
			}
		}
		return c.id
	}
	return "foundations"
}

mastered :: proc(st: ^State, concept_id: string) -> bool {
	for c in st.concepts {
		if c.concept_id == concept_id && (c.state == .Independent || c.state == .Retained) {
			return true
		}
	}
	return false
}

attempted :: proc(st: ^State, problem_key: string) -> bool {
	for a in st.attempts {
		if a.problem_key == problem_key {
			return true
		}
	}
	return false
}

first_nonzero :: proc(values: ..int) -> int {
	for v in values {
		if v != 0 {
			return v
		}
	}
	return 0
}

first_nonempty :: proc(values: ..string) -> string {
	for v in values {
		if v != "" {
			return v
		}
	}
	return ""
}

// -- progress_get --------------------------------------------------------------

Progress_Get_Params :: struct {
	goal:       string,
	topic:      string,
	date_scope: string,
}

// Separate views (section 9): execution and judge evidence are never folded
// into learning claims.
op_progress_get :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	params(input, Progress_Get_Params) or_return
	st := fold(store)

	Execution :: struct {
		verified_passed_runs: int,
		failed_runs:          int,
		unverified_runs:      int,
	}
	Judge :: struct {
		accepted:        int,
		pending:         int,
		outcome_unknown: int,
	}
	Counts :: struct {
		active_sessions:      int,
		closed_sessions:      int,
		open_reviews:         int,
		assisted_sessions:    int,
		independent_sessions: int,
	}

	counts := Counts{open_reviews = len(st.reviews)}
	for s in st.sessions {
		if s.status != .Closed {
			counts.active_sessions += 1
			continue
		}
		counts.closed_sessions += 1
		if s.independent_qualified {
			counts.independent_sessions += 1
		} else if s.closure_reason == .Completed {
			counts.assisted_sessions += 1
		}
	}

	execution: Execution
	judge: Judge
	for ev in store.events {
		kind, _ := parse_enum(EVENT_TYPE_NAMES, ev.type)
		#partial switch kind {
		case .Runner_Observed:
			p: Runner_Observed
			decode(string(ev.payload), &p)
			switch p.outcome {
			case "passed": execution.verified_passed_runs += 1
			case "failed": execution.failed_runs += 1
			case:          execution.unverified_runs += 1
			}
		case .Job_Observed:
			p: Job_Observed
			decode(string(ev.payload), &p)
			if p.state != "terminal" {
				judge.pending += 1
			} else if strings.to_lower(p.verdict) == "accepted" {
				judge.accepted += 1
			}
		case .Submission_Outcome_Unknown:
			judge.outcome_unknown += 1
		}
	}

	// Every curriculum concept appears, in curriculum order.
	concepts := make([dynamic]Concept_View)
	if curriculum, ok := curriculum_concepts(); ok {
		for c in curriculum {
			state := Concept_State{concept_id = c.id, state = .Unknown}
			for known in st.concepts {
				if known.concept_id == c.id {
					state = known
					break
				}
			}
			append(&concepts, concept_view(state))
		}
	} else {
		for c in st.concepts {
			append(&concepts, concept_view(c))
		}
	}

	Data :: struct {
		execution: Execution,
		judge:     Judge,
		concepts:  []Concept_View,
		counts:    Counts,
	}
	res.data = to_json(Data{execution, judge, concepts[:], counts})
	return
}
