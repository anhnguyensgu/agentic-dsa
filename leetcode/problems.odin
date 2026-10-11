package main

import "core:encoding/json"
import "core:fmt"
import "core:hash"
import "core:math/rand"
import "core:net"
import "core:os"
import "core:strings"

LIST_QUERY :: `query($skip:Int,$limit:Int,$filters:QuestionListFilterInput) {
 problemsetQuestionList: questionList(categorySlug:"all-code-essentials",skip:$skip,limit:$limit,filters:$filters) {
 total:totalNum questions:data { questionFrontendId title titleSlug difficulty isPaidOnly status acRate topicTags { name slug } }
 } }`

PROBLEM_QUERY :: `query($slug:String!) { question(titleSlug:$slug) {
 questionId questionFrontendId title titleSlug difficulty content exampleTestcaseList sampleTestCase metaData
 codeSnippets { lang langSlug code } topicTags { name slug } isPaidOnly hints stats
} }`

DAILY_QUERY :: `query { activeDailyCodingChallengeQuestion { date question { titleSlug } } }`

PROBLEM_URL_PREFIX :: "https://leetcode.com/problems/"

valid_slug :: proc(s: string) -> bool {
	if s == "" || s[0] == '-' || s[len(s) - 1] == '-' {
		return false
	}
	for c in s {
		switch c {
		case 'a' ..= 'z', '0' ..= '9', '-':
		case:
			return false
		}
	}
	return true
}

digits :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for c in s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

// -- cache ---------------------------------------------------------------------

cache_path :: proc(o: Options, key: string) -> string {
	return join_path(join_path(o.workspace, ".cache"), concat(key, ".json"))
}

read_cache :: proc(o: Options, key: string) -> (value: json.Value, err: Error) {
	data, read_err := os.read_entire_file(cache_path(o, key), context.allocator)
	if read_err != nil {
		return nil, .Offline
	}
	parsed, parse_err := json.parse(data, .JSON, parse_integers = true)
	if parse_err != nil {
		return nil, .Offline
	}
	return parsed, nil
}

// Caching is best effort; a read-only workspace only costs a warning.
save_cache :: proc(o: Options, key: string, v: json.Value) {
	if write_private_file(cache_path(o, key), jencode(v)) != nil {
		fmt.eprintln("warning: could not save cache")
	}
}

// -- queries -------------------------------------------------------------------

list_problems :: proc(o: Options, search := "") -> (result: json.Value, err: Error) {
	filters := jobject()
	if search != "" {
		filters["searchKeywords"] = search
	}
	if o.difficulty != "" {
		filters["difficulty"] = strings.to_upper(o.difficulty)
	}
	switch o.status {
	case "ac":    filters["status"] = "AC"
	case "notac": filters["status"] = "TRIED"
	case "todo":  filters["status"] = "NOT_STARTED"
	}
	if len(o.tags) > 0 {
		tags := make(json.Array, 0, len(o.tags))
		for tag in o.tags {
			append(&tags, tag)
		}
		filters["tags"] = tags
	}
	vars := jobject()
	vars["skip"], vars["limit"], vars["filters"] = json.Integer(o.skip), json.Integer(o.limit), filters

	// The key covers every input of the query, in a fixed order.
	key_text := fmt.tprintf("%s|%s|%s|%v|%v|%d|%d", search, o.difficulty, o.status, o.free, o.tags[:], o.limit, o.skip)
	key := fmt.aprintf("list-v2-%x", hash.fnv64a(transmute([]byte)key_text))
	if o.offline {
		cached := read_cache(o, key) or_return
		if !is_problem_page(cached) {
			return nil, .Offline
		}
		return cached, nil
	}
	if o.free {
		all := free_catalog(o, search) or_return
		start := min(o.skip, len(all))
		end := start + min(o.limit, len(all) - start)
		page := make(json.Array, 0, end - start)
		append(&page, ..all[start:end])
		result := jobject()
		result["total"], result["questions"] = json.Integer(len(all)), page
		save_cache(o, key, result)
		return result, nil
	}
	cfg := request_credentials(required = o.status != "") or_return
	data := graphql(LIST_QUERY, vars, cfg) or_return
	result = jget(data, "problemsetQuestionList")
	if !is_problem_page(result) {
		return nil, .API
	}
	save_cache(o, key, result)
	return result, nil
}

is_problem_page :: proc(v: json.Value) -> bool {
	_, has_questions := jget(v, "questions").(json.Array)
	_, has_total := jget(v, "total").(json.Integer)
	return has_questions && has_total
}

