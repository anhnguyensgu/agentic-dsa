package learn

// Immutable submission intents and recoverable remote jobs (section 13).
// Preparation is local. Sending happens once, only with an authorization
// reference supplied by the host after the learner asked for it.

import "../safeio"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

PROVIDER_SEND_TIMEOUT :: 30 * time.Second

Submission_Intent :: struct {
	using prepared:  Submission_Prepared,
	attempt_id:      string,
	session_id:      string,
	sent:            bool,
	outcome_unknown: bool,
}

Remote_Job :: struct {
	using sent: Submission_Sent,
	state:      string, // queued | pending | terminal
}

find_intent :: proc(store: ^Store, intent_id: string) -> (intent: Submission_Intent, found: bool) {
	for ev in store.events {
		kind, _ := parse_enum(EVENT_TYPE_NAMES, ev.type)
		#partial switch kind {
		case .Submission_Prepared:
			p: Submission_Prepared
			if decode(string(ev.payload), &p) && p.intent_id == intent_id {
				intent = {
					prepared   = p,
					attempt_id = ev.attempt_id,
					session_id = ev.session_id,
				}
				found = true
			}
		case .Submission_Sent, .Submission_Outcome_Unknown:
			ref: struct {
				intent_id: string,
			}
			if decode(string(ev.payload), &ref) && ref.intent_id == intent_id {
				intent.sent ||= kind == .Submission_Sent
				intent.outcome_unknown ||= kind == .Submission_Outcome_Unknown
			}
		}
	}
	return
}

find_job :: proc(store: ^Store, job_id: string) -> (job: Remote_Job, found: bool) {
	for ev in store.events {
		kind, _ := parse_enum(EVENT_TYPE_NAMES, ev.type)
		#partial switch kind {
		case .Submission_Sent:
			p: Submission_Sent
			if decode(string(ev.payload), &p) && p.job_id == job_id {
				job = {
					sent  = p,
					state = "queued",
				}
				// A provider without verdicts is done once the upload succeeds.
				if traits, known := provider_traits(p.provider); known && traits.check == .None {
					job.state = "terminal"
				}
				found = true
			}
		case .Job_Observed:
			p: Job_Observed
			if decode(string(ev.payload), &p) && p.job_id == job_id {
				job.state = p.state
			}
		}
	}
	return
}

// -- submission_prepare --------------------------------------------------------

Submission_Prepare_Params :: struct {
	attempt_id:    string,
	account_alias: string,
}

op_submission_prepare :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Submission_Prepare_Params) or_return
	st := fold(store)
	attempt := find_attempt(&st, p.attempt_id)
	if attempt == nil {
		return {}, fail(.Not_Found, "attempt does not exist")
	}
	problem := parse_problem_key(attempt.problem_key) or_return
	traits, _ := provider_traits(problem.provider)
	if !traits.remote_odin && attempt.language == "odin" {
		return {}, fail(.Unsupported_Capability, fmt.aprintf("%s does not judge Odin; preserve this attempt and create a separately tracked supported-language attempt for remote submission", traits.title))
	}
	source, read_err := os.read_entire_file(
		join(ctx.workspace, attempt.source_path),
		context.allocator,
	)
	if read_err != nil {
		return {}, fail(.Not_Found, "attempt source is missing")
	}

	// The exact bytes to send are frozen now; sending checks they still match.
	intent_id := fmt_id("intent", store.revision + 1)
	snapshot_path := join(
		LEARNING_DIR,
		"attempts",
		p.attempt_id,
		"submissions",
		strings.concatenate({intent_id, first_nonempty(os.ext(attempt.source_path), ".txt")}),
	)
	if write_private_file(join(ctx.workspace, snapshot_path), string(source)) != nil {
		return {}, fail(.Storage_Error, "could not persist the immutable submission snapshot")
	}
	payload := Submission_Prepared {
		intent_id     = intent_id,
		provider      = problem.provider,
		problem_key   = attempt.problem_key,
		provider_id   = problem.slug,
		slug          = problem.slug,
		language      = attempt.language,
		source_path   = attempt.source_path,
		source_hash   = hash_hex(string(source)),
		snapshot_path = snapshot_path,
		account_alias = p.account_alias,
	}
	ev, replayed := commit(
		ctx,
		store,
		req,
		.Submission_Prepared,
		payload,
		attempt.session_id,
		p.attempt_id,
	) or_return
	if replayed {
		decode(string(ev.payload), &payload)
	}

	Data :: struct {
		replayed:      Replayed `json:",omitempty"`,
		intent_id:     string,
		provider:      string,
		problem_key:   string,
		language:      string,
		source_hash:   string,
		snapshot_path: string,
	}
	res = mutation_result(replayed)
	res.data = to_json(
		Data {
			replayed_flag(replayed),
			payload.intent_id,
			payload.provider,
			payload.problem_key,
			payload.language,
			payload.source_hash,
			payload.snapshot_path,
		},
	)
	append(
		&res.next_actions,
		"send this exact intent only after the learner has authorized the described provider, problem, language, account, and source",
	)
	return
}

