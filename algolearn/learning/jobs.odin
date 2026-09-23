package learning

// Immutable submission intents and recoverable remote jobs (section 13).
// Preparation is local. Sending happens once, only with an authorization
// reference supplied by the host after the learner requested that action.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

Submission_Intent :: struct {
	found:          bool,
	id:             string,
	attempt_id:     string,
	session_id:     string,
	provider:       string,
	problem_key:    string,
	provider_id:    string,
	slug:           string,
	language:       string,
	source_path:    string,
	source_hash:    string,
	snapshot_path:  string,
	account_alias:  string,
	sent:           bool,
	outcome_unknown: bool,
}

Remote_Job :: struct {
	found:       bool,
	id:          string,
	intent_id:   string,
	provider:    string,
	remote_id:   string,
	problem_key: string,
	language:    string,
	source_hash: string,
	state:       string,
}

find_intent :: proc(store: ^Store, intent_id: string) -> Submission_Intent {
	out: Submission_Intent
	for ev in store.events {
		payload, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err != nil { continue }
		if ev.type == "submission_prepared" && jstr(jget(payload, "intent_id")) == intent_id {
			out = Submission_Intent{
				found         = true,
				id            = intent_id,
				attempt_id    = ev.attempt_id,
				session_id    = ev.session_id,
				provider      = jstr(jget(payload, "provider")),
				problem_key   = jstr(jget(payload, "problem_key")),
				provider_id   = jstr(jget(payload, "provider_id")),
				slug          = jstr(jget(payload, "slug")),
				language      = jstr(jget(payload, "language")),
				source_path   = jstr(jget(payload, "source_path")),
				source_hash   = jstr(jget(payload, "source_hash")),
				snapshot_path = jstr(jget(payload, "snapshot_path")),
				account_alias = jstr(jget(payload, "account_alias")),
			}
		} else if jstr(jget(payload, "intent_id")) == intent_id {
			if ev.type == "submission_sent" { out.sent = true }
			if ev.type == "submission_outcome_unknown" { out.outcome_unknown = true }
		}
	}
	return out
}

find_job :: proc(store: ^Store, job_id: string) -> Remote_Job {
	out: Remote_Job
	for ev in store.events {
		if ev.type != "submission_sent" && ev.type != "job_observed" { continue }
		payload, err := json.parse(ev.payload, .JSON, parse_integers = true)
		if err != nil || jstr(jget(payload, "job_id")) != job_id { continue }
		if ev.type == "submission_sent" {
			out = Remote_Job{
				found       = true,
				id          = job_id,
				intent_id   = jstr(jget(payload, "intent_id")),
				provider    = jstr(jget(payload, "provider")),
				remote_id   = jstr(jget(payload, "remote_id")),
				problem_key = jstr(jget(payload, "problem_key")),
				language    = jstr(jget(payload, "language")),
				source_hash = jstr(jget(payload, "source_hash")),
				state       = "queued",
			}
		} else {
			out.state = jstr(jget(payload, "state"))
		}
	}
	return out
}

op_submission_prepare :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"attempt_id"}, {"account_alias"}); fail.status == .Error { return fail }
	attempt_id := jstr(jget(input, "attempt_id"))
	st := fold(store)
	ai := state_attempt_index(&st, attempt_id)
	if ai < 0 { return error_result(.Not_Found, "attempt does not exist") }
	a := &st.attempts[ai]
	problem, found := catalog_find(a.problem_key)
	if !found { return error_result(.Not_Found, "attempt problem is missing from the catalogue") }
	provider := jstr(jget(problem, "provider"))
	if provider == "leetcode" && a.language == "odin" {
		return error_result(.Unsupported_Capability, "LeetCode does not judge Odin; preserve this attempt and create a separately tracked supported-language attempt for remote submission")
	}
	source_abs := join({ctx.workspace, a.source_path})
	source_hash, herr := read_source_hash(source_abs)
	if herr != .None { return error_result(.Not_Found, "attempt source is missing") }
	intent_id := fmt_id("intent", store.revision + 1)
	ext := os.ext(a.source_path)
	if ext == "" { ext = ".txt" }
	snapshot_rel := join({LEARNING_DIR, "attempts", attempt_id, "submissions", fmt.aprintf("%s%s", intent_id, ext)})
	bytes, read_err := os.read_entire_file(source_abs, context.allocator)
	if read_err != nil { return error_result(.Not_Found, "attempt source could not be read") }
	defer delete(bytes)
	if write_private_file(join({ctx.workspace, snapshot_rel}), string(bytes)) != nil {
		return error_result(.Storage_Error, "could not persist the immutable submission snapshot")
	}
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "intent_id", intent_id)
	obj_field_str(&p, "provider", provider)
	obj_field_str(&p, "problem_key", a.problem_key)
	obj_field_str(&p, "provider_id", jstr(jget(problem, "native_id")))
	obj_field_str(&p, "slug", jstr(jget(problem, "slug")))
	obj_field_str(&p, "language", a.language)
	obj_field_str(&p, "source_path", a.source_path)
	obj_field_str(&p, "source_hash", source_hash)
	obj_field_str(&p, "snapshot_path", snapshot_rel)
	obj_field_str(&p, "account_alias", get_opt_str(input, "account_alias"))
	_, res := commit_and_project(store, ctx, req, "submission_prepared", a.session_id, attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "intent_id", intent_id)
	obj_field_str(&res.data, "provider", provider)
	obj_field_str(&res.data, "problem_key", a.problem_key)
	obj_field_str(&res.data, "language", a.language)
	obj_field_str(&res.data, "source_hash", source_hash)
	obj_field_str(&res.data, "snapshot_path", snapshot_rel)
	append(&res.next_actions, "send this exact intent only after the learner has authorized the described provider, problem, language, account, and source")
	return res
}

