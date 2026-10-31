package learn

// Handler tests: input validation, emitted events, and the provider and
// problem-key rules that keep names from ever becoming paths.

import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

fake_now :: proc() -> time.Time {
	t, _ := time.components_to_time(2026, 10, 31, 9, 0, 0)
	return t
}

temp_workspace :: proc(t: ^testing.T) -> string {
	dir, err := os.make_directory_temp("", "algolearn-test-*", context.allocator)
	testing.expect_value(t, err, nil)
	return dir
}

test_context :: proc(workspace: string) -> Context {
	return {workspace = workspace, actor = "agent:test", host = "test", now = fake_now()}
}

call :: proc(t: ^testing.T, ctx: ^Context, operation, text: string) -> Result {
	input, req, message := new_request(text)
	testing.expect_value(t, message, "")
	res, found := run_operation(operation, ctx, input, req)
	testing.expect(t, found)
	return res
}

has :: proc(res: Result, fragment: string) -> bool {
	return strings.contains(string(res.data), fragment)
}

@(test)
handlers_reject_invalid_inputs :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	ctx := test_context(ws)

	cases := [?]struct {
		operation, input: string,
	} {


		// Unexpected fields are rejected, including the old revision envelope.
		{
			"attempt_start",
			`{"problem_key":"kattis:hello","language":"odin","expected_revision":1}`,
		},
		// Required fields must be present.
		{"attempt_start", `{"problem_key":"kattis:hello"}`},
		// Problem keys name a known provider and a path-safe slug.
		{"attempt_start", `{"problem_key":"leetcode:../x","language":"odin"}`},
		// Invalid enums are rejected.
		{"attempt_start", `{"problem_key":"kattis:hello","language":"odin","action":"move"}`},
		{"test_run", `{"source_path":"a.odin","runner_kind":"python"}`},
		// Wrongly typed fields are rejected.
		{"test_run", `{"source_path":"a.odin","timeout_seconds":"slow"}`},
		{"test_run", `{"source_path":"a.odin","timeout_seconds":600}`},
		// Paths stay inside the workspace.
		{"test_run", `{"source_path":"../escape.odin"}`},
		{
			"submit",
			`{"problem_key":"kattis:hello","language":"odin","source_path":"/etc/passwd","authorization_reference":"x"}`,
		},
		// A remote id is never an option of the provider command.
		{"job_check", `{"provider":"kattis","remote_id":"--help"}`},
		{"job_check", `{"provider":"codeforces","remote_id":"1"}`},
	}
	for c in cases {
		res := call(t, &ctx, c.operation, c.input)
		testing.expectf(
			t,
			res.err == .Invalid_Input,
			"%s %s: got %v",
			c.operation,
			c.input,
			res.err,
		)
		testing.expectf(
			t,
			len(res.events) == 0,
			"%s emitted an event on invalid input",
			c.operation,
		)
	}
}

@(test)
attempts_emit_one_event_and_mint_fresh_ids :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	ctx := test_context(ws)

	request := `{"problem_key":"kattis:hello","language":"odin","session_id":"s1"}`
	first := call(t, &ctx, "attempt_start", request)
	second := call(t, &ctx, "attempt_start", request)
	testing.expect_value(t, first.status, Status.Completed)
	testing.expect_value(t, len(first.events), 1)
	ev := first.events[0]
	testing.expect_value(t, ev.type, "attempt_started")
	testing.expect_value(t, ev.schema_version, SCHEMA_VERSION)
	testing.expect_value(t, ev.session_id, "s1")
	testing.expect_value(t, ev.actor, "agent:test")
	testing.expect_value(t, ev.timestamp, "2026-10-31T09:00:00Z")
	testing.expect(t, strings.has_prefix(ev.event_id, "ev_"))
	testing.expect(t, strings.has_prefix(ev.attempt_id, "att_"))
	testing.expect(t, has(first, ev.attempt_id))
	// Nothing is deduplicated: the same request makes a second attempt.
	testing.expect(t, second.events[0].attempt_id != ev.attempt_id)
	testing.expect(t, second.events[0].event_id != ev.event_id)
	// And nothing is stored beside the attempts.
	testing.expect(t, !os.exists(join(ws, ".algo")))
}

