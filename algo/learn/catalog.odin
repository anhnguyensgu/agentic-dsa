package learn

// Versioned offline curriculum and reviewed provider mappings (sections 8 and
// 16). The files stay distributable artifacts, while #load keeps the binary
// independent of its working directory.

import "core:fmt"
import "core:strings"

CONCEPTS_JSON :: #load("../curriculum/concepts.json", string)
PROBLEMS_JSON :: #load("../curriculum/problems.json", string)
CATALOG_VERSION :: "2026-09-20"

// The doctor treats a smaller catalogue as damaged.
MIN_CATALOG_PROBLEMS :: 36

Catalog_Problem :: struct {
	problem_key:     string,
	provider:        string,
	native_id:       string,
	slug:            string,
	title:           string,
	canonical_url:   string,
	difficulty:      string,
	effort_minutes:  int,
	access:          string,
	offline:         bool,
	concept_ids:     []string,
	prerequisites:   []string,
	practice_modes:  []string,
	judge_languages: []string,
	spoiler_tags:    []string,
	label_origin:    string,
}

Curriculum_Concept :: struct {
	id:            string,
	title:         string,
	prerequisites: []string,
}

catalog_problems :: proc() -> (problems: []Catalog_Problem, err: Engine_Error) {
	doc: struct {
		problems: []Catalog_Problem,
	}
	if !decode(PROBLEMS_JSON, &doc) {
		return nil, .Storage_Error
	}
	return doc.problems, nil
}

curriculum_concepts :: proc() -> (concepts: []Curriculum_Concept, ok: bool) {
	doc: struct {
		concepts: []Curriculum_Concept,
	}
	ok = decode(CONCEPTS_JSON, &doc)
	return doc.concepts, ok
}

catalog_find :: proc(problem_key: string) -> (Catalog_Problem, bool) {
	problems, err := catalog_problems()
	if err != nil {
		return {}, false
	}
	for problem in problems {
		if problem.problem_key == problem_key {
			return problem, true
		}
	}
	return {}, false
}

// resolve_problem returns the curated entry for a catalogue problem, or
// describes any other "<provider>:<slug>" key from the key alone. Agents may
// pick any provider problem; the catalogue only adds reviewed metadata.
resolve_problem :: proc(problem_key: string) -> (problem: Catalog_Problem, err: Op_Error) {
	if curated, found := catalog_find(problem_key); found {
		return curated, nil
	}
	provider, _, slug := strings.partition(problem_key, ":")
	providers := PROVIDERS
	if !contains(providers[:], provider) || !is_problem_slug(slug) {
		return {}, invalid(`problem_key must be "<provider>:<slug>" with provider leetcode or kattis and a lowercase slug, such as "leetcode:two-sum" or "kattis:hello"`)
	}
	url := fmt.aprintf("https://open.kattis.com/problems/%s", slug) if provider == "kattis" else fmt.aprintf("https://leetcode.com/problems/%s/", slug)
	return {
		problem_key   = problem_key,
		provider      = provider,
		native_id     = slug,
		slug          = slug,
		title         = slug,
		canonical_url = url,
		label_origin  = UNCATALOGUED,
	}, nil
}

// Problems outside the curated catalogue carry this label origin.
UNCATALOGUED :: "uncatalogued"

