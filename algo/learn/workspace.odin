package learn

// Workspace setup, the learner profile, and whole-state reads.

import "core:fmt"
import "core:os"

MIN_BUDGET_MINUTES :: 5
MAX_BUDGET_MINUTES :: 480

// -- workspace_init ------------------------------------------------------------

Workspace_Init_Params :: struct {
	goal:                 string,
	language:             string,
	timezone:             string,
	experience:           string,
	time_budget_minutes:  int,
	learner_id:           string,
	explanation_language: string,
	teaching_preferences: string,
	authorization_policy: string,
	import_legacy:        bool,
}

Manifest :: struct {
	schema_version:     int,
	engine_version:     string,
	workspace_id:       string,
	created:            string,
	import_source_hash: string `json:",omitempty"`,
}

op_workspace_init :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Workspace_Init_Params) or_return
	// The manifest marks an initialized workspace; re-initialization is refused.
	if os.exists(manifest_path(ctx.workspace)) {
		return {}, commit_failure(.Destination_Exists)
	}
	if dir_err := ensure_dirs(ctx.workspace); dir_err != nil {
		return {}, fail(.Storage_Error, fmt.aprintf("could not create learning directories: %s", os.error_string(dir_err)))
	}
	nonempty(
		{"goal", p.goal},
		{"language", p.language},
		{"timezone", p.timezone},
		{"experience", p.experience},
	) or_return
	in_range(
		"time_budget_minutes",
		p.time_budget_minutes,
		MIN_BUDGET_MINUTES,
		MAX_BUDGET_MINUTES,
	) or_return

	profile := Profile {
		learner_id           = p.learner_id if p.learner_id != "" else "learner_local",
		goal                 = p.goal,
		language             = p.language,
		timezone             = p.timezone,
		experience           = p.experience,
		explanation_language = p.explanation_language if p.explanation_language != "" else "auto",
		teaching_preferences = p.teaching_preferences,
		authorization_policy = p.authorization_policy if p.authorization_policy != "" else "ask",
		time_budget_minutes  = p.time_budget_minutes,
	}
	ev, replayed := commit(ctx, store, req, .Workspace_Initialized, profile) or_return

	res = mutation_result(replayed)
	if os.exists(join(ctx.workspace, ".algo", "config.json")) {
		// Legacy data stays untouched; importing it is explicit (section 10).
		append(
			&res.warnings,
			"legacy .algo/config.json detected; it is preserved and can be imported with import_validate",
		)
	}
	manifest := Manifest{SCHEMA_VERSION, ENGINE_VERSION, ev.workspace_id, ev.timestamp, ""}
	if write_private_file(manifest_path(ctx.workspace), string(to_json(manifest))) != nil {
		return {}, fail(.Storage_Error, "workspace initialized but the manifest could not be written")
	}

	Data :: struct {
		replayed:     Replayed `json:",omitempty"`,
		workspace_id: string,
		revision:     int,
	}
	res.data = to_json(Data{replayed_flag(replayed), ev.workspace_id, ev.sequence})
	append(
		&res.next_actions,
		"run plan_next to choose a first objective, or session_start to begin practicing",
	)
	return
}

// -- profile_update ------------------------------------------------------------

// Absent fields keep their current value; teaching_preferences may be cleared.
Profile_Update_Params :: struct {
	learner_id:           string,
	goal:                 string,
	language:             string,
	timezone:             string,
	experience:           string,
	explanation_language: string,
	teaching_preferences: Maybe(string),
	authorization_policy: string,
	time_budget_minutes:  Maybe(int),
}

op_profile_update :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Profile_Update_Params) or_return
	envelope := ENVELOPE_FIELDS
	changed := 0
	for key in input.fields {
		if !contains(envelope[:], key) {
			changed += 1
		}
	}
	if changed == 0 {
		return {}, invalid("profile_update requires at least one preference field")
	}
	st := fold(store)
	if !st.profile.initialized {
		return {}, fail(.Not_Found, "initialize the workspace before updating its profile")
	}

	profile := st.profile
	update :: proc(field: ^string, value: string) {
		if value != "" {
			field^ = value
		}
	}
	update(&profile.learner_id, p.learner_id)
	update(&profile.goal, p.goal)
	update(&profile.language, p.language)
	update(&profile.timezone, p.timezone)
	update(&profile.experience, p.experience)
	update(&profile.explanation_language, p.explanation_language)
	update(&profile.authorization_policy, p.authorization_policy)
	if preferences, ok := p.teaching_preferences.?; ok {
		profile.teaching_preferences = preferences
	}
	if budget, ok := p.time_budget_minutes.?; ok {
		if budget < MIN_BUDGET_MINUTES || budget > MAX_BUDGET_MINUTES {
			return {}, invalid("time_budget_minutes must be between 5 and 480")
		}
		profile.time_budget_minutes = budget
	}
	_, replayed := commit(ctx, store, req, .Profile_Updated, profile) or_return

	Data :: struct {
		replayed: Replayed `json:",omitempty"`,
		profile:  Profile,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), profile})
	append(&res.next_actions, "future plans and schedules will use the updated profile")
	return
}

// -- state_get -----------------------------------------------------------------

State_Get_Params :: struct {
	session_id: string,
	detail:     string, // summary | full (default)
}

Capabilities :: struct {
	local_test:                      bool,
	kattis_remote_submission_odin:   bool,
	leetcode_remote_submission_odin: bool,
	mcp:                             bool,
	note:                            string,
}

op_state_get :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, State_Get_Params) or_return
	detail := p.detail if p.detail != "" else "full"
	if detail != "summary" && detail != "full" {
		return {}, invalid("detail must be summary or full")
	}
	st := fold(store)
	sessions := make([dynamic]Session_View)
	for s in st.sessions {
		if p.session_id == "" || s.id == p.session_id {
			append(&sessions, session_view(s))
		}
	}
	if p.session_id != "" && len(sessions) == 0 {
		return {}, fail(.Not_Found, "session does not exist")
	}
	attempts := make([dynamic]Attempt_View)
	if detail == "full" {
		for a in st.attempts {
			if p.session_id == "" || a.session_id == p.session_id {
				append(&attempts, attempt_view(a))
			}
		}
	}

	Data :: struct {
		workspace_revision: int,
		profile:            Raw_JSON,
		sessions:           []Session_View,
		attempts:           []Attempt_View,
		capabilities:       Capabilities,
	}
	res.data = to_json(
		Data {
			workspace_revision = st.revision,
			profile = profile_view(st.profile),
			sessions = sessions[:],
			attempts = attempts[:],
			capabilities = {
				local_test = true,
				kattis_remote_submission_odin = true,
				leetcode_remote_submission_odin = false,
				mcp = true,
				note = "current availability is reported by doctor; LeetCode Odin remains local-practice only",
			},
		},
	)
	if store.tail_warning != "" {
		append(&res.warnings, store.tail_warning)
	}
	return
}