record_unknown_submission :: proc(ctx: ^Context, store: ^Store, req: Request, intent: ^Submission_Intent, reason: string) -> Result {
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "intent_id", intent.id)
	obj_field_str(&p, "reason", reason)
	_, committed := commit_and_project(store, ctx, req, "submission_outcome_unknown", intent.session_id, intent.attempt_id, obj_done(&p))
	if committed.status == .Error { return committed }
	res := error_result(.Submission_Outcome_Unknown, "the request may have reached the provider but no durable remote id was captured; do not resend automatically")
	append(&res.next_actions, "reconcile through provider submission history, then attach the matching receipt or ask the learner before preparing a new send")
	return res
}

op_submission_send :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"intent_id", "authorization_reference"}, {}); fail.status == .Error { return fail }
	intent_id := jstr(jget(input, "intent_id"))
	authorization := jstr(jget(input, "authorization_reference"))
	if intent_id == "" || authorization == "" { return bad_input("intent_id and authorization_reference must be non-empty strings") }
	intent := find_intent(store, intent_id)
	if !intent.found { return error_result(.Not_Found, "submission intent does not exist") }
	if intent.sent { return error_result(.Request_Conflict, "this intent was already sent; use job_check instead of submitting again") }
	if intent.outcome_unknown { return error_result(.Submission_Outcome_Unknown, "this intent has an unknown send outcome and must be reconciled before any new submission") }
	current_hash, herr := read_source_hash(join({ctx.workspace, intent.source_path}))
	if herr != .None || current_hash != intent.source_hash {
		return error_result(.Stale_Source, "the working source changed after preparation; prepare a new immutable intent")
	}
	binary := find_executable(ctx.workspace, "leetcode")
	if intent.provider == "kattis" { binary = find_executable(ctx.workspace, "kattis.bin") }
	if binary == "" { return error_result(.Unsupported_Capability, "the compatible provider binary is unavailable") }
	snapshot_abs := join({ctx.workspace, intent.snapshot_path})
	command := make([dynamic]string)
	defer delete(command)
	if intent.provider == "leetcode" {
		append(&command, binary, "submit-start", intent.slug, snapshot_abs, "--lang", intent.language, "--json", "--timeout", "15")
	} else {
		append(&command, binary, "submit-start", intent.provider_id, snapshot_abs)
		if intent.language != "odin" { append(&command, intent.language) }
		append(&command, "--json")
	}
	obs := run_bounded(command[:], "", 30, MAX_CAPTURE_BYTES, true)
	if obs.start_failed { return error_result(.Unsupported_Capability, "could not launch the provider adapter") }
	if obs.timed_out || obs.output_exceeded {
		return record_unknown_submission(ctx, store, req, &intent, "provider process ended without a durable job id")
	}
	response, parse_err := json.parse(strings.trim_space(obs.stdout), .JSON, parse_integers = true)
	remote_id := jstr(jget(response, "job_id"))
	if parse_err != nil || remote_id == "" {
		if strings.contains(strings.to_lower(obs.stderr), "sign") || strings.contains(strings.to_lower(obs.stderr), "credential") {
			return error_result(.Auth_Required, "provider authentication is required; use the provider's existing login flow")
		}
		return record_unknown_submission(ctx, store, req, &intent, "provider response did not contain a valid job id")
	}
	job_id := fmt_id("job", store.revision + 1)
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "job_id", job_id)
	obj_field_str(&p, "intent_id", intent.id)
	obj_field_str(&p, "authorization_reference", authorization)
	obj_field_str(&p, "provider", intent.provider)
	obj_field_str(&p, "remote_id", remote_id)
	obj_field_str(&p, "problem_key", intent.problem_key)
	obj_field_str(&p, "language", intent.language)
	obj_field_str(&p, "source_hash", intent.source_hash)
	_, res := commit_and_project(store, ctx, req, "submission_sent", intent.session_id, intent.attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	job_doc := obj_new()
	defer obj_free(&job_doc)
	obj_field_int(&job_doc, "schema_version", SCHEMA_VERSION)
	obj_field_str(&job_doc, "job_id", job_id)
	obj_field_str(&job_doc, "intent_id", intent.id)
	obj_field_str(&job_doc, "provider", intent.provider)
	obj_field_str(&job_doc, "remote_id", remote_id)
	obj_field_str(&job_doc, "problem_key", intent.problem_key)
	obj_field_str(&job_doc, "language", intent.language)
	obj_field_str(&job_doc, "source_hash", intent.source_hash)
	obj_field_str(&job_doc, "state", "queued")
	if write_private_file(join({ctx.workspace, LEARNING_DIR, "jobs", fmt.aprintf("%s.json", job_id)}), obj_done(&job_doc)) != nil {
		append(&res.warnings, "job event was committed but its convenience projection could not be written")
	}
	obj_field_str(&res.data, "job_id", job_id)
	obj_field_str(&res.data, "remote_id", remote_id)
	obj_field_str(&res.data, "state", "queued")
	res.status = .Pending
	append(&res.next_actions, "resume this exact job with job_check; do not submit the source again")
	return res
}

