package leetcode

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import judge ".."

// LeetCode's status_code for a finished, accepted-shaped result.
STATUS_ACCEPTED :: 10

language_extension :: proc(lang: string) -> string {
	switch lang {
	case "odin":                                    return ".odin"
	case "python", "python3", "pythondata":         return ".py"
	case "cpp":                                     return ".cpp"
	case "c":                                       return ".c"
	case "java":                                    return ".java"
	case "rust":                                    return ".rs"
	case "golang":                                  return ".go"
	case "javascript":                              return ".js"
	case "typescript":                              return ".ts"
	case "csharp":                                  return ".cs"
	case "ruby":                                    return ".rb"
	case "swift":                                   return ".swift"
	case "kotlin":                                  return ".kt"
	case "scala":                                   return ".scala"
	case "php":                                     return ".php"
	case "dart":                                    return ".dart"
	case "elixir":                                  return ".ex"
	case "erlang":                                  return ".erl"
	case "racket":                                  return ".rkt"
	case "mysql", "mssql", "oraclesql", "postgresql": return ".sql"
	case "bash":                                    return ".sh"
	}
	return ".txt"
}

// solution_language picks the judge language: --lang when given, otherwise
// the problem's only language whose extension matches the file.
solution_language :: proc(q: json.Value, requested, file: string) -> (lang: string, err: Error) {
	lang = requested
	if lang == "" {
		switch ext := os.ext(file); ext {
		case ".odin":
			lang = "odin"
		case ".py":
			// Prefer current Python when Python 2 and 3 share the extension.
			lang = "python3"
		case:
			for s in jarray(jget(q, "codeSnippets")) {
				candidate := jstr(jget(s, "langSlug"))
				if language_extension(candidate) != ext {
					continue
				}
				if lang != "" {
					fmt.eprintln("ambiguous extension; select --lang")
					return "", .Usage
				}
				lang = candidate
			}
		}
	}
	if lang == "odin" {
		fmt.eprintln("LeetCode does not judge Odin; use `algo judge leetcode test <directory>` for local practice")
		return "", .Unsupported
	}
	for s in jarray(jget(q, "codeSnippets")) {
		if jstr(jget(s, "langSlug")) == lang {
			return lang, nil
		}
	}
	fmt.eprintln("language is unavailable for this problem; use `algo judge leetcode languages <problem>`")
	return "", .Unsupported
}

// Judge ids become URL path segments; accept only plain identifier bytes.
valid_judge_id :: proc(id: string) -> bool {
	if id == "" || id == "." || id == ".." {
		return false
	}
	for c in id {
		switch c {
		case '0' ..= '9', 'a' ..= 'z', 'A' ..= 'Z', '_', '-', '.':
		case:
			return false
		}
	}
	return true
}

poll_judge :: proc(id: string, cfg: Config, timeout: int) -> (result: json.Value, err: Error) {
	if !valid_judge_id(id) {
		return nil, .Usage
	}
	started := time.tick_now()
	for {
		remaining := timeout - int(time.tick_since(started) / time.Second)
		if remaining <= 0 {
			fmt.eprintf("judge still pending; resume with `algo judge leetcode check %s`\n", id)
			return nil, .Timeout
		}
		result = http_request("GET", judge.concat("/submissions/detail/", id, "/check/"), cfg, timeout = min(remaining, 20)) or_return
		switch state := jstr(jget(result, "state")); state {
		case "SUCCESS":
			return result, nil
		case "PENDING", "STARTED":
			time.sleep(500 * time.Millisecond)
		case:
			fmt.eprintln("unknown judge state:", state)
			return nil, .API
		}
	}
}

judge_verdict :: proc(result: json.Value) -> Error {
	if jstr(jget(result, "state")) != "SUCCESS" {
		return .API
	}
	switch jint(jget(result, "status_code")) {
	case 0:
		return .API
	case STATUS_ACCEPTED:
	case:
		return .Judge_Failed
	}
	// A completed example run reports status 10 even when its output is
	// wrong; the comparison result is separate.
	if correct, ok := jget(result, "correct_answer").(bool); ok && !correct {
		return .Judge_Failed
	}
	if jget(result, "total_testcases") != nil && jint(jget(result, "total_correct")) < jint(jget(result, "total_testcases")) {
		return .Judge_Failed
	}
	return nil
}

