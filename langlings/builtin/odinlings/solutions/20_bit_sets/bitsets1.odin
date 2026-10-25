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
	return p + {extra}
}

revoke :: proc(p: Permissions, gone: Permission) -> Permissions {
	return p - {gone}
}

can :: proc(p: Permissions, needed: Permission) -> bool {
	return needed in p
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_grant_and_revoke :: proc(t: ^testing.T) {
	p := Permissions{.Read}
	p = grant(p, .Write)
	testing.expect_value(t, p, Permissions{.Read, .Write})

	p = revoke(p, .Read)
	testing.expect_value(t, p, Permissions{.Write})

	p = revoke(p, .Execute)
	testing.expect_value(t, p, Permissions{.Write})
}

@(test)
test_can :: proc(t: ^testing.T) {
	p := Permissions{.Read, .Execute}
	testing.expect(t, can(p, .Execute))
	testing.expect(t, !can(p, .Write))
}
