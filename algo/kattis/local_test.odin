package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"
import "../safeio"

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
// comparing against the matching .out file.
cmd_test :: proc(dir: string, as_json: bool) -> Error {
	solution := join(dir, "solution.odin")
	if !os.is_file(solution) {
		fmt.eprintln("no solution at", solution)
		return .File
	}
	// An absolute path: a bare name like "solution" would be searched on PATH.
	dir_abs, abs_err := os.get_absolute_path(dir, context.allocator)
	if abs_err != nil {
		return .File
	}
	binary := join(dir_abs, "solution")
	build := safeio.run({"odin", "build", solution, "-file", "-o:speed", strings.concatenate({"-out:", binary})}, timeout = BUILD_TIMEOUT)
	if !safeio.ok(build) {
		if as_json {
			print_json(Compile_Report{SCHEMA_VERSION, "compile_error", build.stderr, build.timed_out, build.output_exceeded})
		} else {
			fmt.eprintln("build failed:")
			fmt.eprintln(build.stderr)
		}
		return .Build_Failed
	}

	samples_dir := join(dir, "samples")
	entries, list_err := os.read_all_directory_by_path(samples_dir, context.allocator)
	if list_err != nil {
		fmt.eprintf("cannot list %s: run `kattis get` first\n", samples_dir)
		return .File
	}
	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool { return a.name < b.name })

	cases := make([dynamic]Case_Report)
	for entry in entries {
		if !strings.has_suffix(entry.name, ".in") {
			continue
		}
		c := run_sample(binary, samples_dir, strings.trim_suffix(entry.name, ".in"))
		append(&cases, c)
		if !as_json {
			print_case(c)
		}
	}

	report := Test_Report{schema_version = SCHEMA_VERSION, cases = cases[:]}
	for c in cases {
		switch {
		case !c.verified: report.unchecked += 1
		case c.passed:    report.verified_passed += 1
		case:             report.verified_failed += 1
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

	if as_json {
		print_json(report)
	} else {
		fmt.eprintf("%d/%d samples passed\n", report.verified_passed, len(cases))
	}
	return nil if report.outcome == "passed" else .Samples_Failed
}

run_sample :: proc(binary, samples_dir, name: string) -> (c: Case_Report) {
	c = {name = name, provenance = "official_sample", comparator = "trimmed"}
	expected, expected_err := os.read_entire_file(join(samples_dir, strings.concatenate({name, ".out"})), context.allocator)
	if expected_err != nil {
		c.provenance = "missing_expected_output"
		return
	}
	c.verified = true
	c.expected = string(expected)

	input, input_err := os.read_entire_file(join(samples_dir, strings.concatenate({name, ".in"})), context.allocator)
	if input_err != nil {
		c.runtime_error = "cannot read the sample input"
		return
	}
	result := safeio.run({binary}, stdin = string(input), timeout = RUN_TIMEOUT)
	c.actual = result.stdout
	c.timed_out = result.timed_out
	c.output_limit_exceeded = result.output_exceeded
	switch {
	case result.start_failed:
		c.runtime_error = "could not start the solution"
	case result.timed_out:
		c.runtime_error = "time limit exceeded"
	case result.output_exceeded:
		c.runtime_error = "output limit exceeded"
	case result.exit_code != 0:
		c.runtime_error = fmt.aprintf("exit code %d: %s", result.exit_code, result.stderr)
	case:
		c.passed = normalize_output(c.actual) == normalize_output(c.expected)
	}
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

// normalize_output drops carriage returns and trailing whitespace so line
// ending and final-newline differences do not fail a sample.
normalize_output :: proc(s: string) -> string {
	without_cr, _ := strings.remove_all(s, "\r")
	return strings.trim_right(without_cr, " \t\n")
}
