package judge

// Substring-anchored HTML readers. Judge pages are machine-generated and
// stable, so providers locate fields with plain anchors instead of a parser;
// a missing anchor yields an empty field or a -1 offset.

import "core:strings"

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

// A newline right after <pre> is markup, not data: `<pre>\n1\n</pre>` holds "1\n".
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
	return decode_entities(strings.to_string(b), HTML_ENTITIES[:])
}

// html_text renders statement HTML as readable text, keeping the line
// structure of preformatted examples and superscripts in constraints.
html_text :: proc(html: string) -> string {
	b := strings.builder_make()
	for i := 0; i < len(html); {
		if html[i] != '<' {
			strings.write_byte(&b, html[i])
			i += 1
			continue
		}
		end := strings.index_byte(html[i:], '>')
		if end < 0 {
			break
		}
		switch html[i + 1:i + end] {
		case "sup":
			strings.write_byte(&b, '^')
		case "li":
			strings.write_string(&b, "- ")
		case "br", "br/", "br /", "/p", "/li", "/pre":
			strings.write_byte(&b, '\n')
		}
		i += end + 1
	}
	return strings.trim_space(decode_entities(strings.to_string(b), BASIC_ENTITIES[:]))
}

// The entities every page uses.
BASIC_ENTITIES := [?][2]string {
	{"&amp;", "&"},
	{"&lt;", "<"},
	{"&gt;", ">"},
	{"&quot;", "\""},
	{"&#39;", "'"},
	{"&nbsp;", " "},
}

// BASIC_ENTITIES plus the typographic ones Kattis statements emit.
HTML_ENTITIES := [?][2]string {
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

// decode_entities decodes the given entities in a single pass, so an escaped
// entity such as "&amp;lt;" becomes "&lt;" rather than "<".
decode_entities :: proc(s: string, entities: [][2]string) -> string {
	if !strings.contains_rune(s, '&') {
		return s
	}
	b := strings.builder_make()
	scan: for i := 0; i < len(s); {
		if s[i] == '&' {
			for entity in entities {
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
