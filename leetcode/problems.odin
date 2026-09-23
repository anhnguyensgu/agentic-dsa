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

valid_slug :: proc(s: string) -> bool {
	if s == "" || s[0] == '-' || s[len(s) - 1] == '-' {return false}
	for c in s {if !(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') && c != '-' {return false}}
	return true
}
digits :: proc(s: string) -> bool {
	if s == "" {return false}
	for c in s {if c < '0' || c > '9' {return false}}
	return true
}

cache_path :: proc(o: Options, key: string) -> string {return join_path(
		join_path(o.workspace, ".cache"),
		concat(key, ".json"),
	)}
read_cache :: proc(o: Options, key: string) -> (value: json.Value, err: Error) {
	b, e := os.read_entire_file(cache_path(o, key), context.allocator)
	if e != nil {return nil, .Offline}
	v, je := json.parse(b, .JSON, parse_integers = true)
	if je != nil {return nil, .Offline}
	return v, nil
}
save_cache :: proc(o: Options, key: string, v: json.Value) {
	dir := join_path(o.workspace, ".cache")
	if e := os.make_directory_all(dir, os.perm(0o700));
	   e != nil && e != .Exist {fmt.eprintln("warning: cache directory is not writable"); return}
	if e := write_private_file(cache_path(o, key), transmute([]byte)jencode(v));
	   e != nil {fmt.eprintln("warning: could not save cache")}
}

list_problems :: proc(o: Options, search := "") -> (result: json.Value, err: Error) {
	filters := jobject()
	if search != "" {filters["searchKeywords"] = search}
	if o.difficulty != "" {filters["difficulty"] = strings.to_upper(o.difficulty)}
	switch o.status {
	case "ac":
		filters["status"] = "AC"
	case "notac":
		filters["status"] = "TRIED"
	case "todo":
		filters["status"] = "NOT_STARTED"
	}
	if len(o.tags) > 0 {
		tags := make(json.Array)
		for tag in o.tags {append(&tags, tag)}
		filters["tags"] = tags
	}
	vars := jobject()
	vars["skip"], vars["limit"], vars["filters"] =
		json.Integer(o.skip), json.Integer(o.limit), filters
	// Marshal maps in a stable field order for cache keys.
	key_text := fmt.aprintf(
		"%s|%s|%s|%v|%v|%d|%d",
		search,
		o.difficulty,
		o.status,
		o.free,
		o.tags[:],
		o.limit,
		o.skip,
	)
	key := fmt.aprintf("list-v2-%x", hash.fnv64a(transmute([]byte)key_text))
	if o.offline {
		cached := read_cache(o, key) or_return
		if _, ok := jget(cached, "questions").(json.Array); !ok {return nil, .Offline}
		if _, ok := jget(cached, "total").(json.Integer); !ok {return nil, .Offline}
		return cached, nil
	}
	if o.free {
		all := free_catalog(o, search) or_return
		start := min(o.skip, len(all))
		end := start + min(o.limit, len(all) - start)
		page := make(json.Array)
		append(&page, ..all[start:end])
		obj := jobject()
		obj["total"], obj["questions"] = json.Integer(len(all)), page
		save_cache(o, key, obj)
		return obj, nil
	}
	cfg := request_credentials(o.status != "") or_return
	data := graphql(LIST_QUERY, vars, cfg) or_return
	result = jget(data, "problemsetQuestionList")
	if _, ok := jget(result, "questions").(json.Array); !ok {return nil, .API}
	if _, ok := jget(result, "total").(json.Integer); !ok {return nil, .API}
	save_cache(o, key, result)
	return result, nil
}

// This endpoint supports premium-only, but false means "all", not "free".
// Collect the filtered catalogue before pagination so offsets/totals remain
// meaningful. Random selection also uses this once rather than fetching twice.
free_catalog :: proc(o: Options, search: string) -> (questions: json.Array, err: Error) {
	page := o
	page.free, page.skip, page.limit = false, 0, 100
	questions = make(json.Array)
	for {
		result := list_problems(page, search) or_return
		batch := jarray(jget(result, "questions"))
		for q in batch {if !jbool(jget(q, "isPaidOnly")) {append(&questions, q)}}
		page.skip += len(batch)
		if page.skip >= jint(jget(result, "total")) {break}
		if len(batch) == 0 {return nil, .API}
	}
	return questions, nil
}

resolve_slug :: proc(o: Options, reference: string) -> (slug: string, err: Error) {
	slug = reference
	if strings.has_prefix(slug, "https://leetcode.com/problems/") {
		slug = strings.trim_prefix(slug, "https://leetcode.com/problems/")
		slug, _ = split_once(slug, "/")
		slug, _ = split_once(slug, "?")
	}
	if digits(slug) {
		key := concat("id-", slug)
		if cached, e := read_cache(o, key);
		   e == nil && !o.refresh && valid_slug(jstr(cached)) {return jstr(cached), nil}
		lookup := o
		lookup.limit, lookup.skip = 100, 0
		lookup.difficulty, lookup.status, lookup.tags, lookup.free = "", "", nil, false
		// Search normally places exact frontend IDs first. Walk every search
		// page to avoid accidentally resolving a different matching number.
		for {
			result := list_problems(lookup, slug) or_return
			for q in jarray(jget(result, "questions")) {
				if jstr(jget(q, "questionFrontendId")) == slug {
					found := jstr(jget(q, "titleSlug"))
					if !valid_slug(found) {return "", .API}
					save_cache(o, key, found)
					return found, nil
				}
			}
			lookup.skip += lookup.limit
			if lookup.skip >= jint(jget(result, "total")) {return "", .Not_Found}
		}
	}
	if !valid_slug(
		slug,
	) {fmt.eprintln("expected a problem slug, frontend ID, or https://leetcode.com/problems/... URL"); return "", .Usage}
	return slug, nil
}

get_problem :: proc(o: Options, reference: string) -> (q: json.Value, err: Error) {
	slug := resolve_slug(o, reference) or_return
	key := concat("problem-", slug)
	if o.offline || !o.refresh {
		cached, ce := read_cache(o, key)
		if ce == nil &&
		   jstr(jget(cached, "titleSlug")) == slug &&
		   digits(jstr(jget(cached, "questionId"))) {return cached, nil}
		if o.offline {return nil, .Offline}
	}
	cfg := request_credentials() or_return
	vars := jobject(); vars["slug"] = slug
	data := graphql(PROBLEM_QUERY, vars, cfg) or_return
	q = jget(data, "question")
	if q == nil || jstr(jget(q, "titleSlug")) == "" {return nil, .Not_Found}
	if jstr(jget(q, "titleSlug")) != slug || jstr(jget(q, "questionId")) == "" {return nil, .API}
	save_cache(o, key, q)
	if id := jstr(jget(q, "questionFrontendId"));
	   digits(id) {save_cache(o, concat("id-", id), slug)}
	return q, nil
}

cmd_list :: proc(o: Options) -> Error {
	search := ""
	if len(o.positionals) > 0 {search = o.positionals[0]}
	result := list_problems(o, search) or_return
	if o.json {print_json(result); return nil}
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
	fmt.printf(
		"%d total; offset %d. Use --skip and --limit to page.\n",
		jint(jget(result, "total")),
		o.skip,
	)
	return nil
}

cmd_problem :: proc(o: Options) -> Error {
	ref := ""
	if len(o.positionals) > 0 {ref = o.positionals[0]}
	if o.command == "daily" {
		data: json.Value
		if o.offline {data = read_cache(o, "daily") or_return} else {
			cfg := request_credentials() or_return
			data = graphql(
				`query { activeDailyCodingChallengeQuestion { date question { titleSlug } } }`,
				jobject(),
				cfg,
			) or_return
			save_cache(o, "daily", data)
		}
		daily := jget(data, "activeDailyCodingChallengeQuestion")
		ref = jstr(jget(jget(daily, "question"), "titleSlug"))
		if !o.json {fmt.printf("Daily challenge: %s%s\n", jstr(jget(daily, "date")), " (cached)" if o.offline else "")}
	}
	if o.command == "random" {
		if o.offline {
			return offline_random(o)
		}
		if o.free {
			all := free_catalog(o, "") or_return
			if len(all) == 0 {return .Not_Found}
			ref = jstr(jget(all[rand.int_range(0, len(all))], "titleSlug"))
		} else {
			page := o; page.limit, page.skip = 1, 0
			first := list_problems(page) or_return
			total := jint(jget(first, "total"))
			if total <= 0 {return .Not_Found}
			page.skip = rand.int_range(0, total)
			result := list_problems(page) or_return
			questions := jarray(jget(result, "questions"))
			if len(questions) == 0 {return .Not_Found}
			ref = jstr(jget(questions[0], "titleSlug"))
		}
	}
	if o.command == "open" {
		slug := resolve_slug(o, ref) or_return
		open_browser(concat("https://leetcode.com/problems/", net.percent_encode(slug), "/"))
		return nil
	}
	q := get_problem(o, ref) or_return
	if o.command == "pick" {return scaffold(o, q)}
	if o.command == "languages" {
		if o.json {print_json(jget(q, "codeSnippets")); return nil}
		fmt.println("odin\tOdin (local only)")
		for s in jarray(jget(q, "codeSnippets")) {fmt.printf("%s\t%s\n", jstr(jget(s, "langSlug")), jstr(jget(s, "lang")))}
		return nil
	}
	if o.json {print_json(q); return nil}
	fmt.printf(
		"%s. %s [%s]\nhttps://leetcode.com/problems/%s/\n\n",
		jstr(jget(q, "questionFrontendId")),
		jstr(jget(q, "title")),
		jstr(jget(q, "difficulty")),
		jstr(jget(q, "titleSlug")),
	)
	content := jstr(jget(q, "content"))
	if content ==
	   "" {fmt.println("Description unavailable; this problem may require Premium.")} else {fmt.println(html_text(content))}
	return nil
}

offline_random :: proc(o: Options) -> Error {
	if o.status !=
	   "" {fmt.eprintln("offline random cannot filter account progress"); return .Usage}
	files, fe := os.read_directory_by_path(join_path(o.workspace, ".cache"), -1, context.allocator)
	if fe != nil {return .Offline}
	choices := [dynamic]string{}
	for f in files {
		if !strings.has_prefix(f.name, "problem-") ||
		   !strings.has_suffix(f.name, ".json") {continue}
		q, e := read_cache(o, f.name[:len(f.name) - 5])
		if e != nil || !valid_slug(jstr(jget(q, "titleSlug"))) {continue}
		if o.free && jbool(jget(q, "isPaidOnly")) {continue}
		if o.difficulty != "" && jstr(jget(q, "difficulty")) != o.difficulty {continue}
		matches := true
		for wanted in o.tags {
			found := false
			for tag in jarray(jget(q, "topicTags")) {if jstr(jget(tag, "slug")) == wanted {found = true; break}}
			matches = matches && found
		}
		if matches {append(&choices, jstr(jget(q, "titleSlug")))}
	}
	if len(choices) == 0 {return .Offline}
	next := o; next.command = "show"
	next.positionals = make([dynamic]string)
	append(&next.positionals, choices[rand.int_range(0, len(choices))])
	return cmd_problem(next)
}

// Lightweight readable rendering, preserving preformatted examples and math.
html_text :: proc(html: string) -> string {
	b := [dynamic]byte{}
	for i := 0; i < len(html); {
		if html[i] == '<' {
			end := strings.index(html[i:], ">")
			if end < 0 {break}
			tag := html[i + 1:i + end]
			if tag == "sup" {append(&b, '^')}
			if tag == "li" {append(&b, '-', ' ')}
			if tag == "br" ||
			   tag == "br/" ||
			   tag == "br /" ||
			   tag == "/p" ||
			   tag == "/li" ||
			   tag == "/pre" {append(&b, '\n')}
			i += end + 1; continue
		}
		append(&b, html[i]); i += 1
	}
	s := string(b[:])
	pairs := [][2]string {
		{"&nbsp;", " "},
		{"&lt;", "<"},
		{"&gt;", ">"},
		{"&quot;", "\""},
		{"&#39;", "'"},
		{"&amp;", "&"},
	}
	for pair in pairs {s = strings.replace_all(s, pair[0], pair[1]) or_else s}
	return strings.trim_space(s)
}
