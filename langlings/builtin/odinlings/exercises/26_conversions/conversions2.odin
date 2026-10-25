// conversions2.odin
//
// `distinct` types share a representation but not an identity, so the
// compiler stops you from adding meters to feet.
package main

import "core:testing"

Meters :: distinct f64
Feet :: distinct f64

FEET_TO_METERS :: 0.3048

total_climb :: proc(a: Meters, b: Feet) -> Meters {
	// TODO: Convert the feet to meters first. That's what the error is
	// protecting you from.
	return a + b
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_total_climb :: proc(t: ^testing.T) {
	got := total_climb(100, 1000)
	testing.expectf(t, abs(got - 404.8) < 1e-9, "got %v, want 404.8", got)
}
