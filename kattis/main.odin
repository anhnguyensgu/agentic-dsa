// kattis-poc: one-file proof of concept for a Kattis practice CLI.
//
// Commands (all in this single file):
//
//     odin run kattis -- list [page]       scrape the open problems table
//     odin run kattis -- search <query>    filter the catalogue by text
//     odin run kattis -- show <id>         statement, difficulty, samples
//     odin run kattis -- get <id>          scaffold problems/<id>/ with samples
//     odin run kattis -- test <dir>        build solution.odin, run samples
//     odin run kattis -- auth <user>       log in (password on stdin), save session
//     odin run kattis -- submit <dir>      submit dir/solution.odin and poll verdict
//     odin run kattis -- watch <subid>     poll a submission's verdict
//
// HTTP goes through curl (same transport pattern as leetcode/api.odin).
// HTML is parsed with plain string scanning: Kattis markup is stable and
// machine-generated, so substring anchors are enough for a POC.
//
// Auth uses Kattis's script login (POST /login with user/password/script=true)
// and stores the sessionid cookie jar at ~/.config/kattis-poc/session (0600),
// mirroring the credentials handling in the leetcode tool. SSO-only accounts
// (GitHub etc.) are out of scope for the POC.
package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

BASE_URL :: #config(KATTIS_BASE_URL, "https://open.kattis.com")
VERSION :: "kattis-odin 0.2.0"