@(test)
test_runs_without_verified_cases_are_unverified :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	ctx := test_context(ws)

	testing.expect_value(
		t,
		write_private_file(join(ws, "a.odin"), "package main\nmain :: proc() {}\n"),
		nil,
	)
	// Zero cases never count as passing, and still produce evidence to keep.
	empty := call(t, &ctx, "test_run", `{"source_path":"a.odin","attempt_id":"att_1"}`)
	testing.expect_value(t, empty.status, Status.Completed)
	testing.expect_value(t, empty.cli_exit, EXIT_UNVERIFIED)
	testing.expect(t, has(empty, `"outcome":"unverified"`))
	testing.expect_value(t, len(empty.events), 1)
	testing.expect_value(t, empty.events[0].type, "runner_observed")
	testing.expect_value(t, empty.events[0].attempt_id, "att_1")

	// Each case names where its expected output came from.
	unsourced := call(
		t,
		&ctx,
		"test_run",
		`{"source_path":"a.odin","cases":[{"input":"","expected":"","comparator":"exact","provenance":""}]}`,
	)
	testing.expect_value(t, unsourced.err, Engine_Error.Invalid_Input)
	// Only Odin sources run locally.
	testing.expect_value(t, write_private_file(join(ws, "a.py"), "print(1)\n"), nil)
	python := call(t, &ctx, "test_run", `{"source_path":"a.py"}`)
	testing.expect_value(t, python.err, Engine_Error.Unsupported_Capability)
}

@(test)
submit_refuses_stale_or_unjudged_sources_before_sending :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)
	ctx := test_context(ws)

	testing.expect_value(t, write_private_file(join(ws, "a.odin"), "package main\n"), nil)
	leetcode := call(
		t,
		&ctx,
		"submit",
		`{"problem_key":"leetcode:two-sum","language":"odin","source_path":"a.odin","authorization_reference":"asked"}`,
	)
	testing.expect_value(t, leetcode.err, Engine_Error.Unsupported_Capability)
	stale := call(
		t,
		&ctx,
		"submit",
		`{"problem_key":"kattis:hello","language":"odin","source_path":"a.odin","source_hash":"00","authorization_reference":"asked"}`,
	)
	testing.expect_value(t, stale.err, Engine_Error.Stale_Source)
	testing.expect_value(t, len(stale.events), 0)
}

@(test)
problem_keys_name_any_provider_problem_as_one_path_component :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	for key in ([?]string{"leetcode:trapping-rain-water", "kattis:hello", "kattis:3dprinter", "exercism:two-fer"}) {
		problem, err := parse_problem_key(key)
		testing.expectf(t, err == nil, "%s should be accepted", key)
		testing.expect_value(t, problem.key, key)
	}
	problem, _ := parse_problem_key("leetcode:two-sum")
	testing.expect_value(t, problem.provider, "leetcode")
	testing.expect_value(t, problem.slug, "two-sum")

	rejected := [?]string {
		"",
		"two-sum",
		"leetcode:",
		"codeforces:1a",
		"leetcode:Two-Sum",
		"leetcode:..",
		"leetcode:.hidden",
		"leetcode:a/b",
		"leetcode:a b",
		"kattis:../../etc",
	}
	for key in rejected {
		_, err := parse_problem_key(key)
		testing.expectf(t, err != nil, "%q should be rejected", key)
	}
}

@(test)
provider_names_from_requests_never_become_paths :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)
	ws := temp_workspace(t)
	defer os.remove_all(ws)

	// A request could name any provider; only known ones resolve.
	evil := join(ws, "evil")
	testing.expect_value(t, write_private_file(evil, "#!/bin/sh\n"), nil)
	for name in ([?]string{"../evil", "evil", "/bin/sh", ""}) {
		_, err := provider_command(name)
		testing.expectf(t, err != nil, "resolved provider %q", name)
	}
	for provider in PROVIDERS {
		command, err := provider_command(provider.name)
		testing.expectf(t, err == nil, "known provider %q did not resolve", provider.name)
		testing.expect_value(t, len(command), 3)
		testing.expect_value(t, command[1], "judge")
		testing.expect_value(t, command[2], provider.name)
	}
}

@(test)
provider_traits_describe_every_provider :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	for provider, id in PROVIDERS {
		testing.expectf(
			t,
			provider.name != "" && provider.title != "",
			"provider %v is unnamed",
			id,
		)
		found, ok := provider_traits(provider.name)
		testing.expect(t, ok && found.name == provider.name)
		// A provider without verdicts can only upload, and a scaffolded
		// attempt needs a starter source.
		testing.expect_value(t, provider.check == .None, provider.submit == .Upload)
		testing.expectf(
			t,
			provider.downloads || provider.template != "",
			"%s has no template",
			provider.name,
		)
	}
	_, ok := provider_traits("codeforces")
	testing.expect(t, !ok)
	testing.expect_value(t, len(provider_names()), len(PROVIDERS))
}