// The endpoint can filter to premium-only, but false means "all", not "free".
// Collect the filtered catalogue before paginating so offsets and totals stay
// meaningful. Random selection reuses this rather than fetching twice.
free_catalog :: proc(o: Options, search: string) -> (questions: json.Array, err: Error) {
	page := o
	page.free, page.skip, page.limit = false, 0, 100
	questions = make(json.Array)
	for {
		result := list_problems(page, search) or_return
		batch := jarray(jget(result, "questions"))
		for q in batch {
			if !jbool(jget(q, "isPaidOnly")) {
				append(&questions, q)
			}
		}
		page.skip += len(batch)
		if page.skip >= jint(jget(result, "total")) {
			break
		}
		if len(batch) == 0 {
			return nil, .API
		}
	}
	return questions, nil
}

// resolve_slug accepts a slug, a problem URL, or a frontend problem ID.
resolve_slug :: proc(o: Options, reference: string) -> (slug: string, err: Error) {
	slug = reference
	if strings.has_prefix(slug, PROBLEM_URL_PREFIX) {
		slug, _ = split_once(strings.trim_prefix(slug, PROBLEM_URL_PREFIX), "/")
		slug, _ = split_once(slug, "?")
	}
	if !digits(slug) {
		if !valid_slug(slug) {
			fmt.eprintln("expected a problem slug, frontend ID, or https://leetcode.com/problems/... URL")
			return "", .Usage
		}
		return slug, nil
	}

	key := concat("id-", slug)
	if cached, cache_err := read_cache(o, key); cache_err == nil && !o.refresh && valid_slug(jstr(cached)) {
		return jstr(cached), nil
	}
	lookup := o
	lookup.limit, lookup.skip = 100, 0
	lookup.difficulty, lookup.status, lookup.tags, lookup.free = "", "", nil, false
	// Search usually lists the exact frontend ID first, but walk every page so
	// a different matching number is never mistaken for it.
	for {
		result := list_problems(lookup, slug) or_return
		for q in jarray(jget(result, "questions")) {
			if jstr(jget(q, "questionFrontendId")) != slug {
				continue
			}
			found := jstr(jget(q, "titleSlug"))
			if !valid_slug(found) {
				return "", .API
			}
			save_cache(o, key, found)
			return found, nil
		}
		lookup.skip += lookup.limit
		if lookup.skip >= jint(jget(result, "total")) {
			return "", .Not_Found
		}
	}
}

get_problem :: proc(o: Options, reference: string) -> (q: json.Value, err: Error) {
	slug := resolve_slug(o, reference) or_return
	key := concat("problem-", slug)
	if o.offline || !o.refresh {
		cached, cache_err := read_cache(o, key)
		if cache_err == nil && jstr(jget(cached, "titleSlug")) == slug && digits(jstr(jget(cached, "questionId"))) {
			return cached, nil
		}
		if o.offline {
			return nil, .Offline
		}
	}
	cfg := request_credentials() or_return
	vars := jobject()
	vars["slug"] = slug
	data := graphql(PROBLEM_QUERY, vars, cfg) or_return
	q = jget(data, "question")
	if q == nil || jstr(jget(q, "titleSlug")) == "" {
		return nil, .Not_Found
	}
	if jstr(jget(q, "titleSlug")) != slug || jstr(jget(q, "questionId")) == "" {
		return nil, .API
	}
	save_cache(o, key, q)
	if id := jstr(jget(q, "questionFrontendId")); digits(id) {
		save_cache(o, concat("id-", id), slug)
	}
	return q, nil
}

// -- commands ------------------------------------------------------------------

cmd_list :: proc(o: Options) -> Error {
	search := o.positionals[0] if len(o.positionals) > 0 else ""
	result := list_problems(o, search) or_return
	if o.json {
		print_json(result)
		return nil
	}
	for q in jarray(jget(result, "questions")) {
		fmt.printf(
			"%5s  %-6s %-6s %s%s\n",
			jstr(jget(q, "questionFrontendId")),
			jstr(jget(q, "difficulty")),
			jstr(jget(q, "status")),
			jstr(jget(q, "title")),
			" [paid]" if jbool(jget(q, "isPaidOnly")) else "",
		)
	}
	fmt.printf("%d total; offset %d. Use --skip and --limit to page.\n", jint(jget(result, "total")), o.skip)
	return nil
}

