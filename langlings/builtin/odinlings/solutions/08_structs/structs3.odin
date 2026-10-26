// structs3.odin
package main

import "core:testing"

Package :: struct {
	sender_country:    string,
	recipient_country: string,
	weight_in_grams:   int,
}

make_package :: proc(sender, recipient: string, weight: int) -> (pkg: Package, ok: bool) {
	if weight < 10 {
		return {}, false
	}
	return Package{sender, recipient, weight}, true
}

is_international :: proc(p: Package) -> bool {
	return p.sender_country != p.recipient_country
}

shipping_fee :: proc(p: Package, cents_per_gram: int) -> int {
	return p.weight_in_grams * cents_per_gram
}

main :: proc() {
	// You can optionally experiment here.
}

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
