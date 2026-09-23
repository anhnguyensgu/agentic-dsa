package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

odin_type :: proc(lc: string) -> (name: string, supported: bool) {
	if strings.has_suffix(lc, "[]") {
		base, ok := odin_type(lc[:len(lc) - 2])
		return concat("[]", base), ok
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

odin_source :: proc(q: json.Value) -> (solution, adapter: string) {
	metadata, _ := json.parse(jstr(jget(q, "metaData")), .JSON, parse_integers = true)
	params := jarray(jget(metadata, "params"))
	ret, ok := odin_type(jstr(jget(jget(metadata, "return"), "type")))
	typed := ok && jstr(jget(metadata, "name")) != "" && !jbool(jget(metadata, "systemdesign"))
	declarations, names, calls := [dynamic]string{}, [dynamic]string{}, [dynamic]string{}
	for p, i in params {
		type_name, supported := odin_type(jstr(jget(p, "type")))
		typed = typed && supported && type_name != ""
		name := fmt.aprintf("arg%d", i)
		append(&declarations, concat(name, ": ", type_name))
		append(&names, name)
		append(
			&calls,
			fmt.aprintf("\t%s: %s\n\tdecode(input[%d], &%s)\n", name, type_name, i, name),
		)
	}
	if !typed {
		return `package main

import "core:encoding/json"

// Inputs use LeetCode's JSON representation. For design questions, input[0]
// is the operations array and input[1] is the arguments array.
// List/tree/graph problems keep their serialized JSON representation here.
solve :: proc(input: []json.Value) -> json.Value {
	panic("implement solve")
}
`,
			"\treturn solve(input)"
	}
	return_decl := ""
	if ret != "" {return_decl = concat(" -> ", ret)}
	solution = concat("package main\n\n// ", jstr(jget(q, "title")), "\n")
	for p, i in params {solution = concat(solution, fmt.aprintf("// arg%d: %s (%s)\n", i, jstr(jget(p, "name")), jstr(jget(p, "type"))))}
	solution = concat(
		solution,
		fmt.aprintf("solve :: proc(%s)%s", strings.join(declarations[:], ", "), return_decl),
		" {\n\tpanic(\"implement solve\")\n}\n",
	)
	adapter = concat(
		fmt.aprintf("\tif len(input) != %d", len(params)),
		" { panic(\"wrong number of inputs\") }\n",
		strings.join(calls[:], ""),
	)
	if ret == "" {
		// For in-place problems, compare the mutated first input, as LeetCode
		// does for the common void-returning array/matrix tasks.
		adapter = concat(adapter, "\tsolve(", strings.join(names[:], ", "), ")\n")
		if len(names) >
		   0 {adapter = concat(adapter, "\treturn encode(arg0)")} else {adapter = concat(adapter, "\treturn json.Null(nil)")}
	} else {adapter = concat(
			adapter,
			"\treturn encode(solve(",
			strings.join(names[:], ", "),
			"))",
		)}
	return
}

example_cases :: proc(q: json.Value) -> json.Array {
	cases := make(json.Array)
	examples := jarray(jget(q, "exampleTestcaseList"))
	if len(examples) == 0 &&
	   jstr(jget(q, "sampleTestCase")) != "" {append(&examples, jget(q, "sampleTestCase"))}
	description := html_text(jstr(jget(q, "content")))
	outputs := strings.split(description, "Output:")
	for example, i in examples {
		inputs := make(json.Array)
		remaining := jstr(example)
		for line in strings.split_by_byte_iterator(&remaining, '\n') {
			if strings.trim_space(line) == "" {continue}
			v, e := json.parse(line, .JSON, parse_integers = true)
			if e != nil {inputs = nil; break}
			append(&inputs, v)
		}
		c := jobject()
		c["name"] = fmt.aprintf("Example %d", i + 1)
		c["input"], c["check"], c["unordered"] = inputs, false, false
		c["expected"] = json.Null(nil)
		if i + 1 < len(outputs) {
			line, _ := split_once(strings.trim_space(outputs[i + 1]), "\n")
			v, e := json.parse(strings.trim_space(line), .JSON, parse_integers = true)
			if e == nil {c["expected"], c["check"] = v, true}
		}
		append(&cases, c)
	}
	return cases
}

scaffold :: proc(o: Options, q: json.Value) -> Error {
	lang := o.lang
	if lang == "" {lang = "odin"}
	if !valid_slug(lang) {return .Usage}
	source := ""
	adapter := ""
	if lang == "odin" {source, adapter = odin_source(q)} else {
		for s in jarray(jget(q, "codeSnippets")) {if jstr(jget(s, "langSlug")) == lang {source = jstr(jget(s, "code")); break}}
		if source ==
		   "" {fmt.eprintln("no starter for this language; check `leetcode languages`"); return .Unsupported}
	}
	if jstr(jget(q, "content")) ==
	   "" {fmt.eprintln("problem content unavailable; check your Premium session"); return .Not_Found}
	dir := o.dir
	if dir == "" {
		prefix := ""
		if id := jstr(jget(q, "questionFrontendId")); digits(id) {prefix = concat(id, "-")}
		dir = join_path(o.workspace, concat(prefix, jstr(jget(q, "titleSlug")), "-", lang))
	}
	if e := os.make_directory_all(os.dir(dir), os.perm(0o700));
	   e != nil && e != .Exist {return .File}
	if e := os.make_directory(dir, os.perm(0o700)); e != nil {
		fmt.eprintln("destination exists or cannot be created; select a new --dir:", dir)
		return .File
	}
	// A new directory is reserved before any writes; existing solutions are
	// never overwritten. A failed partial scaffold is kept for inspection.
	write_file(join_path(dir, "problem.json"), jencode(q)) or_return
	write_file(
		join_path(dir, "README.md"),
		fmt.aprintf(
			"# %s. %s\n\nhttps://leetcode.com/problems/%s/\n\n%s\n",
			jstr(jget(q, "questionFrontendId")),
			jstr(jget(q, "title")),
			jstr(jget(q, "titleSlug")),
			html_text(jstr(jget(q, "content"))),
		),
	) or_return
	write_file(
		join_path(dir, concat("solution", language_extension(lang))),
		concat(source, "\n"),
	) or_return
	examples := jarray(jget(q, "exampleTestcaseList"))
	input_parts := [dynamic]string{}
	for v in examples {append(&input_parts, jstr(v))}
	write_file(
		join_path(dir, "input.txt"),
		concat(strings.join(input_parts[:], "\n"), "\n"),
	) or_return
	cases := example_cases(q)
	write_file(join_path(dir, "cases.json"), concat(jencode(cases), "\n")) or_return
	if lang == "odin" {
		harness :=
			strings.replace_all(
				#load("local_runner.txt"),
				"// GENERATED_ADAPTER",
				adapter,
			) or_else ""
		write_file(join_path(dir, "runner.odin"), harness) or_return
	}
	if o.json {print_json(struct {
			directory, language: string,
		}{dir, lang})} else {
		fmt.println("Created", dir)
		if lang ==
		   "odin" {fmt.printf("Implement solution.odin, review cases.json, then: leetcode test %s\n", dir)}
	}
	return nil
}

run_local_process :: proc(command: []string, timeout: int) -> (code: int, err: Error) {
	tmp, te := os.make_directory_temp("", "leetcode-process-*", context.allocator)
	if te != nil { return 0, .File }
	defer os.remove_all(tmp)
	out_path, err_path := join_path(tmp, "stdout"), join_path(tmp, "stderr")
	out_file, oe := os.create(out_path)
	err_file, ee := os.create(err_path)
	if oe != nil || ee != nil {
		if out_file != nil { os.close(out_file) }
		if err_file != nil { os.close(err_file) }
		return 0, .File
	}
	environ, _ := os.environ(context.allocator)
	safe_env := make([dynamic]string)
	defer delete(safe_env)
	for item in environ {
		lower := strings.to_lower(item)
		if strings.contains(lower, "token=") || strings.contains(lower, "secret=") ||
		   strings.contains(lower, "password=") || strings.contains(lower, "cookie=") ||
		   strings.contains(lower, "session=") || strings.has_prefix(lower, "leetcode_") || strings.has_prefix(lower, "kattis_") { continue }
		append(&safe_env, item)
	}
	process, pe := os.process_start({command = command, env = safe_env[:], stdout = out_file, stderr = err_file})
	if pe != nil { os.close(out_file); os.close(err_file); fmt.eprintln(os.error_string(pe)); return 0, .File }
	started := time.now()
	output_exceeded := false
	for {
		state, we := os.process_wait(process, 20 * time.Millisecond)
		if we == nil { code = state.exit_code; break }
		if we != .Timeout { _ = os.process_kill(process); _, _ = os.process_wait(process); err = .File; break }
		out_info, _ := os.stat(out_path, context.allocator)
		err_info, _ := os.stat(err_path, context.allocator)
		if out_info.size + err_info.size > 256 * 1024 {
			_ = os.process_kill(process); _, _ = os.process_wait(process); output_exceeded = true; break
		}
		if time.since(started) >= time.Duration(timeout) * time.Second {
			_ = os.process_kill(process); _, _ = os.process_wait(process); err = .Timeout; break
		}
	}
	os.close(out_file); os.close(err_file)
	out, _ := os.read_entire_file_from_path(out_path, context.allocator)
	errout, _ := os.read_entire_file_from_path(err_path, context.allocator)
	if len(out) > 0 { _, _ = os.write(os.stdout, out[:min(len(out), 256*1024)]) }
	if len(errout) > 0 { _, _ = os.write(os.stderr, errout[:min(len(errout), 256*1024)]) }
	delete(out); delete(errout)
	if output_exceeded { return 0, .Output_Limit }
	return
}

cmd_local_test :: proc(o: Options) -> Error {
	dir := o.positionals[0]
	if _, e := os.stat(join_path(dir, "runner.odin"), context.allocator);
	   e != nil {fmt.eprintln("expected an Odin workspace containing runner.odin"); return .File}
	tmp, te := os.make_directory_temp("", "leetcode-local-*", context.allocator)
	if te != nil {return .File}
	defer os.remove_all(tmp)
	binary := join_path(tmp, "solution")
	code := run_local_process({"odin", "build", dir, concat("-out:", binary)}, o.timeout) or_return
	if code != 0 {return .Judge_Failed}
	command := make([dynamic]string)
	defer delete(command)
	append(&command, binary, join_path(dir, "cases.json"))
	if o.json { append(&command, "--json") }
	code = run_local_process(command[:], o.timeout) or_return
	if code == 4 {return .Unchecked}
	if code != 0 {return .Judge_Failed}
	return nil
}