// cmd_problem handles every command that starts by choosing one problem.
cmd_problem :: proc(o: Options) -> Error {
	ref := o.positionals[0] if len(o.positionals) > 0 else ""
	#partial switch o.command {
	case .Daily:
		ref = daily_slug(o) or_return
	case .Random:
		if o.offline {
			return offline_random(o)
		}
		ref = random_slug(o) or_return
	case .Open:
		slug := resolve_slug(o, ref) or_return
		open_browser(concat(PROBLEM_URL_PREFIX, net.percent_encode(slug), "/"))
		return nil
	}

	q := get_problem(o, ref) or_return
	#partial switch o.command {
	case .Pick:
		return scaffold(o, q)
	case .Languages:
		if o.json {
			print_json(jget(q, "codeSnippets"))
			return nil
		}
		fmt.println("odin\tOdin (local only)")
		for s in jarray(jget(q, "codeSnippets")) {
			fmt.printf("%s\t%s\n", jstr(jget(s, "langSlug")), jstr(jget(s, "lang")))
		}
		return nil
	}

	if o.json {
		print_json(q)
		return nil
	}
	fmt.printf(
		"%s. %s [%s]\n%s%s/\n\n",
		jstr(jget(q, "questionFrontendId")),
		jstr(jget(q, "title")),
		jstr(jget(q, "difficulty")),
		PROBLEM_URL_PREFIX,
		jstr(jget(q, "titleSlug")),
	)
	if content := jstr(jget(q, "content")); content != "" {
		fmt.println(html_text(content))
	} else {
		fmt.println("Description unavailable; this problem may require Premium.")
	}
	return nil
}

daily_slug :: proc(o: Options) -> (slug: string, err: Error) {
	data: json.Value
	if o.offline {
		data = read_cache(o, "daily") or_return
	} else {
		cfg := request_credentials() or_return
		data = graphql(DAILY_QUERY, jobject(), cfg) or_return
		save_cache(o, "daily", data)
	}
	daily := jget(data, "activeDailyCodingChallengeQuestion")
	if !o.json {
		fmt.printf("Daily challenge: %s%s\n", jstr(jget(daily, "date")), " (cached)" if o.offline else "")
	}
	return jstr(jget(jget(daily, "question"), "titleSlug")), nil
}

random_slug :: proc(o: Options) -> (slug: string, err: Error) {
	if o.free {
		all := free_catalog(o, "") or_return
		if len(all) == 0 {
			return "", .Not_Found
		}
		return jstr(jget(rand.choice(all[:]), "titleSlug")), nil
	}
	page := o
	page.limit, page.skip = 1, 0
	first := list_problems(page) or_return
	total := jint(jget(first, "total"))
	if total <= 0 {
		return "", .Not_Found
	}
	page.skip = rand.int_range(0, total)
	result := list_problems(page) or_return
	questions := jarray(jget(result, "questions"))
	if len(questions) == 0 {
		return "", .Not_Found
	}
	return jstr(jget(questions[0], "titleSlug")), nil
}

// offline_random picks among downloaded problems that match the filters.
offline_random :: proc(o: Options) -> Error {
	if o.status != "" {
		fmt.eprintln("offline random cannot filter account progress")
		return .Usage
	}
	files, list_err := os.read_directory_by_path(join_path(o.workspace, ".cache"), -1, context.allocator)
	if list_err != nil {
		return .Offline
	}
	choices := make([dynamic]string)
	for f in files {
		if !strings.has_prefix(f.name, "problem-") || !strings.has_suffix(f.name, ".json") {
			continue
		}
		q, cache_err := read_cache(o, strings.trim_suffix(f.name, ".json"))
		if cache_err == nil && matches_filters(o, q) {
			append(&choices, jstr(jget(q, "titleSlug")))
		}
	}
	if len(choices) == 0 {
		return .Offline
	}
	next := o
	next.command = .Show
	next.positionals = make([dynamic]string)
	append(&next.positionals, rand.choice(choices[:]))
	return cmd_problem(next)
}

matches_filters :: proc(o: Options, q: json.Value) -> bool {
	if !valid_slug(jstr(jget(q, "titleSlug"))) {
		return false
	}
	if o.free && jbool(jget(q, "isPaidOnly")) {
		return false
	}
	if o.difficulty != "" && jstr(jget(q, "difficulty")) != o.difficulty {
		return false
	}
	tags := jarray(jget(q, "topicTags"))
	wanted: for want in o.tags {
		for tag in tags {
			if jstr(jget(tag, "slug")) == want {
				continue wanted
			}
		}
		return false
	}
	return true
}

// html_text renders problem HTML as readable text, keeping the line structure
// of preformatted examples and superscripts in constraints.
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
	s := strings.to_string(b)
	ENTITIES :: [?][2]string{{"&nbsp;", " "}, {"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&#39;", "'"}, {"&amp;", "&"}}
	for entity in ENTITIES {
		s, _ = strings.replace_all(s, entity[0], entity[1])
	}
	return strings.trim_space(s)
}
