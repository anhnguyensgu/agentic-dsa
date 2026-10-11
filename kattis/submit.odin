package main

// Submission and verdict polling. GET /submissions/<id>?json returns
// {status_id, testcase_index, row_html, feedback_html} (see kattis-cli).

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "../safeio"

RUNNING_STATUS :: 5
COMPILE_ERROR_STATUS :: 8
ACCEPTED_STATUS :: 16

STATUS_NAMES := [?]string {
	0                    = "New",
	1                    = "New",
	2                    = "Waiting for compile",
	3                    = "Compiling",
	4                    = "Waiting for run",
	RUNNING_STATUS       = "Running",
	6                    = "Judge Error",
	COMPILE_ERROR_STATUS = "Compile Error",
	9                    = "Run Time Error",
	10                   = "Memory Limit Exceeded",
	11                   = "Output Limit Exceeded",
	12                   = "Time Limit Exceeded",
	13                   = "Illegal Function",
	14                   = "Wrong Answer",
	ACCEPTED_STATUS      = "Accepted",
}

POLL_ATTEMPTS :: 60
POLL_INTERVAL :: 2 * time.Second

// Kattis's editor submits JSON (pages/problems/view.js).
Submit_Request :: struct {
	files:     []Submit_File,
	language:  string,
	mainclass: string,
	problem:   string,
}

Submit_File :: struct {
	filename: string,
	code:     string,
	id:       int,
	session:  json.Value, // always null
}

Submission_Status :: struct {
	status_id:      int,
	testcase_index: int,
	row_html:       string,
	feedback_html:  string,
}

Job_Report :: struct {
	schema_version: int,
	provider:       string,
	operation:      string,
	problem_key:    string,
	job_id:         string,
	state:          string,
	language:       string,
}

Check_Report :: struct {
	schema_version: int,
	provider:       string,
	job_id:         string,
	state:          string, // terminal | pending
	verdict:        string,
}

// cmd_submit sends solution (a file, or a directory holding solution.odin).
// Without problem_id the id is the solution's directory name; the structured
// submit-start path always passes an explicit id.
cmd_submit :: proc(solution, lang: string, problem_id := "", start_only := false, as_json := false) -> Error {
	path := join(solution, "solution.odin") if os.is_dir(solution) else solution
	code, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintln("cannot read", path)
		return .File
	}
	id := problem_id if problem_id != "" else os.base(os.dir(path))
	if !valid_problem_id(id) {
		return .Invalid_Problem_Id
	}
	language := lang if lang != "" else language_for_file(path)
	if !session_alive() {
		return .Not_Signed_In
	}

	body, marshal_err := json.marshal(Submit_Request{
		files    = {{filename = os.base(path), code = string(code), id = 1}},
		language = language,
		problem  = id,
	})
	assert(marshal_err == nil)

	// The body contains source code; it goes through a private file next to
	// the session jar rather than argv.
	jar := session_path() or_return
	body_path := strings.concatenate({jar, ".body"})
	if safeio.write_private_file(body_path, body) != nil {
		fmt.eprintln("cannot write the private request body")
		return .File
	}
	defer os.remove(body_path)

	fmt.eprintf("submitting %s to %s (language %s)...\n", path, id, language)
	response := curl(
		"--max-time", "30",
		"-b", jar,
		"-H", "Content-Type: application/json",
		"-H", "Accept: application/json",
		"--data-binary", strings.concatenate({"@", body_path}),
		"--url", fmt.tprintf("%s/problems/%s/submit", BASE_URL, id),
	) or_return
	// Kattis escapes slashes in JSON ("success_url":"\/submissions\/...").
	response, _ = strings.replace_all(strings.trim_space(response), `\/`, "/")
	submission_id := submission_id_from_url(response)
	if submission_id == "" {
		fmt.eprintln("unexpected submit response:")
		fmt.eprintln(response[:min(len(response), 400)])
		return .Submit_Rejected
	}

	fmt.eprintf("queued as submission %s\n", submission_id)
	if !start_only {
		return watch_submission(submission_id)
	}
	if as_json {
		print_json(Job_Report{SCHEMA_VERSION, PROVIDER, "submission", problem_key(id), submission_id, "queued", language})
	} else {
		fmt.printf("resume with: kattis check %s\n", submission_id)
	}
	return nil
}