// -- submission_send -----------------------------------------------------------

Submission_Send_Params :: struct {
	intent_id:               string,
	authorization_reference: string,
}

op_submission_send :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Submission_Send_Params) or_return
	if p.intent_id == "" || p.authorization_reference == "" {
		return {}, invalid("intent_id and authorization_reference must be non-empty strings")
	}
	intent, found := find_intent(store, p.intent_id)
	switch {
	case !found:
		return {}, fail(.Not_Found, "submission intent does not exist")
	case intent.sent:
		return {}, fail(.Request_Conflict, "this intent was already sent; use job_check instead of submitting again")
	case intent.outcome_unknown:
		return {}, fail(.Submission_Outcome_Unknown, "this intent has an unknown send outcome and must be reconciled before any new submission")
	}
	if current_hash, hash_err := read_source_hash(join(ctx.workspace, intent.source_path));
	   hash_err != nil || current_hash != intent.source_hash {
		return {}, fail(.Stale_Source, "the working source changed after preparation; prepare a new immutable intent")
	}
	command := provider_command(intent.provider) or_return
	traits, _ := provider_traits(intent.provider)

	snapshot := join(ctx.workspace, intent.snapshot_path)
	switch traits.submit {
	case .Start_Job_With_Language:
		append(
			&command,
			"submit-start",
			intent.slug,
			snapshot,
			"--lang",
			intent.language,
			"--json",
			"--timeout",
			"15",
		)
	case .Start_Job:
		// The judge infers its language name from the extension for Odin.
		append(&command, "submit-start", intent.provider_id, snapshot, "--json")
		if intent.language != "odin" {
			append(&command, "--lang", intent.language)
		}
	case .Upload:
		// An upload sends the exercise's own file, which still matches the
		// prepared hash (checked above).
		append(&command, "submit", join(ctx.workspace, intent.source_path))
	}
	run := safeio.run(command[:], timeout = PROVIDER_SEND_TIMEOUT, keep_credentials = true)
	if run.start_failed {
		return {}, fail(.Unsupported_Capability, "could not launch the provider adapter")
	}
	if run.timed_out || run.output_exceeded {
		return {}, record_unknown_submission(ctx, store, req, intent, "provider process ended without a durable job id")
	}
	diagnostic := strings.to_lower(run.stderr)
	remote_id := ""
	if traits.submit == .Upload {
		if run.exit_code != 0 {
			if strings.contains(diagnostic, "token") {
				return {}, fail(.Auth_Required, "provider authentication is required; use the provider's existing login flow")
			}
			reason := strings.trim_space(run.stderr)
			return {}, fail(.Unsupported_Capability, fmt.aprintf("%s did not accept the upload: %s", traits.title, reason[:min(len(reason), 400)]))
		}
	} else {
		response, _ := parse_json(run.stdout)
		remote_id = jstr(jget(response, "job_id"))
		if remote_id == "" {
			if strings.contains(diagnostic, "sign") || strings.contains(diagnostic, "credential") {
				return {}, fail(.Auth_Required, "provider authentication is required; use the provider's existing login flow")
			}
			return {}, record_unknown_submission(ctx, store, req, intent, "provider response did not contain a valid job id")
		}
	}
	// An upload has no remote verdict, so its job is finished once sent.
	state := "uploaded" if traits.submit == .Upload else "queued"

	payload := Submission_Sent {
		job_id                  = fmt_id("job", store.revision + 1),
		intent_id               = intent.intent_id,
		authorization_reference = p.authorization_reference,
		provider                = intent.provider,
		remote_id               = remote_id,
		problem_key             = intent.problem_key,
		language                = intent.language,
		source_hash             = intent.source_hash,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Submission_Sent,
		payload,
		intent.session_id,
		intent.attempt_id,
	) or_return

	res = mutation_result(replayed)
	Job_File :: struct {
		schema_version: int,
		job_id:         string,
		intent_id:      string,
		provider:       string,
		remote_id:      string,
		problem_key:    string,
		language:       string,
		source_hash:    string,
		state:          string,
	}
	job_file := Job_File {
		SCHEMA_VERSION,
		payload.job_id,
		payload.intent_id,
		payload.provider,
		remote_id,
		payload.problem_key,
		payload.language,
		payload.source_hash,
		state,
	}
	if write_private_file(
		   learning_path(ctx.workspace, "jobs", strings.concatenate({payload.job_id, ".json"})),
		   string(to_json(job_file)),
	   ) !=
	   nil {
		append(
			&res.warnings,
			"job event was committed but its convenience projection could not be written",
		)
	}

	Data :: struct {
		replayed:  Replayed `json:",omitempty"`,
		job_id:    string,
		remote_id: string,
		state:     string,
	}
	res.data = to_json(Data{replayed_flag(replayed), payload.job_id, remote_id, state})
	if traits.submit == .Upload {
		append(
			&res.next_actions,
			fmt.aprintf(
				"%s shows no verdict here; assess the learner from the local test evidence",
				traits.title,
			),
		)
		return
	}
	res.status = .Pending
	append(
		&res.next_actions,
		"resume this exact job with job_check; do not submit the source again",
	)
	return
}

