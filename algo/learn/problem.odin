package learn

// Problem identity. There is no bundled problem set or curriculum: any
// provider problem can be practised, named by its key `<provider>:<slug>`, and
// agents choose what comes next themselves.

import "core:fmt"
import "core:strings"

// Slugs become directory names, so they are kept short.
MAX_SLUG_LENGTH :: 128

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
