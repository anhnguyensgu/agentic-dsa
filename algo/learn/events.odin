package learn

// Event types and their payloads. Field order is the on-disk order, so
// reordering fields changes the bytes of every new event.

Event_Type :: enum {
	Workspace_Initialized,
	Profile_Updated,
	Session_Started,
	Session_Checkpoint,
	Session_Closed,
	Attempt_Started,
	Case_Added,
	Hint_Delivered,
	Evidence_Recorded,
	Assessment_Recorded,
	Runner_Observed,
	Job_Observed,
	Judge_Observed,
	Review_Updated,
	Submission_Prepared,
	Submission_Sent,
	Submission_Outcome_Unknown,
	Export_Created,
	Legacy_Imported,
	Content_Redacted,
	Private_Event_Redacted,
}

EVENT_TYPE_NAMES := [Event_Type]string {
	.Workspace_Initialized      = "workspace_initialized",
	.Profile_Updated            = "profile_updated",
	.Session_Started            = "session_started",
	.Session_Checkpoint         = "session_checkpoint",
	.Session_Closed             = "session_closed",
	.Attempt_Started            = "attempt_started",
	.Case_Added                 = "case_added",
	.Hint_Delivered             = "hint_delivered",
	.Evidence_Recorded          = "evidence_recorded",
	.Assessment_Recorded        = "assessment_recorded",
	.Runner_Observed            = "runner_observed",
	.Job_Observed               = "job_observed",
	.Judge_Observed             = "judge_observed",
	.Review_Updated             = "review_updated",
	.Submission_Prepared        = "submission_prepared",
	.Submission_Sent            = "submission_sent",
	.Submission_Outcome_Unknown = "submission_outcome_unknown",
	.Export_Created             = "export_created",
	.Legacy_Imported            = "legacy_imported",
	.Content_Redacted           = "content_redacted",
	.Private_Event_Redacted     = "private_event_redacted",
}

// Events an assessment may cite as evidence.
EVIDENCE_EVENTS :: bit_set[Event_Type] {
	.Evidence_Recorded,
	.Runner_Observed,
	.Job_Observed,
	.Judge_Observed,
}

is_event :: proc(ev: Event, kinds: bit_set[Event_Type]) -> bool {
	kind, known := parse_enum(EVENT_TYPE_NAMES, ev.type)
	return known && kind in kinds
}

// Workspace_Initialized and Profile_Updated carry a full Profile.

Session_Started :: struct {
	objective:      string,
	mode:           string,
	problem_key:    string,
	review_item_id: string,
	budget_minutes: Maybe(int) `json:",omitempty"`,
	concept_ids:    []string,
}

Session_Checkpoint :: struct {
	activity:    string,
	summary:     string,
	next_action: string,
	pause:       bool,
}

Session_Closed :: struct {
	reason:         string,
	independent:    bool,
	review_updates: Raw_JSON, // []Review_Update, frozen when the session closed
}

// A review update either advances an existing item (action "update") or
// schedules a new one; each shape keeps only its own fields on disk.
Review_Update :: struct {
	action:         string,
	id:             string,
	interval_index: int,
	due_ts:         string,
	last_outcome:   string,
	state:          string,
	concept:        string,
	task_type:      string,
	credit:         string,
}

Review_Advanced :: struct {
	action:         string,
	id:             string,
	interval_index: int,
	due_ts:         string,
	last_outcome:   string,
	state:          string,
}

Review_Scheduled :: struct {
	concept:   string,
	task_type: string,
	credit:    string,
	due_ts:    string,
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

Case_Added :: struct {
	case_id:         string,
	name:            string,
	input:           string,
	expected:        Maybe(string), // null when the case has no oracle
	comparator:      string,
	provenance:      string,
	oracle_verified: bool,
	oracle_basis:    string,
}

Hint_Delivered :: struct {
	level:       int,
	content:     string,
	concept_ids: []string,
}

Evidence_Recorded :: struct {
	evidence_type: string,
	producer:      string,
	concept_id:    string,
	content:       string,
	artifact_hash: string,
}

Assessment_Recorded :: struct {
	concept_id:     string,
	dimension:      string,
	score:          int, // 0..3, or -1 for "unknown"
	rationale:      string,
	rubric_version: string,
	evidence_ids:   []string,
}

Runner_Observed :: struct {
	artifact_id:     string,
	source_hash:     string,
	outcome:         string,
	verified_passed: int,
	verified_failed: int,
	unchecked:       int,
}

Job_Observed :: struct {
	job_id:          string,
	intent_id:       string,
	provider:        string,
	remote_id:       string,
	state:           string,
	verdict:         string,
	source_hash:     string,
	provider_result: string,
}

Review_Updated :: struct {
	id:     string,
	action: string,
	until:  string,
}

Submission_Prepared :: struct {
	intent_id:     string,
	provider:      string,
	problem_key:   string,
	provider_id:   string,
	slug:          string,
	language:      string,
	source_path:   string,
	source_hash:   string,
	snapshot_path: string,
	account_alias: string,
}

Submission_Sent :: struct {
	job_id:                  string,
	intent_id:               string,
	authorization_reference: string,
	provider:                string,
	remote_id:               string,
	problem_key:             string,
	language:                string,
	source_hash:             string,
}

Submission_Outcome_Unknown :: struct {
	intent_id: string,
	reason:    string,
}

Export_Created :: struct {
	export_id:    string,
	scope:        string,
	path:         string,
	content_hash: string,
}

Legacy_Imported :: struct {
	source_hash:                  string,
	unresolved_events:            int,
	mastery_inferred:             bool,
	legacy_test_command_executed: bool,
}