print_judge :: proc(result: json.Value, as_json: bool) {
	if as_json {
		judge.print_json(result)
		return
	}
	label := jstr(jget(result, "status_msg"))
	if label == "" {
		label = "Finished"
	}
	if judge_verdict(result) == .Judge_Failed && jint(jget(result, "status_code")) == STATUS_ACCEPTED {
		label = "Wrong Answer"
	}
	fmt.printf("%s | runtime: %s | memory: %s\n", label, jstr(jget(result, "status_runtime")), jstr(jget(result, "status_memory")))
	DETAIL_KEYS :: [?]string {
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
	for key in DETAIL_KEYS {
		if v := jget(result, key); v != nil {
			fmt.printf("%s: %s\n", key, jencode(v))
		}
	}
}

Job_Started :: struct {
	job_id:      string,
	state:       string,
	operation:   string,
	problem_key: string,
	language:    string,
}

cmd_judge :: proc(o: Options) -> Error {
	if o.offline {
		fmt.eprintln("judge commands require an online session")
		return .Usage
	}
	cfg := request_credentials(required = true) or_return
	if Command(o.command) == .Check {
		result := poll_judge(o.positionals[0], cfg, o.timeout) or_return
		print_judge(result, o.json)
		return judge_verdict(result)
	}
	if cfg.csrf_token == "" {
		fmt.eprintln("run and submit require csrftoken as well as LEETCODE_SESSION; use `algo judge leetcode paste`")
		return .No_Input
	}

	problem, file := o.positionals[0], o.positionals[1]
	q := get_problem(o, problem) or_return
	lang := solution_language(q, o.lang, file) or_return
	code, read_err := os.read_entire_file(file, context.allocator)
	if read_err != nil {
		fmt.eprintln(file, os.error_string(read_err))
		return .File
	}
	if strings.trim_space(string(code)) == "" {
		return .No_Input
	}

	is_run := Command(o.command) == .Run || Command(o.command) == .Run_Start
	body := jobject()
	body["lang"], body["question_id"], body["typed_code"] = lang, jget(q, "questionId"), string(code)
	if is_run {
		body["data_input"] = example_input(q, o.input) or_return
	}

	slug := jstr(jget(q, "titleSlug"))
	action := "interpret_solution" if is_run else "submit"
	response := http_request("POST", judge.concat("/problems/", slug, "/", action, "/"), cfg, jencode(body)) or_return
	id := judge_job_id(response, is_run)
	if !valid_judge_id(id) || id == "0" {
		report_rejected_job(o, response, id, cfg)
		return .API
	}
	fmt.eprintf("%s queued: %s\n", COMMANDS[Command(o.command)].names[0], id)

	if Command(o.command) == .Run_Start || Command(o.command) == .Submit_Start {
		if o.json {
			judge.print_json(Job_Started{
				job_id      = id,
				state       = "queued",
				operation   = "example_run" if is_run else "submission",
				problem_key = judge.concat("leetcode:", slug),
				language    = lang,
			})
		} else {
			fmt.printf("resume with: algo judge leetcode check %s\n", id)
		}
		return nil
	}
	result := poll_judge(id, cfg, o.timeout) or_return
	print_judge(result, o.json)
	return judge_verdict(result)
}

// example_input is the custom --input file, or every example the problem lists.
example_input :: proc(q: json.Value, input_file: string) -> (input: string, err: Error) {
	if input_file != "" {
		data, read_err := os.read_entire_file(input_file, context.allocator)
		if read_err != nil {
			return "", .File
		}
		input = string(data)
	} else if examples := jarray(jget(q, "exampleTestcaseList")); len(examples) > 0 {
		parts := make([]string, len(examples))
		for v, i in examples {
			parts[i] = jstr(v)
		}
		input = strings.join(parts, "\n")
	} else {
		input = jstr(jget(q, "sampleTestCase"))
	}
	if strings.trim_space(input) == "" {
		return "", .No_Input
	}
	return input, nil
}

// Example runs return a string interpret_id; submissions an integer submission_id.
judge_job_id :: proc(response: json.Value, is_run: bool) -> string {
	value := jget(response, "interpret_id" if is_run else "submission_id")
	if n, ok := value.(json.Integer); ok && n > 0 {
		return fmt.aprintf("%d", n)
	}
	return jstr(value)
}

// report_rejected_job explains a missing job id without echoing credentials.
report_rejected_job :: proc(o: Options, response: json.Value, id: string, cfg: Config) {
	if message := jstr(jget(response, "error")); message != "" {
		message, _ = strings.replace_all(message, cfg.leetcode_session, "[redacted]")
		if cfg.csrf_token != "" {
			message, _ = strings.replace_all(message, cfg.csrf_token, "[redacted]")
		}
		fmt.eprintf("LeetCode rejected %s: %q\n", COMMANDS[Command(o.command)].names[0], message)
		return
	}
	keys := make([dynamic]string)
	if object, ok := response.(json.Object); ok {
		for key in object {
			append(&keys, key)
		}
	}
	fmt.eprintf("judge did not return a valid job ID (ID %q, response fields: %v)\n", id, keys[:])
}
