package learning

// Bounded local Odin execution with source-bound artifacts (sections 12 and
// 15, acceptance A11/A14/A17). Commands are argument vectors; learner input is
// stdin data and never part of a command line.

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "../../safeio"

DEFAULT_TIMEOUT_SECONDS :: 10
MAX_TIMEOUT_SECONDS :: 60

Case_Record :: struct {
	id:              string,
	name:            string,
	input:           string,
	expected:        Maybe(string),
	comparator:      Comparator,
	provenance:      string,
	oracle_verified: bool,
}

attempt_cases :: proc(store: ^Store, attempt_id: string) -> []Case_Record {
	cases := make([dynamic]Case_Record)
	for ev in store.events {
		if ev.type != EVENT_TYPE_NAMES[.Case_Added] || ev.attempt_id != attempt_id {
			continue
		}
		p: Case_Added
		decode(string(ev.payload), &p)
		comparator, _ := parse_enum(COMPARATOR_NAMES, p.comparator)
		append(&cases, Case_Record{p.case_id, p.name, p.input, p.expected, comparator, p.provenance, p.oracle_verified})
	}
	return cases[:]
}

compare_output :: proc(actual, expected: string, comparator: Comparator) -> bool {
	switch comparator {
	case .Exact:
		return actual == expected
	case .Trimmed:
		return strings.trim_space(actual) == strings.trim_space(expected)
	case .Tokens:
		a, b := strings.fields(actual), strings.fields(expected)
		if len(a) != len(b) {
			return false
		}
		for token, i in a {
			if token != b[i] {
				return false
			}
		}
		return true
	}
	return false
}

Test_Run_Params :: struct {
	attempt_id:       string,
	mode:             string, // only "local" is available
	timeout_seconds:  int,
	source_selection: string,
}

Case_Result :: struct {
	case_id:               string,
	name:                  string,
	verified:              bool,
	passed:                bool,
	comparator:            string,
	provenance:            string,
	exit_code:             int,
	timed_out:             bool,
	output_limit_exceeded: bool,
	actual:                string,
	stderr:                string,
}

