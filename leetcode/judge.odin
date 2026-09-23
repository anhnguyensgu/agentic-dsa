package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

language_extension :: proc(lang: string) -> string {
	switch lang {
	case "odin":
		return ".odin"
	case "python", "python3", "pythondata":
		return ".py"
	case "cpp":
		return ".cpp"
	case "c":
		return ".c"
	case "java":
		return ".java"
	case "rust":
		return ".rs"
	case "golang":
		return ".go"
	case "javascript":
		return ".js"
	case "typescript":
		return ".ts"
	case "csharp":
		return ".cs"
	case "ruby":
		return ".rb"
	case "swift":
		return ".swift"
	case "kotlin":
		return ".kt"
	case "scala":
		return ".scala"
	case "php":
		return ".php"
	case "dart":
		return ".dart"
	case "elixir":
		return ".ex"
	case "erlang":
		return ".erl"
	case "racket":
		return ".rkt"
	case "mysql", "mssql", "oraclesql", "postgresql":
		return ".sql"
	case "bash":
		return ".sh"
	}
	return ".txt"
}

solution_language :: proc(q: json.Value, requested, file: string) -> (lang: string, err: Error) {
	lang = requested
	if lang == "" {
		ext := os.ext(file)
		// Prefer current Python when both Python 2 and 3 share the extension.
		if ext == ".py" {lang = "python3"} else {
			for s in jarray(jget(q, "codeSnippets")) {
				candidate := jstr(jget(s, "langSlug"))
				if language_extension(candidate) == ext {
					if lang !=
					   "" {fmt.eprintln("ambiguous extension; select --lang"); return "", .Usage}
					lang = candidate
				}
			}
		}
		if ext == ".odin" {lang = "odin"}
	}
	if lang ==
	   "odin" {fmt.eprintln("LeetCode does not judge Odin; use `leetcode test <directory>` for local practice"); return "", .Unsupported}
	for s in jarray(jget(q, "codeSnippets")) {if jstr(jget(s, "langSlug")) == lang {return lang, nil}}
	fmt.eprintln("language is unavailable for this problem; use `leetcode languages <problem>`")
	return "", .Unsupported
}

valid_judge_id :: proc(id: string) -> bool {
	if id == "" || id == "." || id == ".." {return false}
	for c in id {if !(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'z') && !(c >= 'A' && c <= 'Z') && c != '_' && c != '-' && c != '.' {return false}}
	return true
}

poll_judge :: proc(id: string, cfg: Config, timeout: int) -> (result: json.Value, err: Error) {
	if !valid_judge_id(id) {return nil, .Usage}
	started := time.tick_now()
	for {
		remaining := timeout - int(time.tick_since(started) / time.Second)
		if remaining <=
		   0 {fmt.eprintf("judge still pending; resume with `leetcode check %s`\n", id); return nil, .Timeout}
		result = http_request(
			"GET",
			concat("/submissions/detail/", id, "/check/"),
			cfg,
			timeout = min(remaining, 20),
		) or_return
		state := jstr(jget(result, "state"))
		switch state {
		case "SUCCESS":
			return result, nil
		case "PENDING", "STARTED":
		case:
			fmt.eprintln("unknown judge state:", state); return nil, .API
		}
		time.sleep(500 * time.Millisecond)
	}
}

judge_verdict :: proc(result: json.Value) -> Error {
	if jstr(jget(result, "state")) != "SUCCESS" {return .API}
	code := jint(jget(result, "status_code"))
	if code == 0 {return .API}
	if code != 10 {return .Judge_Failed}
	// A completed interpret request can have status_code=10 even when its
	// output is wrong. Inspect the comparison result separately.
	if correct, ok := jget(result, "correct_answer").(bool); ok && !correct {return .Judge_Failed}
	if jget(result, "total_testcases") != nil &&
	   jint(jget(result, "total_correct")) <
		   jint(jget(result, "total_testcases")) {return .Judge_Failed}
	return nil
}

