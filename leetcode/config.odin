package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

// String storage belongs to the command arena; this record is non-owning.
Config :: struct {
	leetcode_session: string `json:"leetcode_session"`,
	csrf_token:       string `json:"csrf_token"`,
}

CONFIG_DIR_NAME :: "leetcode-odin"

config_path :: proc() -> (path: string, err: Error) {
	if override := os.get_env("LEETCODE_ODIN_CONFIG", context.allocator); override != "" {
		return override, nil
	}
	home, home_err := os.user_home_dir(context.allocator)
	if home_err != nil || !os.is_absolute_path(home) {
		return "", .Config_Path
	}
	joined, path_err := os.join_path(
		{home, ".config", CONFIG_DIR_NAME, "config.json"},
		context.allocator,
	)
	if path_err != nil {
		return "", .Config_Path
	}
	return joined, nil
}

// Paths are supplied explicitly so storage can be tested without real credentials.
save_config :: proc(cfg: Config, path: string) -> Error {
	if !valid_credentials(cfg) {
		return .No_Input
	}
	if derr := os.make_directory_all(os.dir(path), os.perm(0o700)); derr != nil && derr != .Exist {
		fmt.eprintln("failed to create config dir:", os.error_string(derr))
		return .Config_Write
	}

	data, jerr := json.marshal(cfg, {}, context.allocator)
	if jerr != nil {
		fmt.eprintln("failed to encode credentials:", jerr)
		return .Config_Write
	}
	defer delete(data)

	if werr := write_private_file(path, data); werr != nil {
		fmt.eprintln("failed to write config file:", os.error_string(werr))
		return .Config_Write
	}
	return nil
}

// Write and close a private sibling before atomically replacing the target.
// Failed writes leave existing credentials intact; symlinks are not followed.
write_private_file :: proc(path: string, data: []byte) -> (err: os.Error) {
	file := os.create_temp_file(os.dir(path), ".leetcode-write-*") or_return
	temporary := strings.clone(os.name(file))
	defer delete(temporary)
	defer os.remove(temporary)
	defer if file != nil {
		os.close(file)
	}
	os.fchmod(file, os.perm(0o600)) or_return
	written := os.write(file, data) or_return
	if written != len(data) {return .Invalid_Argument}
	err = os.close(file)
	file = nil
	if err != nil {return}
	return os.rename(temporary, path)
}

load_config :: proc(path: string) -> (cfg: Config, err: Error) {
	data, ferr := os.read_entire_file(path, context.allocator)
	if ferr != nil {
		return cfg, .Config_Read
	}
	defer delete(data)

	if uerr := json.unmarshal(data, &cfg); uerr != nil {
		return {}, .Config_Read
	}
	if !valid_credentials(cfg) {
		return {}, .Config_Read
	}
	return cfg, nil
}

// remove_config deletes the credentials file. Removing a missing file is
// fine — logout is idempotent.
remove_config :: proc(path: string) -> Error {
	if rerr := os.remove(path); rerr != nil && rerr != .Not_Exist {
		fmt.eprintln("failed to remove config file:", os.error_string(rerr))
		return .Config_Delete
	}
	fmt.println("credentials removed.")
	return nil
}
