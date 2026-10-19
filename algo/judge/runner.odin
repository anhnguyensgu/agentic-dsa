package judge

// The local stdin/stdout runner shared by provider `test` commands and the
// learning engine's test_run: build one Odin file, run it once per case with
// the case input on stdin, and compare stdout. Every child is bounded by a
// timeout and an output limit and gets a credential-free environment (safeio).

import "../safeio"
import "core:fmt"
import "core:strings"
import "core:time"

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
