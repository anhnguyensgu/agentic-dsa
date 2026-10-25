package learn

// Bounded local Odin execution with source-bound artifacts (sections 12 and
// 15, acceptance A11/A14/A17), through the judge package's stdin/stdout
// runner, or its test package runner for odin_test_package attempts. Commands
// are argument vectors; learner input is stdin data and never part of a
// command line.

import "../judge"
import "../safeio"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

DEFAULT_TIMEOUT_SECONDS :: 10
MAX_TIMEOUT_SECONDS :: 60

// Building a test package comes on top of the run's own timeout.
PACKAGE_BUILD_ALLOWANCE :: 30 * time.Second

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
		append(
			&cases,
			Case_Record {
				p.case_id,
				p.name,
				p.input,
				p.expected,
				comparator,
				p.provenance,
				p.oracle_verified,
			},
		)
	}
	return cases[:]
}

// The judge runner's comparison for each case_add comparator name.
COMPARE := [Comparator]judge.Compare_Proc {
	.Exact   = judge.compare_exact,
	.Trimmed = judge.compare_trimmed,
	.Tokens  = judge.compare_tokens,
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

op_test_run :: proc(
	ctx: ^Context,
	store: ^Store,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
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
	case attempt.runner_kind == "odin_test_package":
		return run_package_tests(ctx, store, req, attempt, timeout)
	case attempt.runner_kind != "stdin_stdout":
		return {}, fail(.Unsupported_Capability, "this attempt requires its provider workspace runner; use the provider tool until it is registered as stdin_stdout or odin_test_package")
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
		append(
			&res.warnings,
			"no cases are registered; zero cases cannot establish passing behavior",
		)
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
	build := judge.build_odin(source_abs, binary, "-o:none", timeout)
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
		res.data = to_json(
			Compile_Error {
				"compile_error",
				source_hash,
				build.timed_out,
				build.output_exceeded,
				build.stderr,
			},
		)
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
	report := Report {
		schema_version = SCHEMA_VERSION,
		artifact_id    = fmt.aprintf(
			"artifact_%s",
			hash_hex(fmt.tprintf("%s:%s:%s", p.attempt_id, source_hash, req.request_id))[:16],
		),
		attempt_id     = p.attempt_id,
		source_hash    = source_hash,
		cases          = make([]Case_Result, len(cases)),
	}
	tally: judge.Tally
	for c, i in cases {
		expected, has_expected := c.expected.?
		verified := has_expected && c.oracle_verified
		run, passed := judge.run_case(binary, c.input, expected, COMPARE[c.comparator], timeout)
		passed &&= verified
		judge.tally_case(&tally, verified, passed)
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
	report.outcome = judge.outcome(tally)
	report.verified_passed, report.verified_failed, report.unchecked =
		tally.verified_passed, tally.verified_failed, tally.unchecked

	// Persist the report and the exact tested source before recording the run.
	if write_private_file(
		   learning_path(ctx.workspace, "artifacts", report.artifact_id, "report.json"),
		   string(to_json(report)),
	   ) !=
	   nil {
		return {}, fail(.Storage_Error, "could not persist the run artifact")
	}
	snapshot := learning_path(
		ctx.workspace,
		"attempts",
		p.attempt_id,
		"snapshots",
		strings.concatenate({source_hash, ".odin"}),
	)
	if write_private_file(snapshot, string(source)) != nil {
		return {}, fail(.Storage_Error, "could not persist the exact tested source snapshot")
	}
	payload := Runner_Observed {
		report.artifact_id,
		source_hash,
		report.outcome,
		report.verified_passed,
		report.verified_failed,
		report.unchecked,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Runner_Observed,
		payload,
		attempt.session_id,
		p.attempt_id,
	) or_return

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
	res.data = to_json(
		Data {
			replayed_flag(replayed),
			report.artifact_id,
			report.outcome,
			source_hash,
			report.verified_passed,
			report.verified_failed,
			report.unchecked,
			report.cases,
		},
	)
	switch report.outcome {
	case "failed":
		res.cli_exit = EXIT_FAILED_SOLUTION
	case "unverified":
		res.cli_exit = EXIT_UNVERIFIED
		append(&res.warnings, "unchecked cases remain separate from verified passing evidence")
	}
	return
}

// run_package_tests runs an odin_test_package attempt: `odin test` on the
// package holding the attempt source, one case per @(test) procedure. Its
// tests are verified only while they match the files the attempt began with.
@(private = "file")
run_package_tests :: proc(
	ctx: ^Context,
	store: ^Store,
	req: Request,
	attempt: ^Attempt_State,
	timeout: time.Duration,
) -> (
	res: Result,
	err: Op_Error,
) {
	source_abs := join(ctx.workspace, attempt.source_path)
	source, read_err := os.read_entire_file(source_abs, context.allocator)
	if read_err != nil {
		return {}, fail(.Not_Found, "the attempt source file is missing")
	}
	source_hash := hash_hex(string(source))
	dir := os.dir(source_abs)
	tests_modified := attempt.tests_hash != "" && package_tests_hash(dir) != attempt.tests_hash
	provenance := "package_tests"
	if problem, key_err := parse_problem_key(attempt.problem_key); key_err == nil {
		if traits, _ := provider_traits(problem.provider); traits.test_provenance != "" {
			provenance = traits.test_provenance
		}
	}

	build_dir, dir_err := os.make_directory_temp("", "algolearn-tests-*", context.allocator)
	if dir_err != nil {
		return {}, fail(.Storage_Error, "could not create the bounded build directory")
	}
	defer os.remove_all(build_dir)
	process, tests, reported := judge.run_test_package(
		dir,
		build_dir,
		timeout + PACKAGE_BUILD_ALLOWANCE,
	)
	if process.start_failed {
		return {}, fail(.Unsupported_Capability, "could not start the Odin compiler")
	}
	if !reported {
		// Without a report the package did not build, or the run never finished.
		Compile_Error :: struct {
			outcome:               string,
			source_hash:           string,
			timed_out:             bool,
			output_limit_exceeded: bool,
			diagnostic:            string,
		}
		res.data = to_json(
			Compile_Error {
				"failed" if process.timed_out else "compile_error",
				source_hash,
				process.timed_out,
				process.output_exceeded,
				process.stderr,
			},
		)
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
		tests_modified:  bool,
		cases:           []Case_Result,
	}
	report := Report {
		schema_version = SCHEMA_VERSION,
		artifact_id    = fmt.aprintf(
			"artifact_%s",
			hash_hex(fmt.tprintf("%s:%s:%s", attempt.id, source_hash, req.request_id))[:16],
		),
		attempt_id     = attempt.id,
		source_hash    = source_hash,
		tests_modified = tests_modified,
		cases          = make([]Case_Result, len(tests)),
	}
	tally: judge.Tally
	for test, i in tests {
		verified := !tests_modified
		passed := verified && test.success
		judge.tally_case(&tally, verified, passed)
		report.cases[i] = {
			case_id               = test.name,
			name                  = test.name,
			verified              = verified,
			passed                = passed,
			comparator            = "odin_test",
			provenance            = provenance,
			exit_code             = process.exit_code,
			timed_out             = process.timed_out,
			output_limit_exceeded = process.output_exceeded,
		}
	}
	report.outcome = judge.outcome(tally)
	report.verified_passed, report.verified_failed, report.unchecked =
		tally.verified_passed, tally.verified_failed, tally.unchecked

	// Persist the report and the exact tested source before recording the run.
	if write_private_file(
		   learning_path(ctx.workspace, "artifacts", report.artifact_id, "report.json"),
		   string(to_json(report)),
	   ) !=
	   nil {
		return {}, fail(.Storage_Error, "could not persist the run artifact")
	}
	snapshot := learning_path(
		ctx.workspace,
		"attempts",
		attempt.id,
		"snapshots",
		strings.concatenate({source_hash, ".odin"}),
	)
	if write_private_file(snapshot, string(source)) != nil {
		return {}, fail(.Storage_Error, "could not persist the exact tested source snapshot")
	}
	payload := Runner_Observed {
		report.artifact_id,
		source_hash,
		report.outcome,
		report.verified_passed,
		report.verified_failed,
		report.unchecked,
	}
	_, replayed := commit(
		ctx,
		store,
		req,
		.Runner_Observed,
		payload,
		attempt.session_id,
		attempt.id,
	) or_return

	Data :: struct {
		replayed:        Replayed `json:",omitempty"`,
		artifact_id:     string,
		outcome:         string,
		source_hash:     string,
		verified_passed: int,
		verified_failed: int,
		unchecked:       int,
		tests_modified:  bool,
		cases:           []Case_Result,
	}
	res = mutation_result(replayed)
	res.data = to_json(
		Data {
			replayed_flag(replayed),
			report.artifact_id,
			report.outcome,
			source_hash,
			report.verified_passed,
			report.verified_failed,
			report.unchecked,
			tests_modified,
			report.cases,
		},
	)
	if tests_modified {
		append(
			&res.warnings,
			"the package's *_test.odin files changed after the attempt began; restore them for this run to count as evidence",
		)
	}
	switch report.outcome {
	case "failed":
		res.cli_exit = EXIT_FAILED_SOLUTION
	case "unverified":
		res.cli_exit = EXIT_UNVERIFIED
	}
	return
}

// package_tests_hash fingerprints the *_test.odin files of the Odin package
// in dir; "" when there are none.
package_tests_hash :: proc(dir: string) -> string {
	entries, list_err := os.read_all_directory_by_path(dir, context.allocator)
	if list_err != nil {
		return ""
	}
	names := make([dynamic]string)
	for entry in entries {
		if strings.has_suffix(entry.name, "_test.odin") {
			append(&names, entry.name)
		}
	}
	if len(names) == 0 {
		return ""
	}
	slice.sort(names[:])
	b := strings.builder_make()
	for name in names {
		data, _ := os.read_entire_file(join(dir, name), context.allocator)
		fmt.sbprintf(&b, "%s\x00%d\x00", name, len(data))
		strings.write_bytes(&b, data)
	}
	return hash_hex(strings.to_string(b))
}
