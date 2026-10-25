// structs3.odin
//
// Odin has no methods. Procedures that work on a struct take it as an
// ordinary parameter, and a "constructor" is just a procedure that returns
// one.
package main

import "core:testing"

Package :: struct {
	sender_country:    string,
	recipient_country: string,
	weight_in_grams:   int,
}

// Packages under 10 grams can't be shipped: return ok = false for them.
make_package :: proc(sender, recipient: string, weight: int) -> (pkg: Package, ok: bool) {
	// TODO
	return
}

is_international :: proc(p: Package) -> bool {
	// TODO
	return false
}

shipping_fee :: proc(p: Package, cents_per_gram: int) -> int {
	// TODO
	return 0
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_too_light :: proc(t: ^testing.T) {
	_, ok := make_package("Spain", "Austria", 5)
	testing.expect_value(t, ok, false)
}

@(test)
test_international :: proc(t: ^testing.T) {
	p, ok := make_package("Spain", "Russia", 1200)
	testing.expect(t, ok)
	testing.expect(t, is_international(p))
}

@(test)
test_domestic :: proc(t: ^testing.T) {
	p, ok := make_package("Canada", "Canada", 1200)
	testing.expect(t, ok)
	testing.expect(t, !is_international(p))
}

@(test)
test_shipping_fee :: proc(t: ^testing.T) {
	p, ok := make_package("Spain", "Spain", 1500)
	testing.expect(t, ok)
	testing.expect_value(t, shipping_fee(p, 3), 4500)
}
