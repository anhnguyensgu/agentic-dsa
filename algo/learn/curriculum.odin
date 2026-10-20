package learn

// The concept curriculum and problem identity (section 8). There is no
// bundled problem set: any provider problem can be practised, named by its key
// `<provider>:<slug>`. The curriculum is a graph of pattern groups; agents may
// also record free-form sub-patterns named `<group>/<pattern>`, such as
// graphs/topological-sort, which planning and progress roll up under their
// group. #load keeps the binary independent of its working directory.

import "core:fmt"
import "core:strings"

CONCEPTS_JSON :: #load("../curriculum/concepts.json", string)

// Slugs become directory names, so they are kept short.
MAX_SLUG_LENGTH :: 128

Curriculum_Concept :: struct {
	id:            string,
	title:         string,
	prerequisites: []string,
	leetcode_tags: []string, // provider topic slugs that practise this concept
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

// Problem is a provider problem. The slug is also the provider's own id: the
// LeetCode title slug or the Kattis problem id.
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
	known := PROVIDERS
	valid :=
		contains(known[:], provider) &&
		slug != "" &&
		len(slug) <= MAX_SLUG_LENGTH &&
		slug[0] != '.'
	for c in slug {
		switch c {
		case 'a' ..= 'z', '0' ..= '9', '-', '_', '.':
		case:
			valid = false
		}
	}
	if !valid {
		return {}, invalid(fmt.aprintf("problem_key must be <provider>:<slug> with provider %s and a lowercase slug, such as leetcode:two-sum", strings.join(known[:], " or ")))
	}
	return {key, provider, slug}, nil
}
