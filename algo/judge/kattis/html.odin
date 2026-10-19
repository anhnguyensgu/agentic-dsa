package kattis

// Readers for Kattis's machine-generated HTML, built on the judge package's
// substring anchors. Missing anchors yield empty fields; parse_problem_list
// reports them because an empty catalogue page is otherwise indistinguishable
// from moved markup.

import judge ".."
import "core:strings"

Problem_Summary :: struct {
	id:              string, // URL slug, e.g. "twostones"
	name:            string,
	difficulty:      string, // e.g. "7.1 Hard"
	acceptance_rate: string, // e.g. "82%"
	submissions:     string,
}

Sample :: struct {
	input, output: string,
}

Problem_Page :: struct {
	id:         string,
	title:      string,
	difficulty: string, // e.g. "1.1"
	level:      string, // e.g. "Easy"
	statement:  string, // raw problembody HTML
	samples:    []Sample,
}

Search_Match :: struct {
	id:          string,
	name:        string,
	problem_key: string,
}

parse_problem_list :: proc(html: string) -> (rows: []Problem_Summary, ok: bool) {
	// The page has several tables; the catalogue follows the title_link header.
	_, start := judge.between(html, `data-name="title_link"`, "<tbody>")
	if start < 0 {
		return nil, false
	}
	end := judge.index_from(html, "</tbody>", start)
	if end < 0 {
		return nil, false
	}

	list := make([dynamic]Problem_Summary)
	for pos := start; pos < end; {
		row, next := judge.between(html, "<tr", "</tr>", pos)
		if next < 0 {
			break
		}
		pos = next
		if !strings.contains(row, "/problems/") {
			continue
		}
		// Cells: name, fastest, submissions, accepted, ?, solve rate, difficulty, ...
		cells := judge.table_cells(row)
		if len(cells) < 7 {
			continue
		}
		id, _ := judge.between(cells[0], `href="/problems/`, `"`)
		append(
			&list,
			Problem_Summary {
				id = id,
				name = judge.strip_tags(cells[0]),
				difficulty = judge.strip_tags(cells[6]),
				acceptance_rate = judge.strip_tags(cells[5]),
				submissions = judge.strip_tags(cells[2]),
			},
		)
	}
	return list[:], true
}

parse_problem_page :: proc(id, html: string) -> (page: Problem_Page) {
	page.id = id
	if title, _ := judge.between(html, "<title>", "</title>"); title != "" {
		page.title = judge.strip_tags(title)
		// "Two Stones – Kattis, Kattis"
		if i := strings.index(page.title, " Kattis, Kattis"); i > 0 {
			page.title = strings.trim_space(strings.trim_right(page.title[:i], " -–"))
		}
	}
	// <span class="... difficulty_number-problem_view ...">1.1</span>
	if _, p := judge.between(html, "difficulty_number-problem_view", ">"); p >= 0 {
		number, _ := judge.between(html, "", "<", p)
		page.difficulty = judge.strip_tags(number)
	}
	// The level word follows the Difficulty label.
	if _, p := judge.between(html, `info_label">Difficulty`, "</span>"); p >= 0 {
		level, _ := judge.between(html, `text-link">`, "</span>", p)
		page.level = judge.strip_tags(level)
	}
	page.statement, _ = judge.between(html, `class="problembody">`, "</div>")
	page.samples = parse_samples(html)
	return
}

// Each sample is a <table class="sample"> holding one input/output pair, each
// inside a <pre>.
parse_samples :: proc(html: string) -> []Sample {
	samples := make([dynamic]Sample)
	pos := 0
	for {
		table, next := judge.between(html, `<table class="sample"`, "</table>", pos)
		if next < 0 {
			break
		}
		pos = next
		input, after_input := judge.between(table, "<pre>", "</pre>")
		if after_input < 0 {
			continue
		}
		output, _ := judge.between(table, "<pre>", "</pre>", after_input)
		append(&samples, Sample{input = judge.pre_body(input), output = judge.pre_body(output)})
	}
	return samples[:]
}

// Results live in a table under the "Problems" heading:
// <td><a href="/problems/<id>">id</a></td><td>Name</td>
parse_search_results :: proc(html: string) -> []Search_Match {
	matches := make([dynamic]Search_Match)
	_, pos := judge.between(html, ">Problems</h2>", "<table")
	if pos < 0 {
		return matches[:]
	}
	end := judge.index_from(html, "</table>", pos)
	for pos >= 0 && pos < end {
		cell, next := judge.between(html, "<td", "</td>", pos)
		if next < 0 {
			break
		}
		pos = next
		id, _ := judge.between(judge.cell_content(cell), `href="/problems/`, `"`)
		if id == "" {
			continue
		}
		name, after_name := judge.between(html, "<td", "</td>", pos)
		if after_name < 0 {
			break
		}
		pos = after_name
		append(
			&matches,
			Search_Match {
				id = id,
				name = judge.strip_tags(judge.cell_content(name)),
				problem_key = problem_key(id),
			},
		)
	}
	return matches[:]
}

problem_key :: proc(id: string) -> string {
	return strings.concatenate({"kattis:", id})
}
