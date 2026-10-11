package main

import "core:mem"
import "core:testing"

@(test)
user_status_distinguishes_false_from_missing :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	cases := []struct {json: string, expected: User_Status}{
		{`{"data":{"userStatus":{"username":"alice","isSignedIn":true,"isPremium":true}}}`, {"alice", true, true}},
		{`{"data":{"userStatus":{"username":null,"isSignedIn":false,"isPremium":false}}}`, {}},
		{`{"data":{"userStatus":{"username":"old","username":"new","isSignedIn":true}}}`, {"new", true, false}},
	}
	for c in cases {
		status, err := parse_user_status(transmute([]byte)c.json)
		testing.expect_value(t, err, Error.None)
		testing.expect_value(t, status, c.expected)
	}
}

@(test)
user_status_rejects_invalid_responses :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	responses := []string{
		"not JSON",
		"{}",
		"null",
		`{"data":null}`,
		`{"data":{"userStatus":null}}`,
		`{"data":{"userStatus":{}}}`,
		`{"data":{"userStatus":{"isSignedIn":null}}}`,
		`{"data":{"userStatus":{"isSignedIn":"true"}}}`,
		`{"data":{"userStatus":{"isSignedIn":true}}}`,
		`{"errors":[{"message":"upstream failed"}],"data":{"userStatus":{"isSignedIn":false}}}`,
	}
	for response in responses {
		status, err := parse_user_status(transmute([]byte)response)
		testing.expectf(t, err == .Verify_Failed, "accepted invalid response: %s", response)
		testing.expect_value(t, status, User_Status{})
	}
}

@(test)
user_status_outlives_response_buffer :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	text := `{"data":{"userStatus":{"username":"alice","isSignedIn":true}}}`
	buffer: [256]byte
	copy(buffer[:], transmute([]byte)text)
	status, err := parse_user_status(buffer[:len(text)])
	testing.expect_value(t, err, Error.None)
	for &ch in buffer[:] {
		ch = 0
	}
	testing.expect_value(t, status.username, "alice")
}
