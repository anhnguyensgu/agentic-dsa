package learn

// Next-step planning and progress views (sections 8 and 9).

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

DEFAULT_BUDGET_MINUTES :: 30
MAX_SUGGESTIONS :: 3

Plan_Next_Params :: struct {
	goal:                string,
	time_budget_minutes: int,
	topic:               string,
	mode:                string,
	language:            string,
	provider:            string, // suggest concrete problems the curriculum maps for this provider
}

Review_Candidate :: struct {
	kind:      string,
	review_id: string,
	concept:   string,
	reason:    string,
}

// Practice_Candidate names a concept, not a problem: there is no bundled
// problem set, so the agent picks a provider problem using the tags.
Practice_Candidate :: struct {
	kind:                   string,
	concept:                string,
	title:                  string,
	leetcode_tags:          []string,
	hide_tags_from_learner: bool,
	reason:                 string,
	capability_limitations: []string,
}

// Problem_Candidate is a concrete provider problem from the curriculum's
// mapping, named and ordered by the provider's cached catalogue when there is
// one.
Problem_Candidate :: struct {
	kind:                      string, // "problem"
	problem_key:               string,
	concept:                   string,
	title:                     string,
	name:                      string,
	difficulty:                int, // 0 without a cached catalogue
	in_progress:               bool, // attempted, but no verified passing run yet
	hide_concept_from_learner: bool,
	reason:                    string,
}

// Catalogue is a provider track's problem list as the provider caches it in
// problems/<provider>/.cache/<track>.json (`algo judge exercism list`).
Catalogue :: struct {
	schema_version: int,
	track:          string,
	exercises:      []Catalogue_Entry,
}

Catalogue_Entry :: struct {
	slug:       string,
	name:       string,
	difficulty: int,
}

// op_plan_next is a deterministic policy: one due review first, then new
// practice on the first unmet prerequisite or goal concept. With a provider,
// the new practice is concrete problems from the curriculum's mapping.
op_plan_next :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Plan_Next_Params) or_return
	st := fold(store)
	budget := first_nonzero(
		p.time_budget_minutes,
		st.profile.time_budget_minutes,
		DEFAULT_BUDGET_MINUTES,
	)
	if budget < MIN_BUDGET_MINUTES || budget > MAX_BUDGET_MINUTES {
		return {}, invalid("time_budget_minutes must be between 5 and 480")
	}
	language := first_nonempty(p.language, st.profile.language, "odin")
	mode := enum_value(MODE_NAMES, "mode", first_nonempty(p.mode, "guided")) or_return
	if _, known := provider_traits(p.provider); p.provider != "" && !known {
		return {}, invalid(fmt.aprintf("provider must be one of %s", strings.join(provider_names(), ", ")))
	}
	hidden := mode == .Independent || mode == .Assessment

	candidates := make([dynamic]Raw_JSON)
	now := rfc3339_utc(context_now(ctx))
	for r in st.reviews {
		if r.state == .Open && r.due_ts <= now {
			append(
				&candidates,
				to_json(
					Review_Candidate {
						"review",
						r.id,
						r.concept,
						fmt.aprintf("review scheduled for %s is due", r.due_ts),
					},
				),
			)
			break
		}
	}

	topic := p.topic if p.topic != "" else next_topic(&st)
	concept, known := find_concept(concept_group(topic))
	limitations := make([dynamic]string)
	if language == "odin" {
		append(
			&limitations,
			"LeetCode does not judge Odin; Odin practice on LeetCode is local only",
		)
	}
	reason := fmt.aprintf(
		"%s is the next concept to practise; choose a provider problem the learner has not attempted that fits the %d-minute budget",
		topic,
		budget,
	)
	if !known {
		reason = fmt.aprintf(
			"%s is not in a curriculum group; choose a provider problem for it that fits the %d-minute budget",
			topic,
			budget,
		)
	}
	problems: []Problem_Candidate
	if p.provider != "" {
		cached: bool
		problems, cached = suggest_problems(
			store,
			&st,
			ctx.workspace,
			p.provider,
			language,
			topic,
			hidden,
		)
		switch {
		case len(problems) == 0:
			append(
				&res.warnings,
				fmt.aprintf(
					"the curriculum maps no unpassed %s problem from %s on; choose one with the concept tags",
					p.provider,
					topic,
				),
			)
		case !cached:
			append(
				&res.warnings,
				fmt.aprintf(
					"the %s catalogue for %s is not cached, so problems are unfiltered and unsorted; run `algo judge %s list --track %s`",
					p.provider,
					language,
					p.provider,
					language,
				),
			)
		}
	}
	for problem in problems {
		append(&candidates, to_json(problem))
	}
	if len(problems) == 0 {
		append(
			&candidates,
			to_json(
				Practice_Candidate {
					kind = "new_practice",
					concept = topic,
					title = concept.title,
					leetcode_tags = concept.leetcode_tags,
					hide_tags_from_learner = hidden,
					reason = reason,
					capability_limitations = limitations[:],
				},
			),
		)
	}

	attempted := make([dynamic]string)
	for a in st.attempts {
		note_concept(&attempted, a.problem_key)
	}

	Data :: struct {
		candidates:             []Raw_JSON,
		target_concept:         string,
		time_budget_minutes:    int,
		language:               string,
		attempted_problem_keys: []string,
	}
	res.data = to_json(Data{candidates[:], topic, budget, language, attempted[:]})
	return
}

