// bitsets1.odin
package main

import "core:testing"

Permission :: enum {
	Read,
	Write,
	Execute,
}

Permissions :: bit_set[Permission]

grant :: proc(p: Permissions, extra: Permission) -> Permissions {
	// TODO
	return p
}

revoke :: proc(p: Permissions, gone: Permission) -> Permissions {
	// TODO
	return p
}

can :: proc(p: Permissions, needed: Permission) -> bool {
	// TODO
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_grant_and_revoke :: proc(t: ^testing.T) {
	p := Permissions{.Read}
	p = grant(p, .Write)
	testing.expect_value(t, p, Permissions{.Read, .Write})

	p = revoke(p, .Read)
	testing.expect_value(t, p, Permissions{.Write})

	// Revoking something that isn't there is fine.
	p = revoke(p, .Execute)
	testing.expect_value(t, p, Permissions{.Write})
}

@(test)
test_can :: proc(t: ^testing.T) {
	p := Permissions{.Read, .Execute}
	testing.expect(t, can(p, .Execute))
	testing.expect(t, !can(p, .Write))
}
