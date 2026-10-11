package leetcode

import "core:mem"
import "core:os"
import "core:testing"

@(test)
config_round_trip_and_permissions :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	dir, dir_err := os.make_directory_temp("", "leetcode-config-*", context.allocator)
	if !testing.expect(t, dir_err == nil) {
		return
	}
	defer os.remove_all(dir)
	path := os.join_path({dir, "credentials", "config.json"}, context.allocator) or_else ""
	cfg := Config{leetcode_session = "synthetic-session-long", csrf_token = "synthetic-csrf"}
	testing.expect_value(t, save_config(cfg, path), Error.None)
	loaded, err := load_config(path)
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, loaded, cfg)

	// Overwriting a longer, world-readable file must truncate it and restore 0600.
	testing.expect(t, os.chmod(path, os.perm(0o644)) == nil)
	cfg = {leetcode_session = "short"}
	testing.expect_value(t, save_config(cfg, path), Error.None)
	loaded, err = load_config(path)
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, loaded, cfg)
	info, stat_err := os.stat(path, context.allocator)
	testing.expect(t, stat_err == nil)
	when ODIN_OS != .Windows {
		testing.expect_value(t, info.mode & os.Permissions_All, os.perm(0o600))
	}

	testing.expect_value(t, remove_config(path), Error.None)
	testing.expect_value(t, remove_config(path), Error.None)
	_, err = load_config(path)
	testing.expect_value(t, err, Error.Config_Read)
}

@(test)
config_rejects_bad_credentials :: proc(t: ^testing.T) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	context.allocator = mem.dynamic_arena_allocator(&arena)

	dir, dir_err := os.make_directory_temp("", "leetcode-invalid-config-*", context.allocator)
	if !testing.expect(t, dir_err == nil) {
		return
	}
	defer os.remove_all(dir)
	path := os.join_path({dir, "config.json"}, context.allocator) or_else ""
	invalid := []string{
		"not JSON", "{}", "null",
		`{"leetcode_session":""}`,
		`{"leetcode_session":"s","csrf_token":42}`,
		`{"leetcode_session":"s\r\nInjected:header"}`,
	}
	for data in invalid {
		testing.expect(t, os.write_entire_file(path, data, os.perm(0o600)) == nil)
		cfg, err := load_config(path)
		testing.expect_value(t, err, Error.Config_Read)
		testing.expect_value(t, cfg, Config{})
	}

	good := Config{leetcode_session = "keep-existing"}
	testing.expect_value(t, save_config(good, path), Error.None)
	testing.expect_value(t, save_config({}, path), Error.No_Input)
	loaded, err := load_config(path)
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, loaded, good)
}
