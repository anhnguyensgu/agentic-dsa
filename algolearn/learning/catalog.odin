package learning

// Versioned offline curriculum and reviewed provider mappings (sections 8
// and 16). The files remain distributable artifacts while #load keeps the
// compiled binary independent of its current working directory.

import "core:encoding/json"
import "core:strings"

CONCEPTS_JSON :: #load("../../curriculum/concepts.json")
PROBLEMS_JSON :: #load("../../curriculum/problems.json")
CATALOG_VERSION :: "2026-09-20"

catalog_document :: proc() -> (json.Value, Engine_Error) {
	v, err := json.parse(PROBLEMS_JSON, .JSON, parse_integers = true)
	if err != nil { return nil, .Storage_Error }
	return v, .None
}

catalog_problems :: proc() -> (json.Array, Engine_Error) {
	doc, err := catalog_document()
	if err != .None { return nil, err }
	return jarray(jget(doc, "problems")), .None
}

catalog_find :: proc(problem_key: string) -> (json.Value, bool) {
	problems, err := catalog_problems()
	if err != .None { return nil, false }
	for problem in problems {
		if jstr(jget(problem, "problem_key")) == problem_key { return problem, true }
	}
	return nil, false
}

catalog_has_string :: proc(values: json.Value, needle: string) -> bool {
	if needle == "" { return true }
	for value in jarray(values) {
		if jstr(value) == needle { return true }
	}
	return false
}

catalog_matches_query :: proc(problem: json.Value, query: string) -> bool {
	if query == "" { return true }
	q := strings.to_lower(query)
	title := strings.to_lower(jstr(jget(problem, "title")))
	key := strings.to_lower(jstr(jget(problem, "problem_key")))
	slug := strings.to_lower(jstr(jget(problem, "slug")))
	return strings.contains(title, q) || strings.contains(key, q) || strings.contains(slug, q)
}

json_string_array :: proc(values: json.Value) -> [dynamic]string {
	out := make([dynamic]string)
	for value in jarray(values) {
		if s := jstr(value); s != "" { append(&out, s) }
	}
	return out
}

// Assessment views deliberately omit spoiler-sensitive tags.
catalog_problem_json :: proc(problem: json.Value, audience := "learning") -> string {
	o := obj_new()
	defer obj_free(&o)
	obj_field_str(&o, "problem_key", jstr(jget(problem, "problem_key")))
	obj_field_str(&o, "provider", jstr(jget(problem, "provider")))
	obj_field_str(&o, "native_id", jstr(jget(problem, "native_id")))
	obj_field_str(&o, "slug", jstr(jget(problem, "slug")))
	obj_field_str(&o, "title", jstr(jget(problem, "title")))
	obj_field_str(&o, "canonical_url", jstr(jget(problem, "canonical_url")))
	obj_field_str(&o, "difficulty", jstr(jget(problem, "difficulty")))
	obj_field_int(&o, "effort_minutes", jint(jget(problem, "effort_minutes")))
	obj_field_str(&o, "access", jstr(jget(problem, "access")))
	obj_field_bool(&o, "offline", jbool(jget(problem, "offline")))
	concepts := json_string_array(jget(problem, "concept_ids"))
	defer delete(concepts)
	prereqs := json_string_array(jget(problem, "prerequisites"))
	defer delete(prereqs)
	modes := json_string_array(jget(problem, "practice_modes"))
	defer delete(modes)
	langs := json_string_array(jget(problem, "judge_languages"))
	defer delete(langs)
	obj_field_strs(&o, "concept_ids", concepts[:])
	obj_field_strs(&o, "prerequisites", prereqs[:])
	obj_field_strs(&o, "practice_modes", modes[:])
	obj_field_strs(&o, "judge_languages", langs[:])
	if audience != "assessment" {
		tags := json_string_array(jget(problem, "spoiler_tags"))
		defer delete(tags)
		obj_field_strs(&o, "spoiler_tags", tags[:])
	}
	obj_field_str(&o, "label_origin", jstr(jget(problem, "label_origin")))
	return obj_done(&o)
}

op_problem_search :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {}, {"provider", "query", "concept_id", "language", "offline", "limit", "cursor", "audience"}); fail.status == .Error {
		return fail
	}
	provider := get_opt_str(input, "provider")
	query := get_opt_str(input, "query")
	concept := get_opt_str(input, "concept_id")
	language := get_opt_str(input, "language")
	audience := get_opt_str(input, "audience")
	if audience == "" { audience = "learning" }
	if audience != "learning" && audience != "assessment" { return bad_input("audience must be learning or assessment") }
	limit := jint(jget(input, "limit"))
	if limit == 0 { limit = 20 }
	if limit < 1 || limit > 100 { return bad_input("limit must be between 1 and 100") }
	cursor := jint(jget(input, "cursor"))
	if cursor < 0 { return bad_input("cursor must be zero or greater") }

	problems, cerr := catalog_problems()
	if cerr != .None { return error_result(cerr, "the bundled curriculum could not be read") }
	items := make([dynamic]string)
	defer delete(items)
	matched, skipped := 0, 0
	for problem in problems {
		if provider != "" && jstr(jget(problem, "provider")) != provider { continue }
		if !catalog_matches_query(problem, query) { continue }
		if concept != "" && !catalog_has_string(jget(problem, "concept_ids"), concept) { continue }
		if language != "" {
			local_ok := language == "odin" && catalog_has_string(jget(problem, "practice_modes"), "odin_local")
			remote_ok := catalog_has_string(jget(problem, "judge_languages"), language)
			if !local_ok && !remote_ok { continue }
		}
		if skipped < cursor { skipped += 1; continue }
		matched += 1
		if len(items) < limit { append(&items, catalog_problem_json(problem, audience)) }
	}
	res := ok_result()
	obj_field_raws(&res.data, "problems", items[:])
	obj_field_int(&res.data, "count", len(items))
	obj_field_int(&res.data, "next_cursor", cursor + len(items) if matched > limit else 0)
	obj_field_str(&res.data, "catalog_version", CATALOG_VERSION)
	return res
}

op_problem_get :: proc(ctx: ^Context, store: ^Store, input: json.Value, req: Request) -> Result {
	if fail := require_fields(input, {"problem_key"}, {"audience", "offline", "refresh"}); fail.status == .Error { return fail }
	problem_key := jstr(jget(input, "problem_key"))
	if problem_key == "" { return bad_input("problem_key must be a non-empty string") }
	audience := get_opt_str(input, "audience")
	if audience == "" { audience = "learning" }
	if audience != "learning" && audience != "assessment" { return bad_input("audience must be learning or assessment") }
	problem, found := catalog_find(problem_key)
	if !found { return error_result(.Not_Found, "problem is not present in the bundled catalogue") }
	res := ok_result()
	obj_field_raw(&res.data, "problem", catalog_problem_json(problem, audience))
	obj_field_str(&res.data, "metadata_scope", "curated catalogue metadata; fetch the provider statement before practice")
	return res
}
