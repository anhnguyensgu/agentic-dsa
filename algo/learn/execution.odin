package learn

// Bounded local Odin execution through the judge package's stdin/stdout
// runner, or its test package runner for odin_test_package sources. Commands
// are argument vectors; learner input is stdin data and never part of a
// command line. Nothing is written outside a temporary build directory: the
// runner_observed event carries the whole report.

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

Comparator :: enum {
	Exact,
	Trimmed,
	Tokens,
}

COMPARATOR_NAMES := [Comparator]string {
	.Exact   = "exact",
	.Trimmed = "trimmed",
	.Tokens  = "tokens",
}

// The judge runner's comparison for each comparator name.
COMPARE := [Comparator]judge.Compare_Proc {
	.Exact   = judge.compare_exact,
	.Trimmed = judge.compare_trimmed,
	.Tokens  = judge.compare_tokens,
}

// Test_Case is one stdin/stdout case the caller supplies. Only a case with an
// expected output and a verified oracle can count as passing evidence.
Test_Case :: struct {
	name:            string,
	input:           string,
	expected:        Maybe(string), // null when the case has no oracle
	comparator:      string, // exact | trimmed | tokens
	provenance:      string, // where the expected output came from
	oracle_verified: bool,
}

Test_Run_Params :: struct {
	source_path:     string, // workspace-relative .odin source
	runner_kind:     string, // stdin_stdout (default) | odin_test_package
	cases:           []Test_Case, // stdin_stdout only
	tests_hash:      string, // odin_test_package: the tests_hash attempt_start returned
	problem_key:     string, // sets the provenance of a downloaded exercise's tests
	timeout_seconds: int,
	session_id:      string, // the caller's ids, copied into the event
	attempt_id:      string,
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

op_test_run :: proc(ctx: ^Context, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Test_Run_Params) or_return
	timeout_seconds := first_nonzero(p.timeout_seconds, DEFAULT_TIMEOUT_SECONDS)
	if timeout_seconds < 1 || timeout_seconds > MAX_TIMEOUT_SECONDS {
		return {}, invalid("timeout_seconds must be between 1 and 60")
	}
	timeout := time.Duration(timeout_seconds) * time.Second
	runner_kind := first_nonempty(p.runner_kind, "stdin_stdout")
	switch runner_kind {
	case "stdin_stdout", "odin_test_package":
	case:
		return {}, invalid("runner_kind must be stdin_stdout or odin_test_package; other languages run through the provider's own tools")
	}
	if !safe_relative_path(p.source_path) {
		return {}, invalid("source_path must be a safe workspace-relative path")
	}
	if os.ext(p.source_path) != ".odin" {
		return {}, fail(.Unsupported_Capability, "the local runner supports Odin sources")
	}
	source_abs := join(ctx.workspace, p.source_path)
	if !path_is_within_workspace(ctx.workspace, source_abs) {
		return {}, invalid("source_path resolves outside the workspace through a symlink")
	}
	source, read_err := os.read_entire_file(source_abs, context.allocator)
	if read_err != nil {
		return {}, fail(.Not_Found, "the source file is missing")
	}
	run := Runner_Observed {
		source_path = p.source_path,
		source_hash = hash_hex(string(source)),
		runner_kind = runner_kind,
	}

	if runner_kind == "odin_test_package" {
		if len(p.cases) > 0 {
			return {}, invalid("cases apply to stdin_stdout; odin_test_package runs the package's own tests")
		}
		run_package_tests(ctx, &res, &run, p, timeout) or_return
	} else {
		cases := check_cases(p.cases) or_return
		if len(cases) == 0 {
			// Zero cases can never establish passing behavior.
			run.outcome = "unverified"
			append(
				&res.warnings,
				"no cases were supplied; zero cases cannot establish passing behavior",
			)
			append(&res.next_actions, "pass an official or independently verified case in cases")
		} else {
			run_cases(&res, &run, source_abs, cases, timeout) or_return
		}
	}

	emit(ctx, &res, .Runner_Observed, run, p.session_id, p.attempt_id)
	res.data = to_json(run)
	switch run.outcome {
	case "failed", "compile_error":
		res.cli_exit = EXIT_FAILED_SOLUTION
	case "unverified":
		res.cli_exit = EXIT_UNVERIFIED
		append(&res.warnings, "unchecked cases remain separate from verified passing evidence")
	}
	return
}

// check_cases validates the supplied cases. A verified oracle needs an
// expected output.
@(private = "file")
check_cases :: proc(cases: []Test_Case) -> (checked: []Test_Case, err: Op_Error) {
	checked = slice.clone(cases)
	for &c in checked {
		enum_value(COMPARATOR_NAMES, "comparator", c.comparator) or_return
		if c.provenance == "" {
			return nil, invalid(
				"each case needs a provenance naming where its expected output came from",
			)
		}
		_, has_expected := c.expected.?
		c.oracle_verified &&= has_expected
	}
	return checked, nil
}