valid_provider_id :: proc(id: string) -> bool {
	if id == "" { return false }
	for c in id {
		if !(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') && c != '-' && c != '_' { return false }
	}
	return true
}

// ---------------------------------------------------------------------------
// session (cookie jar) handling
// ---------------------------------------------------------------------------

session_path :: proc() -> string {
	home := os.get_env_alloc("HOME", context.allocator)
	if home == "" { return "" }
	return fmt.aprintf("%s/.config/kattis-poc/session", home)
}

// curl request with the saved session attached. Returns body and HTTP status
// of the FINAL response (curl follows redirects; -w appends the code).
http_get_session :: proc(url: string, timeout := 30) -> (body: string, status: int, ok: bool) {
	jar := session_path()
	cmd := [14]string{
		"curl", "-q", "-sS", "-L", "-b", jar,
		"--connect-timeout", "10",
		"--max-time", fmt.aprintf("%d", timeout),
		"--url", url,
		"--write-out", "\\n%{http_code} %{url_effective}",
	}
	state, output, stderr, pe := os.process_exec({command = cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		fmt.eprintf("curl failed (exit %d): %s\n", state.exit_code, string(stderr))
		return "", 0, false
	}
	text := string(output)
	i := strings.last_index(text, "\n")
	if i < 0 { return text, 0, false }
	meta := strings.trim_space(text[i + 1:])
	fields := strings.split(meta, " ")
	code := strconv.parse_int(fields[0]) or_else 0
	final_url := fields[len(fields) - 1]
	// A bounce to /login means the session is missing or expired.
	if strings.contains(final_url, "/login") { return "", 401, true }
	return text[:i], code, true
}

// ---------------------------------------------------------------------------
// curl transport
// ---------------------------------------------------------------------------

http_get :: proc(url: string, timeout := 30) -> (body: string, ok: bool) {
	cmd := [13]string {
		"curl",
		"-q",
		"-sS",
		"-L",
		"-4",
		"-A", USER_AGENT,
		"--connect-timeout",
		"10",
		"--max-time",
		fmt.aprintf("%d", timeout),
		"--url",
		url,
	}
	state, output, stderr, pe := os.process_exec({command = cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		fmt.eprintf("curl failed (exit %d): %s\n", state.exit_code, string(stderr))
		return "", false
	}
	return string(output), true
}

// ---------------------------------------------------------------------------
// tiny HTML helpers
// ---------------------------------------------------------------------------

find :: proc(s, needle: string, from := 0) -> int {
	if from > len(s) {return -1}
	return strings.index(s[from:], needle) + from if strings.index(s[from:], needle) >= 0 else -1
}

// between reads the text after `start_marker` up to `end_marker`, starting the
// search at `from`. Returns the slice and the offset just past `end_marker`.
between :: proc(
	s: string,
	start_marker, end_marker: string,
	from := 0,
) -> (
	out: string,
	next: int,
) {
	start := find(s, start_marker, from)
	if start < 0 {return "", -1}
	start += len(start_marker)
	end := find(s, end_marker, start)
	if end < 0 {return "", -1}
	return s[start:end], end + len(end_marker)
}

decode_entities :: proc(s0: string) -> string {
	s := s0
	pairs := [][2]string {
		{"&amp;", "&"},
		{"&lt;", "<"},
		{"&gt;", ">"},
		{"&quot;", "\""},
		{"&#39;", "'"},
		{"&apos;", "'"},
		{"&ndash;", "-"},
		{"&mdash;", "-"},
		{"&nbsp;", " "},
		{"&hellip;", "..."},
	}
	for p in pairs {
		for {
			i := find(s, p[0])
			if i < 0 {break}
			s = strings.concatenate({s[:i], p[1], s[i + len(p[0]):]}) or_else s
		}
	}
	return s
}

// strip_tags removes <...> tags and collapses whitespace runs.
strip_tags :: proc(s: string) -> string {
	b := strings.builder_make()
	in_tag := false
	prev_space := true // leading trim
	for i := 0; i < len(s); i += 1 {
		r := s[i] // bytes preserve UTF-8 sequences; tag anchors are ASCII
		if r == '<' {in_tag = true; continue}
		if r == '>' {in_tag = false; continue}
		if in_tag {continue}
		is_space := r == ' ' || r == '\n' || r == '\t' || r == '\r'
		if is_space {
			if !prev_space {strings.write_byte(&b, ' ')}
			prev_space = true
		} else {
			strings.write_byte(&b, r)
			prev_space = false
		}
	}
	return decode_entities(strings.to_string(b))
}

// ---------------------------------------------------------------------------
// Kattis page parsers
// ---------------------------------------------------------------------------

Problem_Row :: struct {
	id:         string, // URL slug, e.g. "twostones"
	name:       string,
	difficulty: string, // e.g. "7.1 Hard"
	rate:       string, // e.g. "82%"
	subs:       string,
}

parse_problem_list :: proc(html: string) -> []Problem_Row {
	// The problems page has several tables; the catalogue table follows the
	// title_link column header.
	_, p := between(html, `data-name="title_link"`, "<tbody>")
	if p < 0 {return nil}
	end := find(html, "</tbody>", p)
	if end < 0 {return nil}

	rows: [dynamic]Problem_Row
	pos := p
	for pos < end {
		row, next := between(html, "<tr", "</tr>", pos)
		if next < 0 {break}
		pos = next
		if find(row, `/problems/`) < 0 {continue}

		// Cells: name, fastest, submissions, accepted, ?, solve-rate, difficulty, ...
		cells: [dynamic]string
		cpos := 0
		for cpos < len(row) {
			cell, cnext := between(row, "<td", "</td>", cpos)
			if cnext < 0 {break}
			// Drop the tag's attributes: content starts after the closing '>'
			if gt := strings.index(cell, ">"); gt >= 0 {cell = cell[gt + 1:]}
			append(&cells, cell)
			cpos = cnext
		}
		if len(cells) < 7 {continue}

		href, _ := between(cells[0], `href="/problems/`, `"`, 0)
		append(
			&rows,
			Problem_Row {
				id = href,
				name = strip_tags(cells[0]),
				difficulty = strip_tags(cells[6]),
				rate = strip_tags(cells[5]),
				subs = strip_tags(cells[2]),
			},
		)
	}
	return rows[:]
}

Sample :: struct {
	input, output: string,
}

// pre_body strips the newline the markup puts right after `<pre>`:
// Kattis writes `<pre>\n1\n</pre>`, and the leading `\n` is not data.
pre_body :: proc(s: string) -> string {
	return s[1:] if len(s) > 0 && s[0] == '\n' else s
}

parse_samples :: proc(html: string) -> []Sample {
	// Each sample is a `<table class="sample" ...>` holding one
	// Sample Input/Sample Output pair, each value inside a <pre>.
	samples: [dynamic]Sample
	pos := 0
	for {
		tbl, next := between(html, `<table class="sample"`, "</table>", pos)
		if next < 0 {break}
		pos = next
		inp, n := between(tbl, "<pre>", "</pre>", 0)
		if n < 0 {continue}
		outp, _ := between(tbl, "<pre>", "</pre>", n)
		append(&samples, Sample{input = pre_body(inp), output = pre_body(outp)})
	}
	return samples[:]
}

Problem_Page :: struct {
	id:         string,
	title:      string,
	difficulty: string, // e.g. "1.1"
	level:      string, // e.g. "Easy"
	statement:  string, // raw problembody HTML
	samples:    []Sample,
}

parse_problem_page :: proc(id: string, html: string) -> Problem_Page {
	page := Problem_Page {
		id = id,
	}
	if t, _ := between(html, "<title>", "</title>"); t != "" {
		page.title = strip_tags(t)
		// "... &ndash; Kattis, Kattis"
		if i := find(page.title, " Kattis, Kattis");
		   i > 0 {page.title = strings.trim_space(strings.trim_right(page.title[:i], " -"))}
	}
	// Difficulty number: <span class="... difficulty_number-problem_view ...">1.1</span>
	if _, p := between(html, `difficulty_number-problem_view`, ">"); p >= 0 {
		if d, _ := between(html, "", "<", p); d != "" {
			page.difficulty = strip_tags(d)
		}
	}
	// Level word follows the Difficulty label.
	if _, dpos := between(html, `info_label">Difficulty`, "</span>"); dpos >= 0 {
		if lvl, _ := between(html, `text-link">`, "</span>", dpos); lvl != "" {
			page.level = strip_tags(lvl)
		}
	}
	page.statement, _ = between(html, `class="problembody">`, "</div>")
	page.samples = parse_samples(html)
	return page
}

// ---------------------------------------------------------------------------
// commands
// ---------------------------------------------------------------------------

problem_row_json :: proc(row: Problem_Row) -> json.Object {
	o := make(json.Object)
	o["id"], o["name"], o["difficulty"], o["acceptance_rate"], o["submissions"] = row.id, row.name, row.difficulty, row.rate, row.subs
	return o
}

cmd_list :: proc(page_no: int, as_json := false) -> bool {
	body, ok := http_get(fmt.aprintf("%s/problems?page=%d", BASE_URL, page_no))
	if !ok {return false}
	rows := parse_problem_list(body)
	if rows == nil {
		fmt.eprintln("could not parse the problems table; Kattis markup may have changed")
		return false
	}
	items := make(json.Array)
	if !as_json { fmt.printf("%-28s %-42s %-10s %-6s %s\n", "ID", "NAME", "DIFF", "%ACC", "SUBS") }
	for r in rows {
		append(&items, problem_row_json(r))
		name := r.name
		if len(name) > 40 {name = strings.concatenate({name[:37], "..."}) or_else name}
		if !as_json { fmt.printf("%-28s %-42s %-10s %-6s %s\n", r.id, name, r.difficulty, r.rate, r.subs) }
	}
	if as_json {
		report := make(json.Object)
		report["schema_version"], report["provider"], report["page"] = json.Integer(1), "kattis", json.Integer(page_no)
		report["count"], report["problems"] = json.Integer(len(rows)), items
		encoded, _ := json.marshal(report)
		fmt.println(string(encoded))
	} else { fmt.eprintf("%d problems (page %d)\n", len(rows), page_no) }
	return true
}

cmd_show :: proc(id: string, as_json := false) -> bool {
	if !valid_provider_id(id) { fmt.eprintln("invalid problem id"); return false }
	body, ok := http_get(fmt.aprintf("%s/problems/%s", BASE_URL, id))
	if !ok {return false}
	page := parse_problem_page(id, body)
	if as_json {
		report := make(json.Object)
		report["schema_version"], report["provider"] = json.Integer(1), "kattis"
		report["problem_key"] = strings.concatenate({"kattis:", page.id}) or_else ""
		report["id"], report["title"], report["difficulty"], report["level"] = page.id, page.title, page.difficulty, page.level
		report["statement"] = strip_tags(page.statement)
		samples := make(json.Array)
		for sample, i in page.samples {
			item := make(json.Object)
			item["name"], item["input"], item["output"], item["provenance"] = fmt.aprintf("sample%d", i+1), sample.input, sample.output, "official_sample"
			append(&samples, item)
		}
		report["samples"] = samples
		encoded, _ := json.marshal(report)
		fmt.println(string(encoded))
		return true
	}
	fmt.println(page.title)
	fmt.printf("kattis: %s | difficulty: %s (%s)\n\n", page.id, page.difficulty, page.level)
	fmt.println(strip_tags(page.statement))
	fmt.println("---")
	if len(page.samples) == 0 {
		fmt.println("no inline samples found")
	}
	for s, i in page.samples {
		fmt.printf(
			"Sample %d\n> %s\n< %s\n",
			i + 1,
			strings.trim_space(s.input),
			strings.trim_space(s.output),
		)
	}
	return true
}

solution_template :: "# Kattis problem: %s\n# https://open.kattis.com/problems/%s\n\nSolution goes in solution.odin.\n"

odin_template :: `package main

// Kattis entry point: read all of stdin, print the answer to stdout.
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	data, _ := os.read_entire_file(os.stdin, context.allocator)
	input := string(data)
	_ = input

	// TODO: solve the problem. Example helpers:
	//   n, _ := strconv.parse_int(strings.TrimSpace(input))
	//   fmt.println(n * 2)
	fmt.println("change me")
}
`

cmd_get :: proc(id: string, destination := "", as_json := false) -> bool {
	if !valid_provider_id(id) { fmt.eprintln("invalid problem id"); return false }
	dir := destination
	if dir == "" { dir = fmt.aprintf("problems/%s", id) }
	if os.is_directory(dir) || os.is_file(dir) {
		fmt.eprintf("destination exists; refusing to overwrite %s\n", dir)
		return false
	}
	body, ok := http_get(fmt.aprintf("%s/problems/%s", BASE_URL, id))
	if !ok {return false}
	page := parse_problem_page(id, body)

	sdir := fmt.aprintf("%s/samples", dir)
	if e := os.make_directory_all(sdir, os.perm(0o755)); e != nil && e != .Exist {
		fmt.eprintf("mkdir %s failed: %v\n", sdir, e)
		return false
	}
	failed := false
	defer if failed { os.remove_all(dir) }
	if os.write_entire_file(
		   fmt.aprintf("%s/README.md", dir),
		   fmt.aprintf(solution_template, page.title, page.id),
	   ) !=
	   nil {
		fmt.eprintln("failed to write files"); failed = true; return false
	}
	if os.write_entire_file(
		fmt.aprintf("%s/statement.txt", dir),
		strings.concatenate({strip_tags(page.statement), "\n"}) or_else "",
	) != nil { fmt.eprintln("failed to write statement"); failed = true; return false }
	if os.write_entire_file(fmt.aprintf("%s/solution.odin", dir), odin_template) != nil { fmt.eprintln("failed to write solution"); failed = true; return false }
	for s, i in page.samples {
		if os.write_entire_file(fmt.aprintf("%s/sample%d.in", sdir, i + 1), s.input) != nil ||
		   os.write_entire_file(fmt.aprintf("%s/sample%d.out", sdir, i + 1), s.output) != nil {
			fmt.eprintln("failed to write samples"); failed = true; return false
		}
	}
	if as_json {
		report := make(json.Object)
		report["schema_version"], report["provider"], report["problem_key"] = json.Integer(1), "kattis", strings.concatenate({"kattis:", id}) or_else ""
		report["directory"], report["language"], report["sample_count"] = dir, "odin", json.Integer(len(page.samples))
		encoded, _ := json.marshal(report)
		fmt.println(string(encoded))
		return true
	}
	fmt.printf(
		"created %s (%s, difficulty %s %s), %d samples\n",
		dir,
		page.title,
		page.difficulty,
		page.level,
		len(page.samples),
	)
	fmt.printf("next: edit %s/solution.odin, then: odin run kattis -- test %s\n", dir, dir)
	return true
}

// trim_output normalizes for comparison: strip \r, trailing spaces per line,
// and trailing empty lines.
trim_output :: proc(s0: string) -> string {
	s := strings.replace_all(s0, "\r", "", context.allocator) or_else s0
	return strings.trim_right(s, " \t\n")
}

KATTIS_RUN_OUTPUT_LIMIT :: 256 * 1024

Bounded_Result :: struct {
	exit_code: int,
	stdout: string,
	stderr: string,
	timed_out: bool,
	output_exceeded: bool,
	start_failed: bool,
}

safe_child_environment :: proc() -> []string {
	env, err := os.environ(context.allocator)
	if err != nil { return nil }
	out := make([dynamic]string)
	for item in env {
		lower := strings.to_lower(item)
		if strings.contains(lower, "token=") || strings.contains(lower, "secret=") ||
		   strings.contains(lower, "password=") || strings.contains(lower, "cookie=") ||
		   strings.contains(lower, "session=") || strings.has_prefix(lower, "kattis_") ||
		   strings.has_prefix(lower, "leetcode_") { continue }
		append(&out, item)
	}
	return out[:]
}

exec_bounded :: proc(command: []string, stdin: ^os.File = nil, timeout_seconds := 10) -> Bounded_Result {
	result: Bounded_Result
	tmp, err := os.make_directory_temp("", "kattis-run-*", context.allocator)
	if err != nil { result.start_failed = true; return result }
	defer os.remove_all(tmp)
	out_path := fmt.aprintf("%s/stdout", tmp)
	err_path := fmt.aprintf("%s/stderr", tmp)
	out_file, oe := os.create(out_path)
	err_file, ee := os.create(err_path)
	if oe != nil || ee != nil {
		if out_file != nil { os.close(out_file) }
		if err_file != nil { os.close(err_file) }
		result.start_failed = true
		return result
	}
	env := safe_child_environment()
	defer delete(env)
	process, pe := os.process_start({command = command, env = env, stdin = stdin, stdout = out_file, stderr = err_file})
	if pe != nil { os.close(out_file); os.close(err_file); result.start_failed = true; return result }
	started := time.now()
	for {
		state, wait_err := os.process_wait(process, 20 * time.Millisecond)
		if wait_err == nil { result.exit_code = state.exit_code; break }
		if wait_err != .Timeout { _ = os.process_kill(process); _, _ = os.process_wait(process); result.start_failed = true; break }
		out_info, _ := os.stat(out_path, context.allocator)
		err_info, _ := os.stat(err_path, context.allocator)
		if out_info.size + err_info.size > KATTIS_RUN_OUTPUT_LIMIT {
			_ = os.process_kill(process); _, _ = os.process_wait(process); result.output_exceeded = true; break
		}
		if time.since(started) >= time.Duration(timeout_seconds) * time.Second {
			_ = os.process_kill(process); _, _ = os.process_wait(process); result.timed_out = true; break
		}
	}
	os.close(out_file); os.close(err_file)
	out, _ := os.read_entire_file_from_path(out_path, context.allocator)
	errout, _ := os.read_entire_file_from_path(err_path, context.allocator)
	result.stdout = strings.clone(string(out[:min(len(out), KATTIS_RUN_OUTPUT_LIMIT)]))
	result.stderr = strings.clone(string(errout[:min(len(errout), KATTIS_RUN_OUTPUT_LIMIT)]))
	delete(out); delete(errout)
	return result
}

cmd_test :: proc(dir: string, as_json := false) -> bool {
	solution := fmt.aprintf("%s/solution.odin", dir)
	if _, e := os.stat(solution, context.allocator); e != nil {
		fmt.eprintf("no solution at %s\n", solution)
		return false
	}
	bin := fmt.aprintf("%s/solution", dir)
	build := [6]string{"odin", "build", solution, "-file", "-o:speed", fmt.aprintf("-out:%s", bin)}
	build_result := exec_bounded(build[:], nil, 30)
	if build_result.start_failed || build_result.timed_out || build_result.output_exceeded || build_result.exit_code != 0 {
		if as_json {
			report := make(json.Object)
			report["schema_version"], report["outcome"] = json.Integer(1), "compile_error"
			report["diagnostic"] = build_result.stderr
			report["timed_out"], report["output_limit_exceeded"] = build_result.timed_out, build_result.output_exceeded
			encoded, _ := json.marshal(report)
			fmt.println(string(encoded))
		} else {
			fmt.eprintln("build failed:")
			fmt.eprintln(build_result.stderr)
		}
		return false
	}

	// Collect sample inputs.
	sdir := fmt.aprintf("%s/samples", dir)
	listing, le := os.read_all_directory_by_path(sdir, context.allocator)
	if le != nil {
		fmt.eprintf("cannot list %s: run `get` first\n", sdir)
		return false
	}
	passed, total, unchecked := 0, 0, 0
	results := make(json.Array)
	for f in listing {
		if !strings.has_suffix(f.name, ".in") {continue}
		total += 1
		base := strings.trim_suffix(f.name, ".in")
		in_path := fmt.aprintf("%s/%s", sdir, f.name)
		out_path := fmt.aprintf("%s/%s.out", sdir, base)
		expected, e2 := os.read_entire_file_from_path(out_path, context.allocator)
		if e2 != nil {
			if !as_json { fmt.eprintf("%s: missing expected file %s\n", base, out_path) }
			unchecked += 1
			item := make(json.Object)
			item["name"], item["verified"], item["passed"] = base, false, false
			item["provenance"], item["comparator"] = "missing_expected_output", "trimmed"
			append(&results, item)
			continue
		}
		in_file, oe := os.open(in_path)
		if oe != nil {
			fmt.eprintf("%s: cannot open input\n", base)
			continue
		}
		run_result := exec_bounded({bin}, in_file, 10)
		os.close(in_file)
		if run_result.start_failed || run_result.timed_out || run_result.output_exceeded || run_result.exit_code != 0 {
			if !as_json { fmt.eprintf(
				"%s: runtime error (exit %d) %s\n",
				base,
				run_result.exit_code,
				run_result.stderr,
			) }
			item := make(json.Object)
			item["name"], item["verified"], item["passed"] = base, true, false
			item["runtime_error"] = run_result.stderr
			item["timed_out"], item["output_limit_exceeded"] = run_result.timed_out, run_result.output_exceeded
			append(&results, item)
			continue
		}
		case_passed := trim_output(run_result.stdout) == trim_output(string(expected))
		item := make(json.Object)
		item["name"], item["verified"], item["passed"] = base, true, case_passed
		item["actual"], item["expected"] = run_result.stdout, string(expected)
		item["provenance"], item["comparator"] = "official_sample", "trimmed"
		append(&results, item)
		if case_passed {
			if !as_json { fmt.printf("%s: PASS\n", base) }
			passed += 1
		} else {
			if !as_json { fmt.printf(
				"%s: FAIL\n  want: %q\n  got:  %q\n",
				base,
				strings.trim_space(string(expected)),
				strings.trim_space(run_result.stdout),
			) }
		}
	}
	if as_json {
		report := make(json.Object)
		outcome := "passed"
		if passed < total - unchecked { outcome = "failed" } else if unchecked > 0 || total == 0 { outcome = "unverified" }
		report["schema_version"], report["outcome"] = json.Integer(1), outcome
		report["verified_passed"], report["verified_failed"], report["unchecked"] = json.Integer(passed), json.Integer(total-unchecked-passed), json.Integer(unchecked)
		report["cases"] = results
		encoded, _ := json.marshal(report)
		fmt.println(string(encoded))
	} else {
		fmt.eprintf("%d/%d samples passed\n", passed, total)
	}
	return passed == total && total > 0 && unchecked == 0
}

// Minimal query-string encoder: alphanumerics and a few safe punctuation
// pass through, everything else becomes %XX (Kattis accepts '+' for space).
urlencode :: proc(s: string) -> string {
	b := strings.builder_make()
	for i := 0; i < len(s); i += 1 {
		c := s[i]
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
			c == '-' || c == '_' || c == '.' || c == '~' {
			strings.write_byte(&b, c)
		} else if c == ' ' {
			strings.write_string(&b, "+")
		} else {
			strings.write_string(&b, fmt.aprintf("%%%02X", c))
		}
	}
	return strings.to_string(b)
}

cmd_search :: proc(query: string, page_no: int, as_json := false) -> bool {
	// NOTE: /problems?q= ignores text queries; the catalogue's real text
	// search is the global /search endpoint, which returns id+name only.
	_ = page_no
	body, ok := http_get(fmt.aprintf("%s/search?q=%s", BASE_URL, urlencode(query)))
	if !ok { return false }

	// Results live in a table under the "Problems" heading:
	// <td><a href="/problems/<id>">id</a></td><td>Name</td>
	_, pos := between(body, ">Problems</h2>", "<table", 0)
	if pos < 0 {
		if as_json { fmt.println(`{"schema_version":1,"provider":"kattis","count":0,"problems":[]}`) } else { fmt.println("no matches") }
		return true
	}
	end := find(body, "</table>", pos)
	if !as_json { fmt.printf("%-28s %s\n", "ID", "NAME") }
	items := make(json.Array)
	count := 0
	for pos >= 0 && pos < end {
		cell, next := between(body, "<td", "</td>", pos)
		if next < 0 { break }
		pos = next
		if gt := strings.index(cell, ">"); gt >= 0 { cell = cell[gt + 1:] }
		href, _ := between(cell, `href="/problems/`, `"`, 0)
		if href == "" { continue }
		name, npos := between(body, "<td", "</td>", pos)
		if npos < 0 { break }
		pos = npos
		if gt := strings.index(name, ">"); gt >= 0 { name = name[gt + 1:] }
		clean_name := strip_tags(name)
		if as_json {
			item := make(json.Object)
			item["id"], item["name"], item["problem_key"] = href, clean_name, strings.concatenate({"kattis:", href}) or_else ""
			append(&items, item)
		} else { fmt.printf("%-28s %s\n", href, clean_name) }
		count += 1
	}
	if as_json {
		report := make(json.Object)
		report["schema_version"], report["provider"], report["query"] = json.Integer(1), "kattis", query
		report["count"], report["problems"] = json.Integer(count), items
		encoded, _ := json.marshal(report)
		fmt.println(string(encoded))
	} else { fmt.eprintf("%d problems matching %q\n", count, query) }
	return true
}

// ---------------------------------------------------------------------------
// auth: script login, session saved as a curl cookie jar
// ---------------------------------------------------------------------------

cmd_auth :: proc(user: string) -> bool {
	password, _ := os.read_entire_file(os.stdin, context.allocator)
	password_str := strings.trim_space(string(password))
	if password_str == "" {
		fmt.eprintln("no password on stdin (echo <password> | odin run kattis -- auth <user>)")
		return false
	}

	// Mirror the browser's "Log in with e-mail" flow exactly:
	//   1. GET  /login/email — sets the session cookie, hands out a csrf_token
	//   2. POST user/password/csrf_token back to /login/email
	// The old /login?script=true endpoint expects an API token, NOT the UI
	// password, which is why it reports "Incorrect username or password/token".
	jar := session_path()
	if jar == "" { fmt.eprintln("cannot resolve HOME"); return false }
	if e := os.make_directory_all(os.dir(jar), os.perm(0o700)); e != nil && e != .Exist {
		fmt.eprintf("cannot create %s: %v\n", os.dir(jar), e)
		return false
	}

	// Step 1: fetch the form and save the tied cookie.
	get_cmd := [14]string{
		"curl", "-q", "-sS", "-4", "--connect-timeout", "10", "--max-time", "45",
		"-A", USER_AGENT,
		"-c", jar, "--url", fmt.aprintf("%s/login/email", BASE_URL),
	}
	state, output, stderr, pe := os.process_exec({command = get_cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		fmt.eprintf("could not load the login form: %s\n", string(stderr))
		return false
	}
	csrf, _ := between(string(output), `name="csrf_token" value="`, `"`)
	if csrf == "" {
		fmt.eprintln("could not find csrf token in the login form; Kattis markup may have changed")
		return false
	}

	// Step 2: post credentials. The password travels via a 0600 temp file
	// (curl's name@file form of --data-urlencode) so it never appears in
	// argv, the shell history, or an unencoded URL body.
	creds_path := fmt.aprintf("%s.creds", jar)
	if os.write_entire_file(creds_path, password_str) != nil {
		fmt.eprintln("cannot write credential temp file")
		return false
	}
	defer os.remove(creds_path)

	// Retries: Cloudflare sometimes stalls POSTs (silent drop, HTTP/2 or IPv6
	// path issues). -A looks like a real client, -4 avoids IPv6 black holes,
	// and up to three attempts ride out transient stalls.
	post_cmd := [24]string{
		"curl", "-q", "-sS", "-4", "--connect-timeout", "10", "--max-time", "45",
		"-A", USER_AGENT,
		"-b", jar, "-c", jar,
		"--data-urlencode", fmt.aprintf("user=%s", user),
		"--data-urlencode", fmt.aprintf("password@%s", creds_path),
		"--data-urlencode", fmt.aprintf("csrf_token=%s", csrf),
		"--url", fmt.aprintf("%s/login/email", BASE_URL),
		"--write-out", "\\n%{http_code}",
	}
	text := ""
	for attempt := 1; attempt <= 3; attempt += 1 {
		state, output, stderr, pe = os.process_exec({command = post_cmd[:]}, context.allocator)
		if pe == nil && state.exit_code == 0 {
			text = string(output)
			break
		}
		if attempt < 3 {
			fmt.eprintf("login post attempt %d failed (%s); retrying...\n", attempt, strings.trim_space(string(stderr)))
			time.sleep(time.Second * 2)
		} else {
			fmt.eprintf("login request failed after 3 attempts: %s\n", strings.trim_space(string(stderr)))
			return false
		}
	}
	// Split the HTTP status curl appends after the body.
	li := strings.last_index(text, "\n")
	body := strings.trim_space(text[:max(li, 0)])
	login_status := strconv.parse_int(strings.trim_space(text[li + 1:])) or_else 0
	if login_status == 200 && strings.contains(body, "Unknown Username/Password") {
		fmt.eprintln("login failed: unknown username or password")
		fmt.eprintln("check: the same pair must work via 'Log in with e-mail' in the browser")
		return false
	}
	if login_status < 300 || login_status >= 400 { // success is a 30x redirect
		fmt.eprintln("login failed: Kattis did not redirect after the form post")
		fmt.eprintln(body[:min(len(body), 300)])
		return false
	}

	// Follow the post-login redirect once so the session is fully established
	// and every Set-Cookie on the way is captured into the jar.
	final_cmd := [13]string{
		"curl", "-q", "-sS", "-L", "-4", "-A", USER_AGENT,
		"-b", jar, "-c", jar,
		"--url", fmt.aprintf("%s/", BASE_URL),
	}
	state, output, stderr, pe = os.process_exec({command = final_cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		fmt.eprintf("could not finish the login redirect: %s\n", string(stderr))
		return false
	}

	// Step 3: verify the session really works (homepage probe).
	if !session_alive() {
		fmt.eprintln("session saved but Kattis did not accept it; the homepage still shows a Log in link")
		fmt.eprintln("fallback: if this persists, this network/IP is likely being blocked — try a different network")
		return false
	}
	fmt.printf("signed in as %s; session saved at %s\n", user, jar)
	return true
}

// Real-browser UA: Kattis/Cloudflare get suspicious of `(compatible; ...)`
// bot-pattern agents in some regions (silent stalls, 403s).
USER_AGENT :: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

// Probe login state via the homepage: anonymous pages carry a "Log in" link,
// signed-in pages show the username instead.
session_alive :: proc() -> bool {
	body, status, ok := http_get_session(fmt.aprintf("%s/", BASE_URL))
	if !ok || status != 200 { return false }
	return !strings.contains(body, `href="/login"`)
}

// ---------------------------------------------------------------------------
// submit + verdict polling — official ?json protocol (see kattis-cli's
// show_judgement): GET /submissions/<id>?json returns {status_id,
// testcase_index, row_html, feedback_html}.
// ---------------------------------------------------------------------------

RUNNING_STATUS :: 5
COMPILE_ERROR_STATUS :: 8
ACCEPTED_STATUS :: 16

status_name :: proc(id: int) -> string {
	s := ""
	switch id {
	case 0, 1: s = "New"
	case 2: s = "Waiting for compile"
	case 3: s = "Compiling"
	case 4: s = "Waiting for run"
	case RUNNING_STATUS: s = "Running"
	case 6: s = "Judge Error"
	case COMPILE_ERROR_STATUS: s = "Compile Error"
	case 9: s = "Run Time Error"
	case 10: s = "Memory Limit Exceeded"
	case 11: s = "Output Limit Exceeded"
	case 12: s = "Time Limit Exceeded"
	case 13: s = "Illegal Function"
	case 14: s = "Wrong Answer"
	case ACCEPTED_STATUS: s = "Accepted"
	case: s = fmt.aprintf("Unknown status %d", id)
	}
	return s
}

jget :: proc(v: json.Value, key: string) -> json.Value {
	o := v.(json.Object) or_else nil
	return o[key]
}
jint :: proc(v: json.Value) -> int {
	#partial switch n in v {
	case json.Integer: return int(n)
	case json.Float: return int(n)
	}
	return 0
}
jstr :: proc(v: json.Value) -> string { return v.(string) or_else "" }

poll_submission :: proc(subid: string) -> (verdict: string, done: bool) {
	// Transient stalls (SSL/connection timeouts) are common on some networks;
	// retry the fetch before giving up.
	body := ""
	status := 0
	ok := false
	for attempt := 1; attempt <= 3; attempt += 1 {
		body, status, ok = http_get_session(fmt.aprintf("%s/submissions/%s?json", BASE_URL, subid))
		if ok { break }
		if attempt < 3 { time.sleep(time.Second * 2) }
	}
	if status == 0 {
		fmt.eprintln("could not reach Kattis (connection failures); will keep polling")
		return "", false
	}
	if status != 200 && status != 401 {
		fmt.eprintf("could not fetch submission status (HTTP %d)\n", status)
		return "", true
	}
	if status == 401 {
		return "not signed in (run `auth`)", true
	}
	v, perr := json.parse_string(body)
	if perr != nil {
		fmt.eprintln("could not parse the submission status JSON")
		return "", true
	}
	status_id := jint(jget(v, "status_id"))
	verdict = status_name(status_id)

	if status_id == COMPILE_ERROR_STATUS {
		// feedback_html holds the compiler output inside a <pre>.
		feedback, _ := between(jstr(jget(v, "feedback_html")), "<pre>", "</pre>")
		if feedback != "" { fmt.eprintln(strings.trim_space(feedback)) }
	}
	if status_id == RUNNING_STATUS {
		// Per-testcase progress: done count from the payload, accepted icons
		// from row_html.
		done_n := jint(jget(v, "testcase_index"))
		row := jstr(jget(v, "row_html"))
		passed := strings.count(row, `title="Accepted"`)
		fmt.eprintf("test cases: %d passed (%d judged)\n", passed, done_n)
	}
	return verdict, status_id > RUNNING_STATUS
}

watch_submission :: proc(subid: string, attempts := 60) -> string {
	for i := 0; i < attempts; i += 1 {
		verdict, done := poll_submission(subid)
		if done {
			fmt.println(verdict == "" ? "could not determine verdict; check the page" : verdict)
			return verdict
		}
		if verdict == "" { verdict = "waiting..." }
		time.sleep(time.Second * 2)
	}
	fmt.println("still judging after polling window; check the submission page")
	return ""
}

language_for_file :: proc(path: string) -> string {
	ext := strings.to_lower(os.ext(path))
	switch ext {
		// NOTE: judge-side select values only render for logged-in users;
		// these match kattis-cli's mapping. Override with --lang if wrong.
		case ".c": return "C"
		case ".cpp", ".cc": return "C++"
		case ".cs": return "C#"
		case ".java": return "Java"
		case ".js": return "JavaScript (Node.js)"
		case ".ts": return "TypeScript"
		case ".py": return "Python 3"
		case ".rs": return "Rust"
		case ".go": return "Go"
		case: return "Odin" // .odin and anything else
	}
	return "Odin"
}

// Extract the submission id from the final URL curl reports after following
// the post-submit redirect: .../submissions/<id>.
subid_from_url :: proc(url: string) -> string {
	marker := "/submissions/"
	i := strings.last_index(url, marker)
	if i < 0 { return "" }
	rest := url[i + len(marker):]
	end := len(rest)
	for j := 0; j < len(rest); j += 1 {
		c := rest[j]
		if c < '0' || c > '9' { end = j; break }
	}
	return rest[:end]
}

// json_escape makes a source string safe inside a JSON string literal.
json_escape :: proc(s: string) -> string {
	b := strings.builder_make()
	for i := 0; i < len(s); i += 1 {
		c := s[i]
		switch c {
		case '"':  strings.write_string(&b, "\\\"")
		case '\\': strings.write_string(&b, "\\\\")
		case '\n': strings.write_string(&b, "\\n")
		case '\r': strings.write_string(&b, "\\r")
		case '\t': strings.write_string(&b, "\\t")
		case:
			if c < 32 {
				strings.write_string(&b, fmt.aprintf("\\u%04x", c))
			} else {
				strings.write_byte(&b, c)
			}
		}
	}
	return strings.to_string(b)
}

cmd_submit :: proc(dir: string, lang_override := "", explicit_id := "", start_only := false, json_output := false) -> bool {
	solution := dir
	if os.is_dir(dir) {
		solution = fmt.aprintf("%s/solution.odin", dir)
	}
	if _, e := os.stat(solution, context.allocator); e != nil {
		fmt.eprintf("no solution at %s\n", solution)
		return false
	}
	// Legacy submit infers the id for compatibility. The structured
	// submit-start path always supplies and validates an explicit problem id.
	id := explicit_id
	if id == "" { id = os.base(os.dir(solution)) }
	if !valid_provider_id(id) { fmt.eprintln("invalid problem id"); return false }
	lang := lang_override == "" ? language_for_file(solution) : lang_override
	if !session_alive() {
		fmt.eprintln("not signed in or session expired: run `auth <user>` first (password on stdin)")
		return false
	}
	jar := session_path()

	code, ce := os.read_entire_file_from_path(solution, context.allocator)
	if ce != nil {
		fmt.eprintf("cannot read %s\n", solution)
		return false
	}

	// Kattis's editor submits via JSON (see pages/problems/view.js):
	// {files: [{filename, code, id, session: null}], language, mainclass, problem}
	// NOTE: fmt.aprintf cannot be used for the template — Odin's fmt treats
	// '{' as a placeholder — so the JSON is built by concatenation.
	esc_name := json_escape(os.base(solution))
	esc_code := json_escape(string(code))
	parts := []string{
		`{"files":[{"filename":"`, esc_name,
		`","code":"`, esc_code,
		`","id":1,"session":null}],"language":"`,
		lang,
		`","mainclass":"","problem":"`,
		id,
		`"}`,
	}
	body, jerr := strings.concatenate(parts)
	if jerr != nil {
		fmt.eprintln("cannot assemble request body")
		return false
	}

	fmt.eprintf("submitting %s to %s (language %s)...\n", solution, id, lang)
	// Body goes through a private temp file; credentials-shaped data never
	// becomes a shell argument.
	body_path := fmt.aprintf("%s.body", jar)
	if os.write_entire_file(body_path, body) != nil {
		fmt.eprintln("cannot write request body temp file")
		return false
	}
	defer os.remove(body_path)
	cmd := [20]string{
		"curl", "-q", "-sS", "-4", "-A", USER_AGENT, "-b", jar,
		"--connect-timeout", "10", "--max-time", "30",
		"-H", "Content-Type: application/json",
		"-H", "Accept: application/json",
		"--data-binary", fmt.aprintf("@%s", body_path),
		"--url", fmt.aprintf("%s/problems/%s/submit", BASE_URL, id),
	}
	state, output, stderr, pe := os.process_exec({command = cmd[:]}, context.allocator)
	if pe != nil || state.exit_code != 0 {
		fmt.eprintf("submit request failed: %s\n", string(stderr))
		return false
	}
	response := strings.trim_space(string(output))
	// Kattis escapes slashes in JSON ("success_url":"\/submissions\/...");
	// normalize before matching.
	response = strings.replace_all(response, `\/`, "/", context.allocator) or_else response
	subid := subid_from_url(response)
	if subid == "" {
		if strings.contains(response, `"success":false`) {
			fmt.eprintln("submit rejected; Kattis said:")
		} else {
			fmt.eprintln("unexpected submit response:")
		}
		fmt.eprintln(response[:min(len(response), 400)])
		return false
	}
	fmt.eprintf("queued as submission %s\n", subid)
	if start_only {
		if json_output {
			out := make(json.Object)
			out["schema_version"] = json.Integer(1)
			out["provider"], out["operation"] = "kattis", "submission"
			out["problem_key"] = strings.concatenate({"kattis:", id}) or_else ""
			out["job_id"], out["state"], out["language"] = subid, "queued", lang
			encoded, _ := json.marshal(out)
			fmt.println(string(encoded))
		} else {
			fmt.printf("resume with: kattis-poc check %s\n", subid)
		}
		return true
	}
	verdict := watch_submission(subid)
	return verdict == "Accepted"
}

// ---------------------------------------------------------------------------
// entry point
// ---------------------------------------------------------------------------

print_usage :: proc() {
	fmt.println(
		`usage: kattis-poc <command>

commands:

  help | version        normal help and machine-compatible version output
  capabilities          JSON provider capability contract
  list [page]           list open problems (default page 0)
  search <query> [page] filter the catalogue by text
  show <id>             print statement, difficulty, and samples
  get <id>              scaffold problems/<id>/ with samples + solution.odin
  test <dir>            build solution.odin and check all local samples
  auth <user>           log in; password arrives on stdin
  submit <dir> [lang]   submit dir/solution.odin, poll the verdict
  submit-start <problem-id> <file> [lang] [--json]
                        submit once and return a durable job id
  check <subid> [--json]
                        observe an existing submission once
  watch <subid>         poll an existing submission's verdict`,
	)
}

main :: proc() {
	args := os.args[1:]
	if len(args) == 0 {print_usage(); os.exit(1)}
	ok := false
	switch args[0] {
	case "help", "--help", "-h":
		if len(args) != 1 { fmt.eprintln("help takes no arguments") } else { print_usage(); ok = true }
	case "version", "--version":
		if len(args) != 1 { fmt.eprintln("version takes no arguments") } else { fmt.println(VERSION); ok = true }
	case "capabilities":
		if len(args) > 2 || (len(args) == 2 && args[1] != "--json") {
			fmt.eprintln("usage: capabilities [--json]")
		} else {
			fmt.println(`{"schema_version":1,"provider":"kattis","version":"kattis-odin 0.2.0","structured":true,"local_test":{"implemented":true,"languages":["odin"],"json_report":true},"problem_search":{"implemented":true},"problem_get":{"implemented":true},"attempt_create":{"fresh_destination":true},"submission":{"prepare_send_check":true,"explicit_problem_id":true}}`)
			ok = true
		}
	case "list":
		page, as_json, valid := 0, false, true
		for arg in args[1:] {
			if arg == "--json" { as_json = true }
			else if value, parsed := strconv.parse_int(arg); parsed && value >= 0 { page = value }
			else { valid = false }
		}
		if len(args) > 3 || !valid { fmt.eprintln("usage: list [page] [--json]") } else { ok = cmd_list(page, as_json) }
	case "search":
		if len(args) < 2 || len(args) > 4 {
			fmt.eprintln("usage: search <query> [page] [--json]")
		} else {
			page, as_json, valid := 0, false, true
			for arg in args[2:] {
				if arg == "--json" { as_json = true }
				else if value, parsed := strconv.parse_int(arg); parsed && value >= 0 { page = value }
				else { valid = false }
			}
			if !valid { fmt.eprintln("usage: search <query> [page] [--json]") } else { ok = cmd_search(args[1], page, as_json) }
		}
	case "show":
		if len(args) < 2 || len(args) > 3 || (len(args) == 3 && args[2] != "--json") {fmt.eprintln("usage: show <id> [--json]")} else {ok = cmd_show(args[1], len(args) == 3)}
	case "get":
		if len(args) < 2 || len(args) > 5 {
			fmt.eprintln("usage: get <id> [--dir path] [--json]")
		} else {
			destination, as_json, valid := "", false, true
			for i := 2; i < len(args); i += 1 {
				if args[i] == "--json" { as_json = true }
				else if args[i] == "--dir" && i + 1 < len(args) { i += 1; destination = args[i] }
				else { valid = false }
			}
			if !valid { fmt.eprintln("usage: get <id> [--dir path] [--json]") } else { ok = cmd_get(args[1], destination, as_json) }
		}
	case "test":
		if len(args) < 2 || len(args) > 3 || (len(args) == 3 && args[2] != "--json") {
			fmt.eprintln("usage: test <dir> [--json]")
		} else {ok = cmd_test(args[1], len(args) == 3)}
	case "auth":
		if len(args) < 2 {
			fmt.eprintln("usage: auth <user>; password on stdin")
		} else {
			ok = cmd_auth(args[1])
		}
	case "submit":
		if len(args) < 2 {
			fmt.eprintln("usage: submit <dir> [language]")
		} else {
			lang := ""
			if len(args) > 2 {lang = args[2]}
			ok = cmd_submit(args[1], lang)
		}
	case "submit-start":
		if len(args) < 3 || len(args) > 5 {
			fmt.eprintln("usage: submit-start <problem-id> <file> [language] [--json]")
		} else {
			lang, as_json := "", false
			for arg in args[3:] {
				if arg == "--json" { as_json = true } else if lang == "" { lang = arg } else { fmt.eprintln("unexpected argument"); os.exit(2) }
			}
			ok = cmd_submit(args[2], lang, args[1], true, as_json)
		}
	case "check":
		if len(args) < 2 || len(args) > 3 || (len(args) == 3 && args[2] != "--json") {
			fmt.eprintln("usage: check <subid> [--json]")
		} else {
			verdict, done := poll_submission(args[1])
			if len(args) == 3 {
				state := "terminal" if done else "pending"
				out := make(json.Object)
				out["schema_version"] = json.Integer(1)
				out["provider"], out["job_id"], out["state"], out["verdict"] = "kattis", args[1], state, verdict
				encoded, _ := json.marshal(out)
				fmt.println(string(encoded))
			} else {
				fmt.println(verdict if verdict != "" else "pending")
			}
			ok = true
		}
	case "watch":
		if len(args) < 2 {
			fmt.eprintln("usage: watch <subid>")
		} else {
			ok = watch_submission(args[1]) == "Accepted"
		}
	case:
		fmt.eprintf("unknown command %q\n\n", args[0])
		print_usage()
	}
	os.exit(0 if ok else 1)
}
