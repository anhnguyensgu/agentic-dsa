package kattis

import judge ".."
import "core:fmt"
import "core:os"
import "core:strings"

SCHEMA_VERSION :: 1
PROVIDER :: "kattis"

List_Report :: struct {
	schema_version: int,
	provider:       string,
	page:           int,
	count:          int,
	problems:       []Problem_Summary,
}

Search_Report :: struct {
	schema_version: int,
	provider:       string,
	query:          string,
	count:          int,
	problems:       []Search_Match,
}

Show_Report :: struct {
	schema_version: int,
	provider:       string,
	problem_key:    string,
	id:             string,
	title:          string,
	difficulty:     string,
	level:          string,
	statement:      string,
	samples:        []Sample_Report,
}

Sample_Report :: struct {
	name:       string,
	input:      string,
	output:     string,
	provenance: string,
}

Get_Report :: struct {
	schema_version: int,
	provider:       string,
	problem_key:    string,
	directory:      string,
	language:       string,
	sample_count:   int,
}

README_TEMPLATE :: "# Kattis problem: %s\n# https://open.kattis.com/problems/%s\n\nSolution goes in solution.odin.\n"

SOLUTION_TEMPLATE :: `package main

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
	//   n, _ := strconv.parse_int(strings.trim_space(input))
	//   fmt.println(n * 2)
	fmt.println("change me")
}
`

// cmd_list lists the problem table, or searches when given a query.
cmd_list :: proc(o: Options) -> Error {
	if len(o.positionals) > 0 {
		return search(o.positionals[0], o.json)
	}
	page, as_json := o.page, o.json
	body := http_get(fmt.tprintf("%s/problems?page=%d", BASE_URL, page)) or_return
	rows, ok := parse_problem_list(body)
	if !ok {
		return .Markup_Changed
	}
	if as_json {
		judge.print_json(List_Report{SCHEMA_VERSION, PROVIDER, page, len(rows), rows})
		return nil
	}
	ROW :: "%-28s %-42s %-10s %-6s %s\n"
	fmt.printf(ROW, "ID", "NAME", "DIFF", "%ACC", "SUBS")
	for r in rows {
		name := r.name
		if len(name) > 40 {
			name = strings.concatenate({name[:37], "..."})
		}
		fmt.printf(ROW, r.id, name, r.difficulty, r.acceptance_rate, r.submissions)
	}
	fmt.eprintf("%d problems (page %d)\n", len(rows), page)
	return nil
}

// /problems?q= ignores text; the real text search is the global /search page,
// which returns only ids and names.
search :: proc(query: string, as_json: bool) -> Error {
	body := http_get(fmt.tprintf("%s/search?q=%s", BASE_URL, judge.url_encode(query))) or_return
	matches := parse_search_results(body)
	if as_json {
		judge.print_json(Search_Report{SCHEMA_VERSION, PROVIDER, query, len(matches), matches})
		return nil
	}
	fmt.printf("%-28s %s\n", "ID", "NAME")
	for m in matches {
		fmt.printf("%-28s %s\n", m.id, m.name)
	}
	fmt.eprintf("%d problems matching %q\n", len(matches), query)
	return nil
}

cmd_show :: proc(o: Options) -> Error {
	page := fetch_problem(o.positionals[0]) or_return
	if o.json {
		samples := make([]Sample_Report, len(page.samples))
		for s, i in page.samples {
			samples[i] = {fmt.aprintf("sample%d", i + 1), s.input, s.output, "official_sample"}
		}
		judge.print_json(
			Show_Report {
				schema_version = SCHEMA_VERSION,
				provider = PROVIDER,
				problem_key = problem_key(page.id),
				id = page.id,
				title = page.title,
				difficulty = page.difficulty,
				level = page.level,
				statement = judge.strip_tags(page.statement),
				samples = samples,
			},
		)
		return nil
	}
	fmt.println(page.title)
	fmt.printf("kattis: %s | difficulty: %s (%s)\n\n", page.id, page.difficulty, page.level)
	fmt.println(judge.strip_tags(page.statement))
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
	return nil
}

// cmd_get scaffolds a fresh directory; an existing destination is never
// touched, and a partially written one is removed.
cmd_get :: proc(o: Options) -> (err: Error) {
	id := o.positionals[0]
	if !valid_problem_id(id) {
		return .Invalid_Problem_Id
	}
	if o.lang != "" && o.lang != "odin" {
		fmt.eprintln(
			"algo judge kattis get scaffolds Odin only; other languages can still be submitted with --lang",
		)
		return .Unsupported
	}
	dir := o.dir if o.dir != "" else judge.join(o.workspace, id)
	if os.exists(dir) {
		fmt.eprintln("refusing to overwrite", dir)
		return .Destination_Exists
	}
	page := fetch_problem(id) or_return

	samples_dir := judge.join(dir, "samples")
	if mkdir_err := os.make_directory_all(samples_dir, os.perm(0o755)); mkdir_err != nil {
		fmt.eprintln(samples_dir, os.error_string(mkdir_err))
		return .File
	}
	defer if err != nil {
		os.remove_all(dir)
	}

	write_text(
		judge.join(dir, "README.md"),
		fmt.tprintf(README_TEMPLATE, page.title, page.id),
	) or_return
	write_text(
		judge.join(dir, "statement.txt"),
		strings.concatenate({judge.strip_tags(page.statement), "\n"}),
	) or_return
	write_text(judge.join(dir, "solution.odin"), SOLUTION_TEMPLATE) or_return
	for s, i in page.samples {
		write_text(judge.join(samples_dir, fmt.tprintf("sample%d.in", i + 1)), s.input) or_return
		write_text(judge.join(samples_dir, fmt.tprintf("sample%d.out", i + 1)), s.output) or_return
	}

	if o.json {
		judge.print_json(
			Get_Report{SCHEMA_VERSION, PROVIDER, problem_key(id), dir, "odin", len(page.samples)},
		)
		return nil
	}
	fmt.printf(
		"created %s (%s, difficulty %s %s), %d samples\n",
		dir,
		page.title,
		page.difficulty,
		page.level,
		len(page.samples),
	)
	fmt.printf(
		"next: edit %s, then: algo judge kattis test %s\n",
		judge.join(dir, "solution.odin"),
		dir,
	)
	return nil
}

fetch_problem :: proc(id: string) -> (page: Problem_Page, err: Error) {
	if !valid_problem_id(id) {
		return {}, .Invalid_Problem_Id
	}
	body := http_get(fmt.tprintf("%s/problems/%s", BASE_URL, id)) or_return
	return parse_problem_page(id, body), nil
}

// Scaffolds are ordinary, world-readable source files.
write_text :: proc(path, text: string) -> Error {
	return judge.write_file(path, text, judge.PUBLIC_FILE)
}