// record_unknown_submission records that a send may have reached the provider
// without a durable id, which blocks automatic resending.
record_unknown_submission :: proc(
	ctx: ^Context,
	store: ^Store,
	req: Request,
	intent: Submission_Intent,
	reason: string,
) -> Op_Error {
	commit(
		ctx,
		store,
		req,
		.Submission_Outcome_Unknown,
		Submission_Outcome_Unknown{intent.intent_id, reason},
		intent.session_id,
		intent.attempt_id,
	) or_return
	return Failure {
		code = .Submission_Outcome_Unknown,
		message = "the request may have reached the provider but no durable remote id was captured; do not resend automatically",
		next_action = "reconcile through provider submission history, then attach the matching receipt or ask the learner before preparing a new send",
	}
}

// -- job_check -----------------------------------------------------------------

DEFAULT_WAIT_SECONDS :: 5
MAX_WAIT_SECONDS :: 30

Job_Check_Params :: struct {
	job_id:       string,
	wait_seconds: int,
}

op_job_check :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Job_Check_Params) or_return
	wait_seconds := first_nonzero(p.wait_seconds, DEFAULT_WAIT_SECONDS)
	if wait_seconds < 1 || wait_seconds > MAX_WAIT_SECONDS {
		return {}, invalid("wait_seconds must be between 1 and 30")
	}
	job, found := find_job(store, p.job_id)
	if !found {
		return {}, fail(.Not_Found, "remote job does not exist")
	}
	traits, known := provider_traits(job.provider)
	if known && traits.check == .None {
		return {}, fail(.Unsupported_Capability, fmt.aprintf("%s reports no verdict to check; its results appear only on its website", traits.title))
	}
	if job.state == "terminal" {
		return {}, fail(.Request_Conflict, "job already has a terminal observation")
	}
	intent, _ := find_intent(store, job.intent_id)
	command := provider_command(job.provider) or_return
	append(&command, "check", job.remote_id, "--json", "--timeout", fmt.tprint(wait_seconds))
	run := safeio.run(
		command[:],
		timeout = time.Duration(wait_seconds + 5) * time.Second,
		keep_credentials = true,
	)
	if run.start_failed {
		return {}, fail(.Unsupported_Capability, "could not launch the provider adapter")
	}

	provider_output := strings.trim_space(run.stdout)
	state, verdict := "pending", ""
	if result, ok := parse_json(provider_output); ok {
		switch traits.check {
		case .State_Verdict:
			state, verdict = jstr(jget(result, "state")), jstr(jget(result, "verdict"))
		case .Raw_Result:
			if jstr(jget(result, "state")) == "SUCCESS" {
				state, verdict = "terminal", jstr(jget(result, "status_msg"))
			}
		case .None:
		}
	}
	if run.timed_out || strings.contains(strings.to_lower(run.stderr), "pending") {
		state = "pending"
	}

	payload := Job_Observed {
		job.job_id,
		job.intent_id,
		job.provider,
		job.remote_id,
		state,
		verdict,
		job.source_hash,
		provider_output,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Job_Observed,
		payload,
		intent.session_id,
		intent.attempt_id,
	) or_return

	Data :: struct {
		replayed:    Replayed `json:",omitempty"`,
		job_id:      string,
		state:       string,
		verdict:     string,
		source_hash: string,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{replayed_flag(replayed), job.job_id, state, verdict, job.source_hash})
	if state != "terminal" {
		res.status = .Pending
		append(&res.next_actions, "check this same job later; no new submission was created")
	}
	return
}
