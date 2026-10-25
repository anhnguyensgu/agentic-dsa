// dynamic4.odin
//
// `[dynamic; 4]string` holds at most four strings, stored inside the value
// itself. No allocator, nothing to delete. `append` adds what fits and returns
// how many elements it added.
package main

import "core:testing"

Party :: [dynamic; 4]string

try_join :: proc(party: ^Party, name: string) -> bool {
	// TODO: Report whether `name` really joined. When the party is full,
	// `append` adds nothing, but this still says it worked.
	append(party, name)
	return true
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_party_fills_up :: proc(t: ^testing.T) {
	party: Party
	names := []string{"Ada", "Bo", "Cy", "Di", "Ed"}
	for name, i in names {
		joined := try_join(&party, name)
		testing.expect_value(t, joined, i < 4)
	}
	testing.expect_value(t, len(party), 4)
	testing.expect_value(t, party[3], "Di")
}
