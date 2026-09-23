package main

import "core:encoding/json"
import "core:mem"
import "core:strings"
import "core:testing"

@(test)
cli_rejects_invalid_values :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	cases := [][]string{
		{"show"}, {"show","a","b"}, {"run","two-sum"},
		{"list","--limit","0"}, {"list","--skip","-1"},
		{"list","--limit","101"}, {"list","--difficulty","easy"},
		{"list","--status","invalid"}, {"list","--limit"},
		{"list","--offline","--refresh"}, {"list","--unknown"},
		{"test","a","--timeout","0"},
	}
	for args in cases { _, e := parse_options(args); testing.expectf(t,e == .Usage,"accepted %v",args) }
	o, e := parse_options({"list","two sum","--tag","array","--tag","hash-table","--limit","3","--free","--json"})
	testing.expect_value(t,e,Error.None)
	testing.expect_value(t,len(o.tags),2)
	testing.expect_value(t,o.limit,3)
	testing.expect(t,o.free && o.json)
}

@(test)
judge_completion_is_not_acceptance :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	cases := []struct {body:string, expected:Error}{
		{`{"state":"SUCCESS","status_code":10,"total_correct":3,"total_testcases":3}`, .None},
		{`{"state":"SUCCESS","status_code":10,"correct_answer":false}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":10,"total_correct":2,"total_testcases":3}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":11}`, .Judge_Failed},
		{`{"state":"SUCCESS","status_code":20}`, .Judge_Failed},
		{`{"state":"SUCCESS"}`, .API},
		{`{"state":"PENDING","status_code":10}`, .API},
	}
	for c in cases {
		v, _ := json.parse(c.body,.JSON,parse_integers=true)
		testing.expect_value(t,judge_verdict(v),c.expected)
	}
	ids := []string{"../x", "a/b", "a?x", "", "a\n"}
	for id in ids { testing.expect(t,!valid_judge_id(id)) }
	testing.expect(t,valid_judge_id("runcode_123_abc"))
	testing.expect(t,valid_judge_id("runcode_123.123_abc"))
	testing.expect(t,!valid_judge_id(".."))
}

@(test)
scaffolding_preserves_types_and_marks_unknown_outputs :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	q := jobject()
	q["title"] = "Example"
	q["metaData"] = `{"name":"solve","params":[{"name":"matrix","type":"integer[][]"}],"return":{"type":"integer"}}`
	q["content"] = "<pre><strong>Output:</strong> 42</pre>"
	q["exampleTestcaseList"] = json.parse(`["[[1,2],[3,4]]","[[5]]"]`) or_else nil
	source, adapter := odin_source(q)
	testing.expect(t,strings.contains(source,"arg0: [][]int"))
	testing.expect(t,strings.contains(source,"-> int {"))
	testing.expect(t,strings.contains(adapter,"len(input) != 1 {"))
	testing.expect(t,!strings.contains(source,"MISSING"))
	cases := example_cases(q)
	testing.expect_value(t,len(cases),2)
	testing.expect(t,jbool(jget(cases[0],"check")))
	testing.expect(t,!jbool(jget(cases[1],"check")))
	testing.expect_value(t,jint(jget(cases[0],"expected")),42)
	q["metaData"] = `{"systemdesign":true}`
	source, _ = odin_source(q)
	testing.expect(t,strings.contains(source,"input: []json.Value"))
}

@(test)
problem_references_reject_path_traversal :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)
	slugs := []string{"", "../secret", "a/b", "A", "a?x", "-abc"}
	for s in slugs { testing.expect(t,!valid_slug(s)) }
	testing.expect(t,valid_slug("two-sum-ii"))
	testing.expect_value(t,html_text("<p>x &lt; 10<sup>4</sup> &amp; y</p>"),"x < 10^4 & y")
}
