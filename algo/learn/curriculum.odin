package learn

// The concept curriculum and problem identity. There is no bundled problem
// set: any provider problem can be practised, named by its key
// `<provider>:<slug>`. The curriculum is a graph of pattern groups in study
// order; agents may also name free-form sub-patterns `<group>/<pattern>`, such
// as graphs/topological-sort, and roll them up under their group. Agents
// choose what comes next themselves; curriculum_get only describes the
// groups. #load keeps the binary independent of its working directory.

import "core:fmt"
import "core:strings"

CONCEPTS_JSON :: #load("../curriculum/concepts.json", string)

// Slugs become directory names, so they are kept short.
MAX_SLUG_LENGTH :: 128

Curriculum_Concept :: struct {
	id:            string,
	title:         string,
	prerequisites: []string,
	outcomes:      []string, // what a learner can do once the group is learned
	leetcode_tags: []string, // provider topic slugs that practise this concept
	problems:      map[string][]string, // provider -> problem slugs that practise this concept
}

Curriculum :: struct {
	curriculum_version: string,
	concepts:           []Curriculum_Concept,
}

curriculum :: proc() -> (doc: Curriculum, ok: bool) {
	ok = decode(CONCEPTS_JSON, &doc)
	return
}

curriculum_version :: proc() -> string {
	doc, _ := curriculum()
	return doc.curriculum_version
}

curriculum_concepts :: proc() -> (concepts: []Curriculum_Concept, ok: bool) {
	doc := curriculum() or_return
	return doc.concepts, true
}

// concept_group is the group part of a concept id: `graphs` for both graphs
// and graphs/topological-sort.
concept_group :: proc(id: string) -> string {
	group, _, _ := strings.partition(id, "/")
	return group
}

find_concept :: proc(id: string) -> (Curriculum_Concept, bool) {
	concepts, ok := curriculum_concepts()
	if !ok {
		return {}, false
	}
	for c in concepts {
		if c.id == id {
			return c, true
		}
	}
	return {}, false
}

// -- curriculum_get ------------------------------------------------------------

Curriculum_Get_Params :: struct {
	concept_id: string, // a group, or a `<group>/<pattern>` that selects its group
}

op_curriculum_get :: proc(
	ctx: ^Context,
	input: Input,
	req: Request,
) -> (
	res: Result,
	err: Op_Error,
) {
	p := params(input, Curriculum_Get_Params) or_return
	doc, ok := curriculum()
	if !ok {
		return {}, fail(.Storage_Error, "the bundled curriculum could not be read")
	}
	concepts := doc.concepts
	if p.concept_id != "" {
		concept, found := find_concept(concept_group(p.concept_id))
		if !found {
			return {}, fail(.Not_Found, "concept_id names no curriculum group")
		}
		concepts = make([]Curriculum_Concept, 1)
		concepts[0] = concept
	}
	Data :: struct {
		curriculum_version: string,
		concepts:           []Curriculum_Concept,
	}
	res.data = to_json(Data{doc.curriculum_version, concepts})
	return
}

// Problem is a provider problem. The slug is also the provider's own id: the
// LeetCode title slug, the Kattis problem id, or the Exercism exercise slug.
Problem :: struct {
	key:      string,
	provider: string,
	slug:     string,
}

// parse_problem_key accepts `<provider>:<slug>` for a known provider. The
// slug is restricted to lowercase letters, digits, '-', '_' and '.', and may
// not start with '.', so it is always a single safe path component.
parse_problem_key :: proc(key: string) -> (problem: Problem, err: Op_Error) {
	provider, _, slug := strings.partition(key, ":")
	_, known := provider_traits(provider)
	valid := known && slug != "" && len(slug) <= MAX_SLUG_LENGTH && slug[0] != '.'
	for c in slug {
		switch c {
		case 'a' ..= 'z', '0' ..= '9', '-', '_', '.':
		case:
			valid = false
		}
	}
	if !valid {
		return {}, invalid(fmt.aprintf("problem_key must be <provider>:<slug> with provider %s and a lowercase slug, such as leetcode:two-sum", strings.join(provider_names(), ", ")))
	}
	return {key, provider, slug}, nil
}
