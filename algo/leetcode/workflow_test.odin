package main

import "core:encoding/json"
import "core:strings"
import "core:testing"

@(test)
cli_rejects_invalid_values :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	invalid := [][]string {
		{"show"},
		{"show", "a", "b"},
		{"run", "two-sum"},
		{"list", "--limit", "0"},
		{"list", "--skip", "-1"},
		{"list", "--limit", "101"},
		{"list", "--difficulty", "easy"},
		{"list", "--status", "invalid"},
		{"list", "--limit"},
		{"list", "--offline", "--refresh"},
		{"list", "--unknown"},
		{"test", "a", "--timeout", "0"},
	}
	for args in invalid {
		_, err := parse_options(args)
		testing.expectf(t, err == .Usage, "accepted %v", args)
	}

	o, err := parse_options({"list", "two sum", "--tag", "array", "--tag", "hash-table", "--limit", "3", "--free", "--json"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, o.command, Command.List)
	testing.expect_value(t, len(o.tags), 2)
	testing.expect_value(t, o.limit, 3)
	testing.expect(t, o.free && o.json)

	// Aliases resolve to their canonical command.
	o, err = parse_options({"search", "graphs"})
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, o.command, Command.List)
}

@(test)
judge_completion_is_not_acceptance :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	cases := []struct {
		body:     string,
		expected: Error,
	} {
		{`{"state":"SUCCESS","status_code":10,"total_correct":3,"total_testcases":3}`, .None},
		{`{"state":"SUCCESS","status_code":10,"correct_answer":false}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":10,"total_correct":2,"total_testcases":3}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":11}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":20}`, .Judge_Failed},
		{`{"state":"SUCCESS"}`, .API},
		{`{"state":"PENDING","status_code":10}`, .API},
	}
	for c in cases {
		v, _ := json.parse(c.body, .JSON, parse_integers = true)
		testing.expect_value(t, judge_verdict(v), c.expected)
	}

	for id in ([]string{"../x", "a/b", "a?x", "", "a\n", ".."}) {
		testing.expectf(t, !valid_judge_id(id), "accepted judge id %q", id)
	}
	testing.expect(t, valid_judge_id("runcode_123_abc"))
	testing.expect(t, valid_judge_id("runcode_123.123_abc"))
}

@(test)
scaffolding_preserves_types_and_marks_unknown_outputs :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	q := jobject()
	q["title"] = "Example"
	q["metaData"] = `{"name":"solve","params":[{"name":"matrix","type":"integer[][]"}],"return":{"type":"integer"}}`
	q["content"] = "<pre><strong>Output:</strong> 42</pre>"
	q["exampleTestcaseList"] = json.parse(`["[[1,2],[3,4]]","[[5]]"]`) or_else nil

	source, adapter := odin_source(q)
	testing.expect(t, strings.contains(source, "arg0: [][]int"))
	testing.expect(t, strings.contains(source, "-> int {"))
	testing.expect(t, strings.contains(adapter, "len(input) != 1 {"))

	// Only the example with a parseable Output line is checked.
	cases := example_cases(q)
	testing.expect_value(t, len(cases), 2)
	testing.expect(t, jbool(jget(cases[0], "check")))
	testing.expect(t, !jbool(jget(cases[1], "check")))
	testing.expect_value(t, jint(jget(cases[0], "expected")), 42)

	// Design problems fall back to raw JSON values.
	q["metaData"] = `{"systemdesign":true}`
	source, _ = odin_source(q)
	testing.expect(t, strings.contains(source, "input: []json.Value"))
}

@(test)
problem_references_reject_path_traversal :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	for slug in ([]string{"", "../secret", "a/b", "A", "a?x", "-abc"}) {
		testing.expectf(t, !valid_slug(slug), "accepted slug %q", slug)
	}
	testing.expect(t, valid_slug("two-sum-ii"))
	testing.expect_value(t, html_text("<p>x &lt; 10<sup>4</sup> &amp; y</p>"), "x < 10^4 & y")
}