// suggest_problems names up to MAX_SUGGESTIONS problems from provider that
// practise topic's group and have no verified passing run. When that group
// maps none, it moves on through later groups the learner has not mastered.
// Problems in progress come first, then easier ones. cached reports whether
// the provider's catalogue for track filtered and ordered them.
suggest_problems :: proc(
	store: ^Store,
	st: ^State,
	workspace, provider, track, topic: string,
	hidden: bool,
) -> (
	problems: []Problem_Candidate,
	cached: bool,
) {
	concepts, _ := curriculum_concepts()
	catalogue: Catalogue
	if valid_track(track) {
		path := join(
			workspace,
			"problems",
			provider,
			".cache",
			strings.concatenate({track, ".json"}),
		)
		if data, read_err := os.read_entire_file(path, context.allocator); read_err == nil {
			cached = decode(string(data), &catalogue)
		}
	}

	passed := make([dynamic]string)
	for ev in store.events {
		if ev.type != EVENT_TYPE_NAMES[.Runner_Observed] {
			continue
		}
		run: Runner_Observed
		if decode(string(ev.payload), &run) && run.outcome == "passed" {
			if a := find_attempt(st, ev.attempt_id); a != nil {
				note_concept(&passed, a.problem_key)
			}
		}
	}
	attempted := make([dynamic]string)
	for a in st.attempts {
		note_concept(&attempted, a.problem_key)
	}

	group := concept_group(topic)
	start := 0
	for c, i in concepts {
		if c.id == group {
			start = i
		}
	}
	list := make([dynamic]Problem_Candidate)
	for c, i in concepts[start:] {
		if i > 0 && mastered(st, c.id) {
			continue
		}
		for slug in c.problems[provider] {
			key := strings.concatenate({provider, ":", slug})
			if contains(passed[:], key) {
				continue
			}
			candidate := Problem_Candidate {
				kind                      = "problem",
				problem_key               = key,
				concept                   = c.id,
				title                     = c.title,
				name                      = slug,
				in_progress               = contains(attempted[:], key),
				hide_concept_from_learner = hidden,
			}
			if cached {
				listed := false
				for entry in catalogue.exercises {
					if entry.slug == slug {
						candidate.name, candidate.difficulty = entry.name, entry.difficulty
						listed = true
					}
				}
				if !listed {
					continue // the track does not have it
				}
			}
			switch {
			case candidate.in_progress:
				candidate.reason = fmt.aprintf(
					"continue the attempt on %s, which has no verified passing run yet",
					candidate.name,
				)
			case c.id == group:
				candidate.reason = fmt.aprintf(
					"practises %s, the concept to work on next",
					c.title,
				)
			case:
				candidate.reason = fmt.aprintf(
					"%s maps no unpassed %s problem, so this practises %s, the next concept that does",
					group,
					provider,
					c.title,
				)
			}
			append(&list, candidate)
		}
		if len(list) > 0 {
			break
		}
	}
	slice.stable_sort_by(list[:], proc(a, b: Problem_Candidate) -> bool {
		if a.in_progress != b.in_progress {
			return a.in_progress
		}
		return a.difficulty < b.difficulty
	})
	return list[:min(len(list), MAX_SUGGESTIONS)], cached
}

// next_topic is the first curriculum group not yet mastered, or its first
// unmet prerequisite.
next_topic :: proc(st: ^State) -> string {
	concepts, ok := curriculum_concepts()
	if !ok || len(concepts) == 0 {
		return ""
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
	return concepts[0].id
}

// mastered reports an independent or retained concept. A group also counts as
// mastered when one of its sub-patterns is.
mastered :: proc(st: ^State, concept_id: string) -> bool {
	for c in st.concepts {
		in_group := c.concept_id == concept_id || concept_group(c.concept_id) == concept_id
		if in_group && (c.state == .Independent || c.state == .Retained) {
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
op_progress_get :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
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
		uploaded:        int, // sent to a provider that reports no verdict
	}
	Counts :: struct {
		active_sessions:      int,
		closed_sessions:      int,
		open_reviews:         int,
		assisted_sessions:    int,
		independent_sessions: int,
	}

	counts := Counts {
		open_reviews = len(st.reviews),
	}
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
			case "passed":
				execution.verified_passed_runs += 1
			case "failed":
				execution.failed_runs += 1
			case:
				execution.unverified_runs += 1
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
		case .Submission_Sent:
			p: Submission_Sent
			decode(string(ev.payload), &p)
			if traits, known := provider_traits(p.provider); known && traits.check == .None {
				judge.uploaded += 1
			}
		}
	}

	// Every curriculum group appears in curriculum order, followed by its
	// recorded sub-patterns; concepts outside every group come last.
	concepts := make([dynamic]Concept_View)
	listed := make([dynamic]string)
	curriculum, _ := curriculum_concepts()
	for group in curriculum {
		state := Concept_State {
			concept_id = group.id,
			state      = .Unknown,
		}
		for known in st.concepts {
			if known.concept_id == group.id {
				state = known
			}
		}
		append(&concepts, concept_view(state))
		append(&listed, group.id)
		for known in st.concepts {
			if known.concept_id != group.id && concept_group(known.concept_id) == group.id {
				append(&concepts, concept_view(known))
				append(&listed, known.concept_id)
			}
		}
	}
	for known in st.concepts {
		if !contains(listed[:], known.concept_id) {
			append(&concepts, concept_view(known))
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