op_job_check :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"job_id"}, {"wait_seconds"}); fail.status == .Error { return fail }
	job_id := jstr(jget(input, "job_id"))
	wait_seconds := jint(jget(input, "wait_seconds"))
	if wait_seconds == 0 { wait_seconds = 5 }
	if wait_seconds < 1 || wait_seconds > 30 { return bad_input("wait_seconds must be between 1 and 30") }
	job := find_job(store, job_id)
	if !job.found { return error_result(.Not_Found, "remote job does not exist") }
	if job.state == "terminal" { return error_result(.Request_Conflict, "job already has a terminal observation") }
	intent := find_intent(store, job.intent_id)
	binary := find_executable(ctx.workspace, "leetcode")
	if job.provider == "kattis" { binary = find_executable(ctx.workspace, "kattis.bin") }
	if binary == "" { return error_result(.Unsupported_Capability, "the compatible provider binary is unavailable") }
	command := make([dynamic]string)
	defer delete(command)
	if job.provider == "leetcode" {
		append(&command, binary, "check", job.remote_id, "--json", "--timeout", fmt.aprintf("%d", wait_seconds))
	} else {
		append(&command, binary, "check", job.remote_id, "--json")
	}
	obs := run_bounded(command[:], "", wait_seconds + 5, MAX_CAPTURE_BYTES, true)
	if obs.start_failed { return error_result(.Unsupported_Capability, "could not launch the provider adapter") }
	provider_result, parse_err := json.parse(strings.trim_space(obs.stdout), .JSON, parse_integers = true)
	state := "pending"
	verdict := ""
	if parse_err == nil {
		if job.provider == "kattis" {
			state = jstr(jget(provider_result, "state"))
			verdict = jstr(jget(provider_result, "verdict"))
		} else {
			provider_state := jstr(jget(provider_result, "state"))
			if provider_state == "SUCCESS" { state = "terminal"; verdict = jstr(jget(provider_result, "status_msg")) }
		}
	}
	if obs.timed_out || strings.contains(strings.to_lower(obs.stderr), "pending") { state = "pending" }
	p := obj_new()
	defer obj_free(&p)
	obj_field_str(&p, "job_id", job.id)
	obj_field_str(&p, "intent_id", job.intent_id)
	obj_field_str(&p, "provider", job.provider)
	obj_field_str(&p, "remote_id", job.remote_id)
	obj_field_str(&p, "state", state)
	obj_field_str(&p, "verdict", verdict)
	obj_field_str(&p, "source_hash", job.source_hash)
	obj_field_str(&p, "provider_result", strings.trim_space(obs.stdout))
	_, res := commit_and_project(store, ctx, req, "job_observed", intent.session_id, intent.attempt_id, obj_done(&p))
	if res.status == .Error { return res }
	obj_field_str(&res.data, "job_id", job.id)
	obj_field_str(&res.data, "state", state)
	obj_field_str(&res.data, "verdict", verdict)
	obj_field_str(&res.data, "source_hash", job.source_hash)
	if state != "terminal" {
		res.status = .Pending
		append(&res.next_actions, "check this same job later; no new submission was created")
	}
	return res
}
