package main

// Substring-anchored readers for Kattis's machine-generated HTML. Missing
// anchors yield empty fields; parse_problem_list reports them because an
// empty catalogue page is otherwise indistinguishable from moved markup.

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
	_, start := between(html, `data-name="title_link"`, "<tbody>")
	if start < 0 {
		return nil, false
	}
	end := index_from(html, "</tbody>", start)
	if end < 0 {
		return nil, false
	}

	list := make([dynamic]Problem_Summary)
	for pos := start; pos < end; {
		row, next := between(html, "<tr", "</tr>", pos)
		if next < 0 {
			break
		}
		pos = next
		if !strings.contains(row, "/problems/") {
			continue
		}
		// Cells: name, fastest, submissions, accepted, ?, solve rate, difficulty, ...
		cells := table_cells(row)
		if len(cells) < 7 {
			continue
		}
		id, _ := between(cells[0], `href="/problems/`, `"`)
		append(&list, Problem_Summary{
			id              = id,
			name            = strip_tags(cells[0]),
			difficulty      = strip_tags(cells[6]),
			acceptance_rate = strip_tags(cells[5]),
			submissions     = strip_tags(cells[2]),
		})
	}
	return list[:], true
}

parse_problem_page :: proc(id, html: string) -> (page: Problem_Page) {
	page.id = id
	if title, _ := between(html, "<title>", "</title>"); title != "" {
		page.title = strip_tags(title)
		// "Two Stones – Kattis, Kattis"
		if i := strings.index(page.title, " Kattis, Kattis"); i > 0 {
			page.title = strings.trim_space(strings.trim_right(page.title[:i], " -–"))
		}
	}
	// <span class="... difficulty_number-problem_view ...">1.1</span>
	if _, p := between(html, "difficulty_number-problem_view", ">"); p >= 0 {
		number, _ := between(html, "", "<", p)
		page.difficulty = strip_tags(number)
	}
	// The level word follows the Difficulty label.
	if _, p := between(html, `info_label">Difficulty`, "</span>"); p >= 0 {
		level, _ := between(html, `text-link">`, "</span>", p)
		page.level = strip_tags(level)
	}
	page.statement, _ = between(html, `class="problembody">`, "</div>")
	page.samples = parse_samples(html)
	return
}

// Each sample is a <table class="sample"> holding one input/output pair, each
// inside a <pre>.
parse_samples :: proc(html: string) -> []Sample {
	samples := make([dynamic]Sample)
	pos := 0
	for {
		table, next := between(html, `<table class="sample"`, "</table>", pos)
		if next < 0 {
			break
		}
		pos = next
		input, after_input := between(table, "<pre>", "</pre>")
		if after_input < 0 {
			continue
		}
		output, _ := between(table, "<pre>", "</pre>", after_input)
		append(&samples, Sample{input = pre_body(input), output = pre_body(output)})
	}
	return samples[:]
}

// Results live in a table under the "Problems" heading:
// <td><a href="/problems/<id>">id</a></td><td>Name</td>
parse_search_results :: proc(html: string) -> []Search_Match {
	matches := make([dynamic]Search_Match)
	_, pos := between(html, ">Problems</h2>", "<table")
	if pos < 0 {
		return matches[:]
	}
	end := index_from(html, "</table>", pos)
	for pos >= 0 && pos < end {
		cell, next := between(html, "<td", "</td>", pos)
		if next < 0 {
			break
		}
		pos = next
		id, _ := between(cell_content(cell), `href="/problems/`, `"`)
		if id == "" {
			continue
		}
		name, after_name := between(html, "<td", "</td>", pos)
		if after_name < 0 {
			break
		}
		pos = after_name
		append(&matches, Search_Match{id = id, name = strip_tags(cell_content(name)), problem_key = problem_key(id)})
	}
	return matches[:]
}

problem_key :: proc(id: string) -> string {
	return strings.concatenate({"kattis:", id})
}

// between returns the text of s between start and end, searching from offset
// from, plus the offset just past end. next is -1 when a marker is missing.
between :: proc(s, start, end: string, from := 0) -> (text: string, next: int) {
	i := index_from(s, start, from)
	if i < 0 {
		return "", -1
	}
	i += len(start)
	j := index_from(s, end, i)
	if j < 0 {
		return "", -1
	}
	return s[i:j], j + len(end)
}

index_from :: proc(s, needle: string, from: int) -> int {
	if from > len(s) {
		return -1
	}
	i := strings.index(s[from:], needle)
	return i + from if i >= 0 else -1
}

// table_cells returns the content of each <td> in row.
table_cells :: proc(row: string) -> []string {
	cells := make([dynamic]string)
	for pos := 0; pos < len(row); {
		cell, next := between(row, "<td", "</td>", pos)
		if next < 0 {
			break
		}
		append(&cells, cell_content(cell))
		pos = next
	}
	return cells[:]
}

// cell_content drops the rest of an opening tag: `<td class="x">body` -> body.
cell_content :: proc(cell: string) -> string {
	if i := strings.index_byte(cell, '>'); i >= 0 {
		return cell[i + 1:]
	}
	return cell
}

// Kattis writes `<pre>\n1\n</pre>`; the newline after <pre> is not data.
pre_body :: proc(s: string) -> string {
	return strings.trim_prefix(s, "\n")
}

// strip_tags removes <...> tags, collapses whitespace runs, and decodes entities.
strip_tags :: proc(s: string) -> string {
	b := strings.builder_make()
	in_tag := false
	previous_space := true // trims leading whitespace
	for i in 0 ..< len(s) {
		c := s[i] // bytes keep UTF-8 sequences intact; the anchors are ASCII
		switch {
		case c == '<':
			in_tag = true
		case c == '>':
			in_tag = false
		case in_tag:
		case c == ' ', c == '\n', c == '\t', c == '\r':
			if !previous_space {
				strings.write_byte(&b, ' ')
			}
			previous_space = true
		case:
			strings.write_byte(&b, c)
			previous_space = false
		}
	}
	return decode_entities(strings.to_string(b))
}

// decode_entities decodes the entities Kattis emits in a single pass, so an
// escaped entity such as "&amp;lt;" becomes "&lt;" rather than "<".
decode_entities :: proc(s: string) -> string {
	ENTITIES :: [?][2]string {
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
	if !strings.contains_rune(s, '&') {
		return s
	}
	b := strings.builder_make()
	scan: for i := 0; i < len(s); {
		if s[i] == '&' {
			for entity in ENTITIES {
				if strings.has_prefix(s[i:], entity[0]) {
					strings.write_string(&b, entity[1])
					i += len(entity[0])
					continue scan
				}
			}
		}
		strings.write_byte(&b, s[i])
		i += 1
	}
	return strings.to_string(b)
}
