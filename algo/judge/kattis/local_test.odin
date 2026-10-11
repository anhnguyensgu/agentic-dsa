package kattis

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"
import judge ".."
import "../../safeio"

BUILD_TIMEOUT :: 30 * time.Second
RUN_TIMEOUT :: 10 * time.Second

Compile_Report :: struct {
	schema_version:        int,
	outcome:               string,
	diagnostic:            string,
	timed_out:             bool,
	output_limit_exceeded: bool,
}

Test_Report :: struct {
	schema_version:  int,
	outcome:         string, // passed | failed | unverified
	verified_passed: int,
	verified_failed: int,
	unchecked:       int,
	cases:           []Case_Report,
}

Case_Report :: struct {
	name:                  string,
	verified:              bool, // false when there is no expected output to check against
	passed:                bool,
	provenance:            string,
	comparator:            string,
	actual:                string,
	expected:              string,
	runtime_error:         string,
	timed_out:             bool,
	output_limit_exceeded: bool,
}

// cmd_test builds dir/solution.odin and runs it on every samples/*.in file,
// comparing against the matching .out file. --timeout (seconds) bounds the
// build and each sample; without it the defaults above apply.
cmd_test :: proc(o: Options) -> Error {
	dir, timeout, as_json := o.positionals[0], o.timeout, o.json
	solution := judge.join(dir, "solution.odin")
	if !os.is_file(solution) {
		fmt.eprintln("no solution at", solution)
		return .File
	}
	// An absolute path: a bare name like "solution" would be searched on PATH.
	dir_abs, abs_err := os.get_absolute_path(dir, context.allocator)
	if abs_err != nil {
		return .File
	}
	build_timeout, run_timeout := BUILD_TIMEOUT, RUN_TIMEOUT
	if timeout > 0 {
		build_timeout = time.Duration(timeout) * time.Second
		run_timeout = build_timeout
	}
	binary := judge.join(dir_abs, "solution")
	build := judge.build_odin(solution, binary, "-o:speed", build_timeout)
	if !safeio.ok(build) {
		if as_json {
			judge.print_json(Compile_Report{SCHEMA_VERSION, "compile_error", build.stderr, build.timed_out, build.output_exceeded})
		} else {
			fmt.eprintln("build failed:")
			fmt.eprintln(build.stderr)
		}
		return .Build_Failed
	}

	samples_dir := judge.join(dir, "samples")
	entries, list_err := os.read_all_directory_by_path(samples_dir, context.allocator)
	if list_err != nil {
		fmt.eprintf("cannot list %s: run `algo judge kattis get` first\n", samples_dir)
		return .File
	}
	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool { return a.name < b.name })

	cases := make([dynamic]Case_Report)
	for entry in entries {
		if !strings.has_suffix(entry.name, ".in") {
			continue
		}
		c := run_sample(binary, samples_dir, strings.trim_suffix(entry.name, ".in"), run_timeout)
		append(&cases, c)
		if !as_json {
			print_case(c)
		}
	}

	tally: judge.Tally
	for c in cases {
		judge.tally_case(&tally, c.verified, c.passed)
	}
	report := Test_Report{
		schema_version  = SCHEMA_VERSION,
		outcome         = judge.outcome(tally),
		verified_passed = tally.verified_passed,
		verified_failed = tally.verified_failed,
		unchecked       = tally.unchecked,
		cases           = cases[:],
	}

	if as_json {
		judge.print_json(report)
	} else {
		fmt.eprintf("%d/%d samples passed\n", report.verified_passed, len(cases))
	}
	switch report.outcome {
	case "passed":     return nil
	case "unverified": return .Unchecked
	}
	return .Samples_Failed
}

run_sample :: proc(binary, samples_dir, name: string, timeout: time.Duration) -> (c: Case_Report) {
	// Reports have always labelled this comparison "trimmed".
	c = {name = name, provenance = "official_sample", comparator = "trimmed"}
	expected, expected_err := os.read_entire_file(judge.join(samples_dir, strings.concatenate({name, ".out"})), context.allocator)
	if expected_err != nil {
		c.provenance = "missing_expected_output"
		return
	}
	c.verified = true
	c.expected = string(expected)

	input, input_err := os.read_entire_file(judge.join(samples_dir, strings.concatenate({name, ".in"})), context.allocator)
	if input_err != nil {
		c.runtime_error = "cannot read the sample input"
		return
	}
	result: safeio.Process_Result
	result, c.passed = judge.run_case(binary, string(input), c.expected, judge.compare_trailing, timeout)
	c.actual = result.stdout
	c.timed_out = result.timed_out
	c.output_limit_exceeded = result.output_exceeded
	c.runtime_error = judge.failure_reason(result)
	return
}

print_case :: proc(c: Case_Report) {
	switch {
	case !c.verified:
		fmt.eprintf("%s: missing expected output file\n", c.name)
	case c.runtime_error != "":
		fmt.eprintf("%s: runtime error %s\n", c.name, c.runtime_error)
	case c.passed:
		fmt.printf("%s: PASS\n", c.name)
	case:
		fmt.printf("%s: FAIL\n  want: %q\n  got:  %q\n", c.name, strings.trim_space(c.expected), strings.trim_space(c.actual))
	}
}
