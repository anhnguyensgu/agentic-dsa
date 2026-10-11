package leetcode

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import judge ".."
import "../../safeio"

odin_type :: proc(lc: string) -> (name: string, supported: bool) {
	if strings.has_suffix(lc, "[]") {
		base, ok := odin_type(lc[:len(lc) - 2])
		return judge.concat("[]", base), ok
	}
	switch lc {
	case "integer", "long":
		return "int", true
	case "double", "float":
		return "f64", true
	case "boolean":
		return "bool", true
	case "string", "character":
		return "string", true
	case "void":
		return "", true
	}
	return "json.Value", false
}

GENERIC_SOLUTION :: `package main

import "core:encoding/json"

// Inputs use LeetCode's JSON representation. For design questions, input[0]
// is the operations array and input[1] is the arguments array.
// List/tree/graph problems keep their serialized JSON representation here.
solve :: proc(input: []json.Value) -> json.Value {
	panic("implement solve")
}
`

// odin_source generates solution.odin and the adapter spliced into the local
// runner. Problems whose signature has no plain Odin equivalent get a
// generic solve over LeetCode's JSON values.
odin_source :: proc(q: json.Value) -> (solution, adapter: string) {
	metadata, _ := json.parse(jstr(jget(q, "metaData")), .JSON, parse_integers = true)
	params := jarray(jget(metadata, "params"))
	return_type, return_ok := odin_type(jstr(jget(jget(metadata, "return"), "type")))
	typed := return_ok && jstr(jget(metadata, "name")) != "" && !jbool(jget(metadata, "systemdesign"))

	param_types := make([]string, len(params))
	for p, i in params {
		type_name, supported := odin_type(jstr(jget(p, "type")))
		typed &&= supported && type_name != ""
		param_types[i] = type_name
	}
	if !typed {
		return GENERIC_SOLUTION, "\treturn solve(input)"
	}

	sol := strings.builder_make()
	fmt.sbprintf(&sol, "package main\n\n// %s\n", jstr(jget(q, "title")))
	for p, i in params {
		fmt.sbprintf(&sol, "// arg%d: %s (%s)\n", i, jstr(jget(p, "name")), jstr(jget(p, "type")))
	}
	strings.write_string(&sol, "solve :: proc(")
	for type_name, i in param_types {
		fmt.sbprintf(&sol, "%sarg%d: %s", ", " if i > 0 else "", i, type_name)
	}
	strings.write_string(&sol, ")")
	if return_type != "" {
		fmt.sbprintf(&sol, " -> %s", return_type)
	}
	strings.write_string(&sol, " {\n\tpanic(\"implement solve\")\n}\n")

	args := strings.builder_make()
	for _, i in param_types {
		fmt.sbprintf(&args, "%sarg%d", ", " if i > 0 else "", i)
	}
	adp := strings.builder_make()
	fmt.sbprintf(&adp, "\tif len(input) != %d {{ panic(\"wrong number of inputs\") }}\n", len(params))
	for type_name, i in param_types {
		fmt.sbprintf(&adp, "\targ%d: %s\n\tdecode(input[%d], &arg%d)\n", i, type_name, i, i)
	}
	switch {
	case return_type != "":
		fmt.sbprintf(&adp, "\treturn encode(solve(%s))", strings.to_string(args))
	case len(params) > 0:
		// In-place problems: compare the mutated first input, as LeetCode does
		// for the common void-returning array/matrix tasks.
		fmt.sbprintf(&adp, "\tsolve(%s)\n\treturn encode(arg0)", strings.to_string(args))
	case:
		strings.write_string(&adp, "\tsolve()\n\treturn json.Null(nil)")
	}
	return strings.to_string(sol), strings.to_string(adp)
}

// example_cases builds cases.json from the listed examples. An expected value
// is filled in (and checked) only when the statement's "Output:" line is JSON.
example_cases :: proc(q: json.Value) -> json.Array {
	examples := jarray(jget(q, "exampleTestcaseList"))
	if len(examples) == 0 && jstr(jget(q, "sampleTestCase")) != "" {
		append(&examples, jget(q, "sampleTestCase"))
	}
	outputs := strings.split(judge.html_text(jstr(jget(q, "content"))), "Output:")
	cases := make(json.Array, 0, len(examples))
	for example, i in examples {
		inputs := make(json.Array)
		remaining := jstr(example)
		for line in strings.split_lines_iterator(&remaining) {
			if strings.trim_space(line) == "" {
				continue
			}
			v, parse_err := json.parse(line, .JSON, parse_integers = true)
			if parse_err != nil {
				inputs = nil
				break
			}
			append(&inputs, v)
		}
		c := jobject()
		c["name"] = fmt.aprintf("Example %d", i + 1)
		c["input"], c["check"], c["unordered"], c["expected"] = inputs, false, false, json.Null(nil)
		if i + 1 < len(outputs) {
			line, _ := judge.split_once(strings.trim_space(outputs[i + 1]), "\n")
			if v, parse_err := json.parse(strings.trim_space(line), .JSON, parse_integers = true); parse_err == nil {
				c["expected"], c["check"] = v, true
			}
		}
		append(&cases, c)
	}
	return cases
}

