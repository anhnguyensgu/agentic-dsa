// conversions2.odin
package main

import "core:testing"

Meters :: distinct f64
Feet :: distinct f64

FEET_TO_METERS :: 0.3048

total_climb :: proc(a: Meters, b: Feet) -> Meters {
	// Converting between distinct types is explicit, the same as between
	// any other types. The untyped constant converts on its own.
	return a + Meters(b) * FEET_TO_METERS
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_total_climb :: proc(t: ^testing.T) {
	got := total_climb(100, 1000)
	testing.expectf(t, abs(got - 404.8) < 1e-9, "got %v, want 404.8", got)
}