op_test_run :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Test_Run_Params) or_return
	if first_nonempty(p.mode, "local") != "local" {
		return {}, fail(.Unsupported_Capability, "remote example execution is available only through a configured provider adapter")
	}
	timeout_seconds := first_nonzero(p.timeout_seconds, DEFAULT_TIMEOUT_SECONDS)
	if timeout_seconds < 1 || timeout_seconds > MAX_TIMEOUT_SECONDS {
		return {}, invalid("timeout_seconds must be between 1 and 60")
	}
	timeout := time.Duration(timeout_seconds) * time.Second

	st := fold(store)
	attempt := find_attempt(&st, p.attempt_id)
	switch {
	case attempt == nil:
		return {}, fail(.Not_Found, "attempt does not exist")
	case attempt.language != "odin":
		return {}, fail(.Unsupported_Capability, "the guaranteed local runner supports Odin attempts")
	case attempt.runner_kind != "stdin_stdout":
		return {}, fail(.Unsupported_Capability, "this attempt requires its provider workspace runner; use the provider tool until it is registered as stdin_stdout")
	}
	source_abs := join(ctx.workspace, attempt.source_path)
	source, read_err := os.read_entire_file(source_abs, context.allocator)
	if read_err != nil {
		return {}, fail(.Not_Found, "the attempt source file is missing")
	}
	source_hash := hash_hex(string(source))

	// Zero cases can never establish passing behavior.
	cases := attempt_cases(store, p.attempt_id)
	if len(cases) == 0 {
		Empty :: struct {
			outcome:         string,
			verified_passed: int,
			verified_failed: int,
			unchecked:       int,
			source_hash:     string,
		}
		res.data = to_json(Empty{outcome = "unverified", source_hash = source_hash})
		append(&res.warnings, "no cases are registered; zero cases cannot establish passing behavior")
		append(&res.next_actions, "add an official or independently verified case with case_add")
		res.cli_exit = EXIT_UNVERIFIED
		return
	}

	build_dir, dir_err := os.make_directory_temp("", "algolearn-build-*", context.allocator)
	if dir_err != nil {
		return {}, fail(.Storage_Error, "could not create the bounded build directory")
	}
	defer os.remove_all(build_dir)
	binary := join(build_dir, "solution")
	build := safeio.run({"odin", "build", source_abs, "-file", "-o:none", strings.concatenate({"-out:", binary})}, timeout = timeout)
	if build.start_failed {
		return {}, fail(.Unsupported_Capability, "could not start the Odin compiler")
	}
	if !safeio.ok(build) {
		Compile_Error :: struct {
			outcome:               string,
			source_hash:           string,
			timed_out:             bool,
			output_limit_exceeded: bool,
			diagnostic:            string,
		}
		res.data = to_json(Compile_Error{"compile_error", source_hash, build.timed_out, build.output_exceeded, build.stderr})
		res.cli_exit = EXIT_FAILED_SOLUTION
		return
	}

	Report :: struct {
		schema_version:  int,
		artifact_id:     string,
		attempt_id:      string,
		source_hash:     string,
		outcome:         string, // passed | failed | unverified
		verified_passed: int,
		verified_failed: int,
		unchecked:       int,
		cases:           []Case_Result,
	}
	report := Report{
		schema_version = SCHEMA_VERSION,
		artifact_id    = fmt.aprintf("artifact_%s", hash_hex(fmt.tprintf("%s:%s:%s", p.attempt_id, source_hash, req.request_id))[:16]),
		attempt_id     = p.attempt_id,
		source_hash    = source_hash,
		cases          = make([]Case_Result, len(cases)),
	}
	for c, i in cases {
		run := safeio.run({binary}, stdin = c.input, timeout = timeout)
		expected, has_expected := c.expected.?
		verified := has_expected && c.oracle_verified
		passed := verified && safeio.ok(run) && compare_output(run.stdout, expected, c.comparator)
		switch {
		case !verified: report.unchecked += 1
		case passed:    report.verified_passed += 1
		case:           report.verified_failed += 1
		}
		report.cases[i] = {
			case_id               = c.id,
			name                  = c.name,
			verified              = verified,
			passed                = passed,
			comparator            = COMPARATOR_NAMES[c.comparator],
			provenance            = c.provenance,
			exit_code             = run.exit_code,
			timed_out             = run.timed_out,
			output_limit_exceeded = run.output_exceeded,
			actual                = run.stdout,
			stderr                = run.stderr,
		}
	}
	switch {
	case report.verified_failed > 0:
		report.outcome = "failed"
	case report.unchecked > 0 || report.verified_passed == 0:
		report.outcome = "unverified"
	case:
		report.outcome = "passed"
	}

	// Persist the report and the exact tested source before recording the run.
	if write_private_file(learning_path(ctx.workspace, "artifacts", report.artifact_id, "report.json"), string(to_json(report))) != nil {
		return {}, fail(.Storage_Error, "could not persist the run artifact")
	}
	snapshot := learning_path(ctx.workspace, "attempts", p.attempt_id, "snapshots", strings.concatenate({source_hash, ".odin"}))
	if write_private_file(snapshot, string(source)) != nil {
		return {}, fail(.Storage_Error, "could not persist the exact tested source snapshot")
	}
	payload := Runner_Observed{report.artifact_id, source_hash, report.outcome, report.verified_passed, report.verified_failed, report.unchecked}
	_, replayed := commit(ctx, store, req, .Runner_Observed, payload, attempt.session_id, p.attempt_id) or_return

	Data :: struct {
		replayed:        Replayed `json:",omitempty"`,
		artifact_id:     string,
		outcome:         string,
		source_hash:     string,
		verified_passed: int,
		verified_failed: int,
		unchecked:       int,
		cases:           []Case_Result,
	}
	res = mutation_result(replayed)
	res.data = to_json(Data{
		replayed_flag(replayed),
		report.artifact_id,
		report.outcome,
		source_hash,
		report.verified_passed,
		report.verified_failed,
		report.unchecked,
		report.cases,
	})
	switch report.outcome {
	case "failed":
		res.cli_exit = EXIT_FAILED_SOLUTION
	case "unverified":
		res.cli_exit = EXIT_UNVERIFIED
		append(&res.warnings, "unchecked cases remain separate from verified passing evidence")
	}
	return
}