Scaffold_Report :: struct {
	directory: string,
	language:  string,
}

// scaffold reserves a fresh directory before writing anything, so existing
// solutions are never overwritten. A failed partial scaffold is kept for
// inspection.
scaffold :: proc(o: Options, q: json.Value) -> Error {
	lang := o.lang if o.lang != "" else "odin"
	if !valid_slug(lang) {
		return .Usage
	}
	source, adapter: string
	if lang == "odin" {
		source, adapter = odin_source(q)
	} else {
		for s in jarray(jget(q, "codeSnippets")) {
			if jstr(jget(s, "langSlug")) == lang {
				source = jstr(jget(s, "code"))
				break
			}
		}
		if source == "" {
			fmt.eprintln("no starter for this language; check `algo judge leetcode languages`")
			return .Unsupported
		}
	}
	content := jstr(jget(q, "content"))
	if content == "" {
		fmt.eprintln("problem content unavailable; check your Premium session")
		return .Not_Found
	}

	dir := o.dir
	if dir == "" {
		id := jstr(jget(q, "questionFrontendId"))
		prefix := judge.concat(id, "-") if judge.digits(id) else ""
		dir = judge.join(o.workspace, judge.concat(prefix, jstr(jget(q, "titleSlug")), "-", lang))
	}
	if mkdir_err := os.make_directory_all(os.dir(dir), os.perm(0o700)); mkdir_err != nil && mkdir_err != .Exist {
		return .File
	}
	if os.make_directory(dir, os.perm(0o700)) != nil {
		fmt.eprintln("destination exists or cannot be created; select a new --dir:", dir)
		return .File
	}

	examples := jarray(jget(q, "exampleTestcaseList"))
	example_inputs := make([]string, len(examples))
	for v, i in examples {
		example_inputs[i] = jstr(v)
	}
	readme := fmt.aprintf(
		"# %s. %s\n\n%s%s/\n\n%s\n",
		jstr(jget(q, "questionFrontendId")),
		jstr(jget(q, "title")),
		PROBLEM_URL_PREFIX,
		jstr(jget(q, "titleSlug")),
		judge.html_text(content),
	)
	judge.write_file(judge.join(dir, "problem.json"), jencode(q)) or_return
	judge.write_file(judge.join(dir, "README.md"), readme) or_return
	judge.write_file(judge.join(dir, judge.concat("solution", language_extension(lang))), judge.concat(source, "\n")) or_return
	judge.write_file(judge.join(dir, "input.txt"), judge.concat(strings.join(example_inputs, "\n"), "\n")) or_return
	judge.write_file(judge.join(dir, "cases.json"), judge.concat(jencode(example_cases(q)), "\n")) or_return
	if lang == "odin" {
		runner, _ := strings.replace_all(#load("local_runner.txt", string), "// GENERATED_ADAPTER", adapter)
		judge.write_file(judge.join(dir, "runner.odin"), runner) or_return
	}

	if o.json {
		judge.print_json(Scaffold_Report{dir, lang})
	} else {
		fmt.println("Created", dir)
		if lang == "odin" {
			fmt.printf("Implement solution.odin, review cases.json, then: algo judge leetcode test %s\n", dir)
		}
	}
	return nil
}

// run_local runs a bounded, credential-free child and relays its output.
run_local :: proc(command: []string, timeout: int) -> (exit_code: int, err: Error) {
	result := safeio.run(command, timeout = time.Duration(timeout) * time.Second)
	os.write_string(os.stdout, result.stdout)
	os.write_string(os.stderr, result.stderr)
	switch {
	case result.start_failed:
		fmt.eprintln("could not start", command[0])
		return 0, .File
	case result.timed_out:       return 0, .Timeout
	case result.output_exceeded: return 0, .Output_Limit
	}
	return result.exit_code, nil
}

cmd_local_test :: proc(o: Options) -> Error {
	dir := o.positionals[0]
	if !os.is_file(judge.join(dir, "runner.odin")) {
		fmt.eprintln("expected an Odin workspace containing runner.odin")
		return .File
	}
	tmp, tmp_err := os.make_directory_temp("", "leetcode-local-*", context.allocator)
	if tmp_err != nil {
		return .File
	}
	defer os.remove_all(tmp)

	binary := judge.join(tmp, "solution")
	if code := run_local({"odin", "build", dir, judge.concat("-out:", binary)}, o.timeout) or_return; code != 0 {
		return .Judge_Failed
	}
	command := [?]string{binary, judge.join(dir, "cases.json"), "--json"}
	switch run_local(command[:3 if o.json else 2], o.timeout) or_return {
	case 0: return nil
	case 4: return .Unchecked
	}
	return .Judge_Failed
}