// A provider slug becomes a directory name, so it is restricted to lowercase
// letters, digits, '-', '_', and '.', starting with a letter or digit.
is_problem_slug :: proc(slug: string) -> bool {
	if len(slug) == 0 || len(slug) > 100 {
		return false
	}
	for c, i in transmute([]u8)slug {
		alnum := (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
		if !alnum && (i == 0 || (c != '-' && c != '_' && c != '.')) {
			return false
		}
	}
	return true
}

// known_concepts requires every id to name a curriculum topic; topics are a
// fixed list even though problems are not.
known_concepts :: proc(field: string, ids: ..string) -> Op_Error {
	concepts, ok := curriculum_concepts()
	if !ok {
		return fail(.Storage_Error, "the bundled curriculum could not be read")
	}
	names := make([dynamic]string)
	for c in concepts {
		append(&names, c.id)
	}
	for id in ids {
		if id != "" && !contains(names[:], id) {
			return invalid(fmt.aprintf("%s must be curriculum topics: %s", field, strings.join(names[:], ", ")))
		}
	}
	return nil
}

// supports_language reports whether a problem can be practiced in language,
// locally (Odin) or on the provider's judge.
supports_language :: proc(problem: Catalog_Problem, language: string) -> bool {
	local := language == "odin" && contains(problem.practice_modes, "odin_local")
	return local || contains(problem.judge_languages, language)
}

matches_query :: proc(problem: Catalog_Problem, query: string) -> bool {
	if query == "" {
		return true
	}
	q := strings.to_lower(query)
	for field in ([?]string{problem.title, problem.problem_key, problem.slug}) {
		if strings.contains(strings.to_lower(field), q) {
			return true
		}
	}
	return false
}

// Assessment views omit spoiler tags, which can reveal the technique.
Audience :: enum {
	Learning,
	Assessment,
}

AUDIENCE_NAMES := [Audience]string {
	.Learning   = "learning",
	.Assessment = "assessment",
}

Problem_View :: struct {
	problem_key:     string,
	provider:        string,
	native_id:       string,
	slug:            string,
	title:           string,
	canonical_url:   string,
	difficulty:      string,
	effort_minutes:  int,
	access:          string,
	offline:         bool,
	concept_ids:     []string,
	prerequisites:   []string,
	practice_modes:  []string,
	judge_languages: []string,
	spoiler_tags:    Maybe([]string) `json:",omitempty"`,
	label_origin:    string,
}

problem_view :: proc(p: Catalog_Problem, audience: Audience) -> Problem_View {
	return {
		problem_key     = p.problem_key,
		provider        = p.provider,
		native_id       = p.native_id,
		slug            = p.slug,
		title           = p.title,
		canonical_url   = p.canonical_url,
		difficulty      = p.difficulty,
		effort_minutes  = p.effort_minutes,
		access          = p.access,
		offline         = p.offline,
		concept_ids     = p.concept_ids,
		prerequisites   = p.prerequisites,
		practice_modes  = p.practice_modes,
		judge_languages = p.judge_languages,
		spoiler_tags    = p.spoiler_tags if audience == .Learning else nil,
		label_origin    = p.label_origin,
	}
}

parse_audience :: proc(name: string) -> (Audience, Op_Error) {
	if name == "" {
		return .Learning, nil
	}
	if audience, ok := parse_enum(AUDIENCE_NAMES, name); ok {
		return audience, nil
	}
	return {}, invalid("audience must be learning or assessment")
}

// -- problem_search ------------------------------------------------------------

Problem_Search_Params :: struct {
	provider:   string,
	query:      string,
	concept_id: string,
	language:   string,
	offline:    bool,
	limit:      int,
	cursor:     int,
	audience:   string,
}

op_problem_search :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Problem_Search_Params) or_return
	audience := parse_audience(p.audience) or_return
	limit := p.limit if p.limit != 0 else 20
	if limit < 1 || limit > 100 {
		return {}, invalid("limit must be between 1 and 100")
	}
	if p.cursor < 0 {
		return {}, invalid("cursor must be zero or greater")
	}
	problems, catalog_err := catalog_problems()
	if catalog_err != nil {
		return {}, fail(catalog_err, "the bundled curriculum could not be read")
	}

	page := make([dynamic]Problem_View)
	matched, skipped := 0, 0
	for problem in problems {
		if p.provider != "" && problem.provider != p.provider {
			continue
		}
		if !matches_query(problem, p.query) {
			continue
		}
		if p.concept_id != "" && !contains(problem.concept_ids, p.concept_id) {
			continue
		}
		if p.language != "" && !supports_language(problem, p.language) {
			continue
		}
		if skipped < p.cursor {
			skipped += 1
			continue
		}
		matched += 1
		if len(page) < limit {
			append(&page, problem_view(problem, audience))
		}
	}

	Data :: struct {
		problems:        []Problem_View,
		count:           int,
		next_cursor:     int, // 0 when there is no further page
		catalog_version: string,
	}
	next_cursor := p.cursor + len(page) if matched > limit else 0
	res.data = to_json(Data{page[:], len(page), next_cursor, CATALOG_VERSION})
	return
}

// -- problem_get ---------------------------------------------------------------

Problem_Get_Params :: struct {
	problem_key: string,
	audience:    string,
	offline:     bool,
	refresh:     bool,
}

op_problem_get :: proc(ctx: ^Context, store: ^Store, input: Input, req: Request) -> (res: Result, err: Op_Error) {
	p := params(input, Problem_Get_Params) or_return
	if p.problem_key == "" {
		return {}, invalid("problem_key must be a non-empty string")
	}
	audience := parse_audience(p.audience) or_return
	problem := resolve_problem(p.problem_key) or_return

	Data :: struct {
		problem:        Problem_View,
		metadata_scope: string,
	}
	scope := "curated catalogue metadata; fetch the provider statement before practice"
	if problem.label_origin == UNCATALOGUED {
		scope = "uncatalogued problem described from its key only; fetch the provider statement before practice"
	}
	res.data = to_json(Data{problem_view(problem, audience), scope})
	return
}
