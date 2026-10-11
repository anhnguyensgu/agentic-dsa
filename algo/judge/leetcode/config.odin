package leetcode

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "../../safeio"

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
	joined, join_err := os.join_path({home, ".config", CONFIG_DIR_NAME, "config.json"}, context.allocator)
	if join_err != nil {
		return "", .Config_Path
	}
	return joined, nil
}

// Paths are supplied explicitly so storage can be tested without real
// credentials. The file is written atomically with mode 0600.
save_config :: proc(cfg: Config, path: string) -> Error {
	if !valid_credentials(cfg) {
		return .No_Input
	}
	data, marshal_err := json.marshal(cfg)
	if marshal_err != nil {
		fmt.eprintln("failed to encode credentials:", marshal_err)
		return .Config_Write
	}
	if write_err := safeio.write_private_file(path, data); write_err != nil {
		fmt.eprintln("failed to write config file:", os.error_string(write_err))
		return .Config_Write
	}
	return nil
}

load_config :: proc(path: string) -> (cfg: Config, err: Error) {
	data, read_err := os.read_entire_file(path, context.allocator)
	// unmarshal asserts on malformed input, so a corrupt file is checked first.
	if read_err != nil || !json.is_valid(data, .JSON) || json.unmarshal(data, &cfg, .JSON) != nil || !valid_credentials(cfg) {
		return {}, .Config_Read
	}
	return cfg, nil
}

// remove_config deletes the credentials file. Removing a missing file is
// fine — logout is idempotent.
remove_config :: proc(path: string) -> Error {
	if remove_err := os.remove(path); remove_err != nil && remove_err != .Not_Exist {
		fmt.eprintln("failed to remove config file:", os.error_string(remove_err))
		return .Config_Delete
	}
	fmt.println("credentials removed.")
	return nil
}
