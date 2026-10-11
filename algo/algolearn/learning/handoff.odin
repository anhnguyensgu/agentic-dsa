package learning

// Compact, evidence-backed session handoff for context loss and host changes
// (section 14). It deliberately excludes credentials and full conversations.

import "core:fmt"

Handoff_Attempt :: struct {
	record:                 Attempt_View,
	current_source_hash:    string,
	changed_since_creation: bool,
}

Pending_Job :: struct {
	job_id:      string,
	provider:    string,
	remote_id:   string,
	problem_key: string,
	source_hash: string,
	state:       string,
}

Handoff :: struct {
	schema_version:          int,
	engine_version:          string,
	catalog_version:         string,
	workspace_id:            string,
	workspace_revision:      int,
	profile:                 Raw_JSON,
	session:                 Session_View,
	attempt:                 Maybe(Handoff_Attempt), // null before the first attempt
	hints:                   []Event,
	results_and_assessments: []Event,
	pending_jobs:            []Pending_Job,
	next_action:             string,
}

HANDOFF_RESULT_EVENTS :: bit_set[Event_Type]{.Runner_Observed, .Job_Observed, .Judge_Observed, .Assessment_Recorded}

session_handoff :: proc(store: ^Store, session_id: string) -> (doc: Raw_JSON, found: bool) {
	st := fold(store)
	session := find_session(&st, session_id)
	if session == nil {
		return "", false
	}
	handoff := Handoff{
		schema_version     = SCHEMA_VERSION,
		engine_version     = ENGINE_VERSION,
		catalog_version    = CATALOG_VERSION,
		workspace_id       = st.workspace_id,
		workspace_revision = st.revision,
		profile            = profile_view(st.profile),
		session            = session_view(session^),
		next_action        = session.next_action,
	}

	// The session's latest attempt, and whether its source moved since.
	#reverse for a in st.attempts {
		if a.session_id == session_id {
			current_hash, _ := read_source_hash(join(store.workspace, a.source_path))
			handoff.attempt = Handoff_Attempt{attempt_view(a), current_hash, current_hash != "" && current_hash != a.source_hash}
			break
		}
	}

	hints := make([dynamic]Event)
	results := make([dynamic]Event)
	jobs := make([dynamic]Pending_Job)
	for ev in store.events {
		if ev.session_id != session_id {
			continue
		}
		switch {
		case is_event(ev, {.Hint_Delivered}):
			append(&hints, ev)
		case is_event(ev, HANDOFF_RESULT_EVENTS):
			append(&results, ev)
		case is_event(ev, {.Submission_Sent}):
			sent: Submission_Sent
			decode(string(ev.payload), &sent)
			if job, job_found := find_job(store, sent.job_id); job_found && job.state != "terminal" {
				append(&jobs, Pending_Job{job.job_id, job.provider, job.remote_id, job.problem_key, job.source_hash, job.state})
			}
		}
	}
	handoff.hints, handoff.results_and_assessments, handoff.pending_jobs = hints[:], results[:], jobs[:]
	return to_json(handoff), true
}

// write_session_handoff refreshes handoff.json and a short handoff.md.
write_session_handoff :: proc(store: ^Store, session_id: string) -> Engine_Error {
	doc, found := session_handoff(store, session_id)
	if !found {
		return .Not_Found
	}
	dir := learning_path(store.workspace, "sessions", session_id)
	if write_private_file(join(dir, "handoff.json"), string(doc)) != nil {
		return .Storage_Error
	}
	st := fold(store)
	s := find_session(&st, session_id)
	markdown := fmt.aprintf(
		"# Algorithm Learning handoff\n\n" +
		"Session: `%s`\n\n" +
		"Objective: %s\n\n" +
		"Mode: `%s`; activity: `%s`; status: `%s`\n\n" +
		"Learner summary: %s\n\n" +
		"Next action: %s\n\n" +
		"Authoritative detail is in `handoff.json` at workspace revision %d.\n",
		s.id,
		s.objective,
		MODE_NAMES[s.mode],
		ACTIVITY_NAMES[s.activity],
		SESSION_STATUS_NAMES[s.status],
		s.summary,
		s.next_action,
		st.revision,
	)
	if write_private_file(join(dir, "handoff.md"), markdown) != nil {
		return .Storage_Error
	}
	return nil
}
