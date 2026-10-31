package learn

// The events the tools emit (schemas/event-v2.json). The engine keeps none of
// them: each result carries its events, and the host agent, or any store it
// chooses, keeps them. Ordering, deduplication, and learning judgments such
// as hints, assessments, and reviews belong to that consumer. Field order is
// the wire order.

Event :: struct {
	schema_version: int,
	event_id:       string,
	timestamp:      string, // RFC 3339 UTC
	actor:          string, // "agent:<host>" | "learner" | "tool"
	type:           string,
	session_id:     string, // the caller's session, when it passed one
	attempt_id:     string,
	payload:        Raw_JSON,
}

Event_Type :: enum {
	Attempt_Started,
	Runner_Observed,
	Submission_Sent,
	Submission_Outcome_Unknown,
	Job_Observed,
}

EVENT_TYPE_NAMES := [Event_Type]string {
	.Attempt_Started            = "attempt_started",
	.Runner_Observed            = "runner_observed",
	.Submission_Sent            = "submission_sent",
	.Submission_Outcome_Unknown = "submission_outcome_unknown",
	.Job_Observed               = "job_observed",
}

// emit adds one event to an operation's result and returns it.
emit :: proc(
	ctx: ^Context,
	res: ^Result,
	type: Event_Type,
	payload: any,
	session_id := "",
	attempt_id := "",
) -> Event {
	ev := Event {
		schema_version = SCHEMA_VERSION,
		event_id       = new_id("ev"),
		timestamp      = rfc3339_utc(context_now(ctx)),
		actor          = ctx.actor,
		type           = EVENT_TYPE_NAMES[type],
		session_id     = session_id,
		attempt_id     = attempt_id,
		payload        = to_json(payload),
	}
	append(&res.events, ev)
	return ev
}

Attempt_Started :: struct {
	problem_key:         string,
	language:            string,
	source_path:         string,
	source_hash:         string,
	runner_kind:         string,
	previous_attempt_id: string,
	fresh:               bool,
	tests_hash:          string, // the package's *_test.odin files at start (odin_test_package)
}

// Runner_Observed is self-contained: it carries every case result, so a
// consumer never needs a file the run left behind.
Runner_Observed :: struct {
	source_path:     string,
	source_hash:     string,
	runner_kind:     string,
	outcome:         string, // passed | failed | unverified | compile_error
	verified_passed: int,
	verified_failed: int,
	unchecked:       int,
	tests_modified:  bool,
	cases:           []Case_Result,
}

Submission_Sent :: struct {
	provider:                string,
	problem_key:             string,
	language:                string,
	source_path:             string,
	source_hash:             string,
	remote_id:               string, // "" for an upload
	state:                   string, // queued | uploaded
	authorization_reference: string,
	account_alias:           string,
}

Submission_Outcome_Unknown :: struct {
	provider:    string,
	problem_key: string,
	language:    string,
	source_hash: string,
	reason:      string,
}

Job_Observed :: struct {
	provider:        string,
	remote_id:       string,
	state:           string, // pending | terminal
	verdict:         string,
	source_hash:     string,
	provider_result: string,
}