cmd_check :: proc(submission_id: string, as_json: bool) -> Error {
	if !valid_submission_id(submission_id) {
		return .Invalid_Submission_Id
	}
	verdict, done := poll_submission(submission_id)
	if as_json {
		print_json(Check_Report{SCHEMA_VERSION, PROVIDER, submission_id, "terminal" if done else "pending", verdict})
	} else {
		fmt.println(verdict if verdict != "" else "pending")
	}
	return nil
}

watch_submission :: proc(submission_id: string) -> Error {
	if !valid_submission_id(submission_id) {
		return .Invalid_Submission_Id
	}
	for _ in 0 ..< POLL_ATTEMPTS {
		verdict, done := poll_submission(submission_id)
		if done {
			fmt.println(verdict if verdict != "" else "could not determine the verdict; check the submission page")
			return nil if verdict == STATUS_NAMES[ACCEPTED_STATUS] else .Not_Accepted
		}
		time.sleep(POLL_INTERVAL)
	}
	fmt.println("still judging after the polling window; check the submission page")
	return .Not_Accepted
}

// poll_submission observes a submission once. done is false while judging
// continues or Kattis is unreachable; verdict is empty when unknown.
poll_submission :: proc(submission_id: string) -> (verdict: string, done: bool) {
	url := fmt.tprintf("%s/submissions/%s?json", BASE_URL, submission_id)
	body: string
	status: int
	err: Error
	// Transient connection stalls are common on some networks.
	for attempt in 1 ..= 3 {
		body, status, err = http_get_session(url)
		if err == nil {
			break
		}
		if attempt < 3 {
			time.sleep(POLL_INTERVAL)
		}
	}
	switch {
	case err != nil:
		fmt.eprintln("could not reach Kattis; will keep polling")
		return "", false
	case status == 401:
		return "not signed in (run `kattis auth`)", true
	case status != 200:
		fmt.eprintf("could not fetch the submission status (HTTP %d)\n", status)
		return "", true
	}

	// unmarshal asserts on malformed input, so a truncated body is checked first.
	s: Submission_Status
	if !json.is_valid(transmute([]byte)body, .JSON) || json.unmarshal_string(body, &s, .JSON) != nil {
		fmt.eprintln("could not parse the submission status JSON")
		return "", true
	}
	switch s.status_id {
	case COMPILE_ERROR_STATUS:
		// feedback_html holds the compiler output inside a <pre>.
		if feedback, _ := between(s.feedback_html, "<pre>", "</pre>"); feedback != "" {
			fmt.eprintln(strings.trim_space(feedback))
		}
	case RUNNING_STATUS:
		passed := strings.count(s.row_html, `title="Accepted"`)
		fmt.eprintf("test cases: %d passed (%d judged)\n", passed, s.testcase_index)
	}
	return status_name(s.status_id), s.status_id > RUNNING_STATUS
}

status_name :: proc(id: int) -> string {
	if id >= 0 && id < len(STATUS_NAMES) && STATUS_NAMES[id] != "" {
		return STATUS_NAMES[id]
	}
	return fmt.aprintf("Unknown status %d", id)
}

// Judge-side language names only render for signed-in users; these match
// kattis-cli's mapping. Pass a language explicitly when this guess is wrong.
language_for_file :: proc(path: string) -> string {
	switch strings.to_lower(os.ext(path)) {
	case ".c":          return "C"
	case ".cpp", ".cc": return "C++"
	case ".cs":         return "C#"
	case ".java":       return "Java"
	case ".js":         return "JavaScript (Node.js)"
	case ".ts":         return "TypeScript"
	case ".py":         return "Python 3"
	case ".rs":         return "Rust"
	case ".go":         return "Go"
	}
	return "Odin"
}

// The final redirect after submitting is .../submissions/<id>.
submission_id_from_url :: proc(s: string) -> string {
	MARKER :: "/submissions/"
	i := strings.last_index(s, MARKER)
	if i < 0 {
		return ""
	}
	rest := s[i + len(MARKER):]
	end := 0
	for end < len(rest) && rest[end] >= '0' && rest[end] <= '9' {
		end += 1
	}
	return rest[:end]
}

valid_submission_id :: proc(id: string) -> bool {
	if id == "" {
		return false
	}
	for c in id {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}
