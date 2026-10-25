// soa1.odin
package main

import "core:testing"

Particle :: struct {
	pos: [2]f32,
	vel: [2]f32,
}

N :: 4

Particles :: #soa[N]Particle

step :: proc(ps: ^Particles, dt: f32) {
	for &p in ps {
		p.pos += p.vel * dt
	}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_step :: proc(t: ^testing.T) {
	ps: Particles
	ps[0] = {pos = {0, 0}, vel = {1, 2}}
	ps[3] = {pos = {5, 5}, vel = {-2, 0}}

	step(&ps, 0.5)

	testing.expect_value(t, ps[0].pos, [2]f32{0.5, 1})
	testing.expect_value(t, ps[3].pos, [2]f32{4, 5})
}

@(test)
test_field_arrays :: proc(t: ^testing.T) {
	ps: Particles
	ps[2].vel = {7, 8}
	velocities := ps.vel
	testing.expect_value(t, velocities[2], [2]f32{7, 8})
	testing.expect_value(t, len(velocities), N)
}
