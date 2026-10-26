package judge

// The local stdin/stdout runner shared by provider `test` commands and the
// learning engine's test_run: build one Odin file, run it once per case with
// the case input on stdin, and compare stdout. Every child is bounded by a
// timeout and an output limit and gets a credential-free environment (safeio).
// run_test_package runs an Odin test package instead, such as an Exercism
// exercise and its test file.

import "../safeio"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

// Package_Test is one @(test) procedure's result from `odin test`.
Package_Test :: struct {
	name:    string,
	success: bool,
}

// run_test_package builds and runs the Odin test package in dir, writing the
// binary and core:testing's JSON report into build_dir. tests lists every
// test by name. reported is false when the package did not build or the
// runner wrote no report; process then says why.
run_test_package :: proc(
	dir, build_dir: string,
	timeout: time.Duration,
) -> (
	process: safeio.Process_Result,
	tests: []Package_Test,
	reported: bool,
) {
	report_path := join(build_dir, "report.json")
	process = safeio.run(
		{
			"odin",
			"test",
			dir,
			concat("-out:", join(build_dir, "tests")),
			concat("-define:ODIN_TEST_JSON_REPORT=", report_path),
			"-define:ODIN_TEST_FANCY=false",
		},
		timeout = timeout,
	)
	data, read_err := os.read_entire_file(report_path, context.allocator)
	if read_err != nil {
		return
	}
	// {"packages": {"<package>": [{"name": ..., "success": ...}]}, ...}
	report: struct {
		packages: map[string][]Package_Test,
	}
	if !json.is_valid(data, .JSON) || json.unmarshal(data, &report, .JSON) != nil {
		return
	}
	list := make([dynamic]Package_Test)
	for _, package_tests in report.packages {
		append(&list, ..package_tests)
	}
	slice.sort_by(list[:], proc(a, b: Package_Test) -> bool {return a.name < b.name})
	return process, list[:], true
}

Compare_Proc :: proc(actual, expected: string) -> bool

compare_exact :: proc(actual, expected: string) -> bool {
	return actual == expected
}

compare_trimmed :: proc(actual, expected: string) -> bool {
	return strings.trim_space(actual) == strings.trim_space(expected)
}

compare_tokens :: proc(actual, expected: string) -> bool {
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

// compare_trailing ignores carriage returns and trailing whitespace, so line
// ending and final-newline differences do not fail a sample.
compare_trailing :: proc(actual, expected: string) -> bool {
	normalize :: proc(s: string) -> string {
		without_cr, _ := strings.remove_all(s, "\r")
		return strings.trim_right(without_cr, " \t\n")
	}
	return normalize(actual) == normalize(expected)
}

// build_odin compiles one Odin source file into binary, an absolute path (a
// bare name would be searched on PATH when run).
build_odin :: proc(
	source, binary, optimization: string,
	timeout: time.Duration,
) -> safeio.Process_Result {
	return safeio.run(
		{"odin", "build", source, "-file", optimization, concat("-out:", binary)},
		timeout = timeout,
	)
}

// run_case runs binary once with input on stdin. The case passes only when the
// process finished cleanly and compare accepts its stdout.
run_case :: proc(
	binary, input, expected: string,
	compare: Compare_Proc,
	timeout: time.Duration,
) -> (
	result: safeio.Process_Result,
	passed: bool,
) {
	result = safeio.run({binary}, stdin = input, timeout = timeout)
	passed = safeio.ok(result) && compare(result.stdout, expected)
	return
}

// failure_reason describes why a run did not finish cleanly; "" when it did.
failure_reason :: proc(r: safeio.Process_Result) -> string {
	switch {
	case r.start_failed:
		return "could not start the solution"
	case r.timed_out:
		return "time limit exceeded"
	case r.output_exceeded:
		return "output limit exceeded"
	case r.exit_code != 0:
		return fmt.aprintf("exit code %d: %s", r.exit_code, r.stderr)
	}
	return ""
}

// Tally counts cases. Only a case with a verified expected output can pass
// or fail; the rest stay unchecked and never count as passing evidence.
Tally :: struct {
	verified_passed: int,
	verified_failed: int,
	unchecked:       int,
}

tally_case :: proc(t: ^Tally, verified, passed: bool) {
	switch {
	case !verified:
		t.unchecked += 1
	case passed:
		t.verified_passed += 1
	case:
		t.verified_failed += 1
	}
}

// outcome is "failed" when any verified case failed, "unverified" when
// unchecked cases remain or nothing passed, and otherwise "passed".
outcome :: proc(t: Tally) -> string {
	switch {
	case t.verified_failed > 0:
		return "failed"
	case t.unchecked > 0 || t.verified_passed == 0:
		return "unverified"
	}
	return "passed"
}
