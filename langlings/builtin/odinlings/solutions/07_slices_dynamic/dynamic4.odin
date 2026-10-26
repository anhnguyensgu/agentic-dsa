// dynamic4.odin
package main

import "core:testing"

Party :: [dynamic; 4]string

try_join :: proc(party: ^Party, name: string) -> bool {
	// Checking `len(party) < cap(party)` first works too.
	return append(party, name) == 1
}

main :: proc() {
	// You can optionally experiment here.
}

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
