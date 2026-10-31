package learn

// Remote submissions and verdict polling. Nothing is stored here: submit
// sends once and returns the judge's remote id in a submission_sent event,
// and the caller keeps that id to poll with job_check. Guarding against a
// duplicate submission after a lost id is the caller's job; an ambiguous send
// is reported as submission_outcome_unknown and never retried here.

import "../safeio"
import "core:fmt"
import "core:strings"
import "core:time"

PROVIDER_SEND_TIMEOUT :: 30 * time.Second

// -- submit --------------------------------------------------------------------

Submit_Params :: struct {
	problem_key:             string,
	language:                string, // the provider's language name; odin for Odin
	source_path:             string, // workspace-relative
	source_hash:             string, // optional: refuse if the file changed since it was tested
	authorization_reference: string, // the learner's request this send acts on
	account_alias:           string,
	session_id:              string, // the caller's ids, copied into the event
	attempt_id:              string,
}

op_submit :: proc(ctx: ^Context, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Submit_Params) or_return
	nonempty(
		{"problem_key", p.problem_key},
		{"language", p.language},
		{"authorization_reference", p.authorization_reference},
	) or_return
	problem := parse_problem_key(p.problem_key) or_return
	traits, _ := provider_traits(problem.provider)
	if !traits.remote_odin && p.language == "odin" {
		return {}, fail(.Unsupported_Capability, fmt.aprintf("%s does not judge Odin; keep this attempt local and submit a separate supported-language attempt", traits.title))
	}
	if !safe_relative_path(p.source_path) {
		return {}, invalid("source_path must be a safe workspace-relative path")
	}
	source_abs := join(ctx.workspace, p.source_path)
	if !path_is_within_workspace(ctx.workspace, source_abs) {
		return {}, invalid("source_path resolves outside the workspace through a symlink")
	}
	source_hash, hash_err := read_source_hash(source_abs)
	if hash_err != nil {
		return {}, fail(.Not_Found, "the source file is missing")
	}
	if p.source_hash != "" && p.source_hash != source_hash {
		return {}, fail(.Stale_Source, "the source changed since the hash you passed; test it again or pass its current hash")
	}

	command := provider_command(problem.provider) or_return
	switch traits.submit {
	case .Start_Job_With_Language:
		append(
			&command,
			"submit-start",
			problem.slug,
			source_abs,
			"--lang",
			p.language,
			"--json",
			"--timeout",
			"15",
		)
	case .Start_Job:
		// The judge infers its language name from the extension for Odin.
		append(&command, "submit-start", problem.slug, source_abs, "--json")
		if p.language != "odin" {
			append(&command, "--lang", p.language)
		}
	case .Upload:
		append(&command, "submit", source_abs)
	}
	run := safeio.run(command[:], timeout = PROVIDER_SEND_TIMEOUT, keep_credentials = true)
	if run.start_failed {
		return {}, fail(.Unsupported_Capability, "could not launch the provider adapter")
	}
	unknown := Submission_Outcome_Unknown {
		provider    = problem.provider,
		problem_key = p.problem_key,
		language    = p.language,
		source_hash = source_hash,
	}
	if run.timed_out || run.output_exceeded {
		unknown.reason = "provider process ended without a remote id"
		return res, unknown_outcome(ctx, &res, unknown, p)
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
			unknown.reason = "provider response did not contain a valid remote id"
			return res, unknown_outcome(ctx, &res, unknown, p)
		}
	}
	// An upload has no remote verdict, so it is finished once sent.
	state := "uploaded" if traits.submit == .Upload else "queued"

	sent := Submission_Sent {
		provider                = problem.provider,
		problem_key             = p.problem_key,
		language                = p.language,
		source_path             = p.source_path,
		source_hash             = source_hash,
		remote_id               = remote_id,
		state                   = state,
		authorization_reference = p.authorization_reference,
		account_alias           = p.account_alias,
	}
	emit(ctx, &res, .Submission_Sent, sent, p.session_id, p.attempt_id)

	Data :: struct {
		provider:    string,
		remote_id:   string,
		state:       string,
		source_hash: string,
	}
	res.data = to_json(Data{problem.provider, remote_id, state, source_hash})
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
		"keep provider and remote_id, then poll with job_check; do not submit the source again",
	)
	return
}

// unknown_outcome reports that a send may have reached the provider without
// a remote id, with the event the caller must keep to block a blind resend.
@(private = "file")
unknown_outcome :: proc(
	ctx: ^Context,
	res: ^Result,
	unknown: Submission_Outcome_Unknown,
	p: Submit_Params,
) -> Op_Error {
	emit(ctx, res, .Submission_Outcome_Unknown, unknown, p.session_id, p.attempt_id)
	return Failure {
		code = .Submission_Outcome_Unknown,
		message = "the request may have reached the provider but no remote id was captured; do not resend automatically",
		next_action = "reconcile through the provider's submission history, or ask the learner, before any new submit",
	}
}

// -- job_check -----------------------------------------------------------------

DEFAULT_WAIT_SECONDS :: 5
MAX_WAIT_SECONDS :: 30

Job_Check_Params :: struct {
	provider:     string,
	remote_id:    string, // from submit
	wait_seconds: int,
	source_hash:  string, // copied into the event, to tie the verdict to the tested source
	session_id:   string,
	attempt_id:   string,
}

op_job_check :: proc(ctx: ^Context, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Job_Check_Params) or_return
	wait_seconds := first_nonzero(p.wait_seconds, DEFAULT_WAIT_SECONDS)
	if wait_seconds < 1 || wait_seconds > MAX_WAIT_SECONDS {
		return {}, invalid("wait_seconds must be between 1 and 30")
	}
	traits, known := provider_traits(p.provider)
	if !known {
		return {}, invalid(fmt.aprintf("provider must be one of: %s", strings.join(provider_names(), ", ")))
	}
	if traits.check == .None {
		return {}, fail(.Unsupported_Capability, fmt.aprintf("%s reports no verdict to check; its results appear only on its website", traits.title))
	}
	// The id becomes an argument of the provider command, never an option.
	if p.remote_id == "" || strings.has_prefix(p.remote_id, "-") {
		return {}, invalid("remote_id must be the id submit returned")
	}
	command := provider_command(p.provider) or_return
	append(&command, "check", p.remote_id, "--json", "--timeout", fmt.tprint(wait_seconds))
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

	observed := Job_Observed {
		provider        = p.provider,
		remote_id       = p.remote_id,
		state           = state,
		verdict         = verdict,
		source_hash     = p.source_hash,
		provider_result = provider_output,
	}
	emit(ctx, &res, .Job_Observed, observed, p.session_id, p.attempt_id)

	Data :: struct {
		provider:  string,
		remote_id: string,
		state:     string,
		verdict:   string,
	}
	res.data = to_json(Data{p.provider, p.remote_id, state, verdict})
	if state != "terminal" {
		res.status = .Pending
		append(&res.next_actions, "check this same remote_id later; no new submission was created")
	}
	return
}