@(private = "file")
run_cases :: proc(
	res: ^Result,
	run: ^Runner_Observed,
	source_abs: string,
	cases: []Test_Case,
	timeout: time.Duration,
) -> Op_Error {
	build_dir, dir_err := os.make_directory_temp("", "algolearn-build-*", context.allocator)
	if dir_err != nil {
		return fail(.Storage_Error, "could not create the bounded build directory")
	}
	defer os.remove_all(build_dir)
	binary := join(build_dir, "solution")
	build := judge.build_odin(source_abs, binary, "-o:none", timeout)
	if build.start_failed {
		return fail(.Unsupported_Capability, "could not start the Odin compiler")
	}
	if !safeio.ok(build) {
		compile_error(res, run, build.timed_out, build.output_exceeded, build.stderr)
		return nil
	}

	run.cases = make([]Case_Result, len(cases))
	tally: judge.Tally
	for c, i in cases {
		comparator, _ := parse_enum(COMPARATOR_NAMES, c.comparator)
		expected, has_expected := c.expected.?
		verified := has_expected && c.oracle_verified
		result, passed := judge.run_case(binary, c.input, expected, COMPARE[comparator], timeout)
		passed &&= verified
		judge.tally_case(&tally, verified, passed)
		run.cases[i] = {
			case_id               = fmt.aprintf("case_%d", i + 1),
			name                  = c.name,
			verified              = verified,
			passed                = passed,
			comparator            = c.comparator,
			provenance            = c.provenance,
			exit_code             = result.exit_code,
			timed_out             = result.timed_out,
			output_limit_exceeded = result.output_exceeded,
			actual                = result.stdout,
			stderr                = result.stderr,
		}
	}
	finish_tally(run, tally)
	return nil
}

// run_package_tests runs `odin test` on the package holding the source, one
// case per @(test) procedure. Its tests are verified only while they match
// the tests_hash the attempt began with.
@(private = "file")
run_package_tests :: proc(
	ctx: ^Context,
	res: ^Result,
	run: ^Runner_Observed,
	p: Test_Run_Params,
	timeout: time.Duration,
) -> Op_Error {
	dir := os.dir(join(ctx.workspace, p.source_path))
	baseline_known := p.tests_hash != ""
	run.tests_modified = baseline_known && package_tests_hash(dir) != p.tests_hash
	provenance := "package_tests"
	if problem, key_err := parse_problem_key(p.problem_key); key_err == nil {
		if traits, _ := provider_traits(problem.provider); traits.test_provenance != "" {
			provenance = traits.test_provenance
		}
	}

	build_dir, dir_err := os.make_directory_temp("", "algolearn-tests-*", context.allocator)
	if dir_err != nil {
		return fail(.Storage_Error, "could not create the bounded build directory")
	}
	defer os.remove_all(build_dir)
	process, tests, reported := judge.run_test_package(
		dir,
		build_dir,
		timeout + PACKAGE_BUILD_ALLOWANCE,
	)
	if process.start_failed {
		return fail(.Unsupported_Capability, "could not start the Odin compiler")
	}
	if !reported {
		// Without a report the package did not build, or the run never finished.
		compile_error(res, run, process.timed_out, process.output_exceeded, process.stderr)
		if process.timed_out {
			run.outcome = "failed"
		}
		return nil
	}

	run.cases = make([]Case_Result, len(tests))
	tally: judge.Tally
	for test, i in tests {
		verified := baseline_known && !run.tests_modified
		passed := verified && test.success
		judge.tally_case(&tally, verified, passed)
		run.cases[i] = {
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
	finish_tally(run, tally)
	switch {
	case !baseline_known:
		append(
			&res.warnings,
			"no tests_hash was supplied, so the tests cannot be shown unchanged since the attempt began; the run is unverified",
		)
		append(&res.next_actions, "pass the tests_hash that attempt_start returned")
	case run.tests_modified:
		append(
			&res.warnings,
			"the package's *_test.odin files changed after the attempt began; restore them for this run to count as evidence",
		)
	}
	return nil
}

@(private = "file")
compile_error :: proc(
	res: ^Result,
	run: ^Runner_Observed,
	timed_out, output_exceeded: bool,
	diagnostic: string,
) {
	run.outcome = "compile_error"
	append(&res.warnings, "the source did not build; see the diagnostic in the case result")
	run.cases = make([]Case_Result, 1)
	run.cases[0] = {
		case_id               = "build",
		name                  = "build",
		timed_out             = timed_out,
		output_limit_exceeded = output_exceeded,
		stderr                = diagnostic,
	}
}

@(private = "file")
finish_tally :: proc(run: ^Runner_Observed, tally: judge.Tally) {
	run.outcome = judge.outcome(tally)
	run.verified_passed, run.verified_failed, run.unchecked =
		tally.verified_passed, tally.verified_failed, tally.unchecked
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