print_judge :: proc(result: json.Value, as_json: bool) {
	if as_json {print_json(result); return}
	label := jstr(jget(result, "status_msg"))
	if label == "" {label = "Finished"}
	if judge_verdict(result) == .Judge_Failed &&
	   jint(jget(result, "status_code")) == 10 {label = "Wrong Answer"}
	fmt.printf(
		"%s | runtime: %s | memory: %s\n",
		label,
		jstr(jget(result, "status_runtime")),
		jstr(jget(result, "status_memory")),
	)
	keys := []string {
		"full_compile_error",
		"compile_error",
		"full_runtime_error",
		"runtime_error",
		"last_testcase",
		"code_answer",
		"expected_code_answer",
		"std_output_list",
		"total_correct",
		"total_testcases",
	}
	for key in keys {
		v := jget(result, key)
		if v != nil {fmt.printf("%s: %s\n", key, jencode(v))}
	}
}

cmd_judge :: proc(o: Options) -> Error {
	if o.offline {fmt.eprintln("judge commands require an online session"); return .Usage}
	cfg := request_credentials(true) or_return
	if o.command == "check" {
		result := poll_judge(o.positionals[0], cfg, o.timeout) or_return
		print_judge(result, o.json)
		return judge_verdict(result)
	}
	if cfg.csrf_token ==
	   "" {fmt.eprintln("run and submit require csrftoken as well as LEETCODE_SESSION; use `leetcode paste`"); return .No_Input}
	q := get_problem(o, o.positionals[0]) or_return
	lang := solution_language(q, o.lang, o.positionals[1]) or_return
	code, fe := os.read_entire_file(o.positionals[1], context.allocator)
	if fe != nil {fmt.eprintln(os.error_string(fe)); return .File}
	if strings.trim_space(string(code)) == "" {return .No_Input}
	body := jobject()
	body["lang"], body["question_id"], body["typed_code"] =
		lang, jget(q, "questionId"), string(code)
	start_only := o.command == "run-start" || o.command == "submit-start"
	action := "submit"
	if o.command == "run" || o.command == "run-start" {
		action = "interpret_solution"
		input := jstr(jget(q, "sampleTestCase"))
		examples := jarray(jget(q, "exampleTestcaseList"))
		if len(examples) > 0 {
			parts := [dynamic]string{}
			for v in examples {append(&parts, jstr(v))}
			input = strings.join(parts[:], "\n")
		}
		if o.input != "" {
			b, e := os.read_entire_file(o.input, context.allocator)
			if e != nil {return .File}
			input = string(b)
		}
		if strings.trim_space(input) == "" {return .No_Input}
		body["data_input"] = input
	}
	slug := jstr(jget(q, "titleSlug"))
	response := http_request(
		"POST",
		concat("/problems/", slug, "/", action, "/"),
		cfg,
		jencode(body),
	) or_return
	id_value := jget(response, "interpret_id")
	if action == "submit" {id_value = jget(response, "submission_id")}
	id := jstr(id_value)
	if n, ok := id_value.(json.Integer); ok && n > 0 {id = fmt.aprintf("%d", n)}
	if !valid_judge_id(id) || id == "0" {
		message := jstr(jget(response, "error"))
		if message != "" {
			message =
				strings.replace_all(
					message,
					cfg.leetcode_session,
					"[redacted]",
				) or_else "request rejected"
			message =
				strings.replace_all(
					message,
					cfg.csrf_token,
					"[redacted]",
				) or_else "request rejected"
			fmt.eprintf("LeetCode rejected %s: %q\n", o.command, message)
		} else {
			keys := [dynamic]string{}
			if object, ok := response.(json.Object); ok {for key in object {append(&keys, key)}}
			fmt.eprintf(
				"judge did not return a valid job ID (ID %q, response fields: %v)\n",
				id,
				keys[:],
			)
		}
		return .API
	}
	fmt.eprintf("%s queued: %s\n", o.command, id)
	if start_only {
		if o.json {
			result := jobject()
			result["job_id"] = id
			result["state"] = "queued"
			result["operation"] = "example_run" if action == "interpret_solution" else "submission"
			result["problem_key"] = concat("leetcode:", slug)
			result["language"] = lang
			print_json(result)
		} else {
			fmt.printf("resume with: leetcode check %s\n", id)
		}
		return nil
	}
	result := poll_judge(id, cfg, o.timeout) or_return
	print_judge(result, o.json)
	return judge_verdict(result)
}
