package learn

// Spaced-review queries and learner-driven review changes (section 9). The
// scheduling policy itself lives in schedule.odin.

import "core:strings"

// Each due review is budgeted at roughly this many minutes.
MINUTES_PER_REVIEW :: 10
MAX_DUE_REVIEWS :: 100

Review_Due_Params :: struct {
	date:                string, // YYYY-MM-DD (end of that day) or an RFC 3339 instant
	time_budget_minutes: int,
	concept_id:          string,
}

op_review_due :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Review_Due_Params) or_return
	now := rfc3339_utc(context_now(ctx))
	switch {
	case len(p.date) == len("YYYY-MM-DD"):
		now = strings.concatenate({p.date, "T23:59:59Z"})
	case p.date != "":
		now = p.date
	}
	limit :=
		max(1, p.time_budget_minutes / MINUTES_PER_REVIEW) if p.time_budget_minutes > 0 else MAX_DUE_REVIEWS

	st := fold(store)
	due := make([dynamic]Review_View)
	for r in st.reviews {
		if r.state != .Open ||
		   r.due_ts > now ||
		   (p.concept_id != "" && r.concept != p.concept_id) {
			continue
		}
		append(&due, review_view(r))
		if len(due) >= limit {
			break
		}
	}

	Data :: struct {
		due:   []Review_View,
		count: int,
	}
	res.data = to_json(Data{due[:], len(due)})
	return
}

Review_Update_Params :: struct {
	review_id: string,
	action:    string, // snooze | resume
	until:     string,
}

op_review_update :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Review_Update_Params) or_return
	nonempty({"review_id", p.review_id}, {"action", p.action}) or_return
	state: Review_State
	switch p.action {
	case "snooze":
		state = .Snoozed
	case "resume":
		state = .Open
	case:
		return {}, invalid("action must be snooze or resume; completing a review happens through a review session's assessment")
	}

	_, replayed := commit(
		ctx,
		store,
		req,
		.Review_Updated,
		Review_Updated{p.review_id, p.action, p.until},
	) or_return

	Data :: struct {
		replayed:  Replayed `json:",omitempty"`,
		review_id: string,
		state:     string,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), p.review_id, REVIEW_STATE_NAMES[state]})
	return
}
